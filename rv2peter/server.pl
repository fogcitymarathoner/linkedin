#!/usr/bin/perl
# perl server.pl -start 100 -end 110 -outsql 100-110.sql
use warnings;
use strict;

use DBI;
use DBD::mysql;
use LWP::Simple;
use HTTP::Request;
use Data::Dumper;
use HTML::TreeBuilder 5 -weak;
use HTML::TreeBuilder::XPath;
use Text::Unidecode;


use constant { True => 1, False =>0 };
use constant { COMMENT_CHAR => '#',
				TAB_CHAR => '\t',
				SPACE_CHAR => ' ',
				NEWLINE => "\n" };
use constant { ID_INDEX => 0,
				LINKEDIN_URL_INDEX => 1,
				NAME_INDEX => 2,
				CITY_INDEX => 1,
				STATE_INDEX => 2,
				COUNTRY_INDEX => 3,
				COMPANY_INDEX => 1,
				SCHOOL_INDEX => 1,
				PHOTO_INDEX => 1,
				SKILL_INDEX => 1 };
use constant { ID => 'ID',
				URL => 'URL',
				NAME => 'NAME',
				CITY => 'CITY',
				STATE => 'STATE',
				COUNTRY => 'COUNTRY',
				ALIAS => 'COUNTRY',
				SKILLS => 'SKILLS',
				CURRENT_JOB => 'CURRENT_JOB',
				EXPERIENCE => 'EXPERIENCE',
				SCHOOL => 'SCHOOL',
				MAJOR => 'MAJOR',
				PHOTO => 'PHOTO',
				TITLE => 'TITLE',
				PERIOD => 'PERIOD',
				COMPANY => 'COMPANY',
				SCRAPE_STATUS => 'SCRAPE STATUS' };
use constant { URL_HOLE => 'URL Hole',
				NAME_HOLE => 'Name Hole',
				LOCATION_HOLE => 'Location Hole',
				SKILLS_HOLE => 'Skills Hole',
				CURRENT_JOB_HOLE => 'Current Job Hole',
				SCHOOL_HOLE => 'School Hole',
				PHOTO_HOLE => 'Photo Hole',
				NEEDS_SCRAPING => 'Needs Scraping' };
use constant { VIDLINK => 'Vidlink',
				SCRAPED => 'Scraped' };
use constant { NO_URL_NAME => 'No URL Name',
				NOT_NEEDED => 'Not Needed',
				FOREIGN => 'Foreign Domain',
				NON_ASCII => 'Non-Ascii URL', 
				FETCH_FAIL => 'URL Fetch Failed' };
use constant { XPATH_FULL_NAME => '//span[@class="full-name"]',
				XPATH_GIVEN_NAME => '//span[@class="given-name"]',
				XPATH_FAMILY_NAME => '//span[@class="family-name"]',
				XPATH_LOCALITY => '//span[@class="locality"]',
				XPATH_SKILLS => '//span[@class="endorse-item-name-text"]',
				XPATH_SCHOOL => '//div[@class="education first"]//h4/a',
				XPATH_MAJOR => '//span[@class="major"]',
				XPATH_CURRENT_JOB => '//div[@class="editable-item section-item current-position"]',
				XPATH_PAST_JOB => '//div[@class="editable-item section-item past-position"]',
				XPATH_PAST_COMPANY => '//h5/a[@dir="auto"]',
				XPATH_PERIOD => '//span[@class="experience-date-locale"]',
				XPATH_PHOTO => '//img[@id="bg-blur-profile-picture"]' };

require 'config.pl';

#use RV::Utils qw(trim);

#my $limitRecords = " limit 10";
my $limitRecords = "";
my $idStr = '';
my $idCond = ' where ';

BEGIN {
	$ENV{HTTPS_DEBUG} = 1;
}

my $dbh; # Database Handler
my $getDataStmt; # Query to get person data

# Aggregate data
my %personData  = ();
my %totals      = (); # Stats
my $numRecords  = 0;  # Number of total records
my $startId     = undef;
my $endId       = undef;
my %skillsDB    = (); # Collect all skills into a hash table.
my %schoolsDB   = (); # Collect all schools into a hash table.
my %companiesDB = (); # Collect all companies into a hash table.
my @idList;

# Web vars
my @httpsProxies;
my @httpProxies;
my $numHttpProxies  = 0;
my $numHttpsProxies = 0;
my $urlCount        = 0;

my @content;
my $response;
my $httpCode = 0;
my $ua = new LWP::UserAgent;

my $xpathRoot;

# Misc Data for location processing
my %countriesDB = ();
my %aliases = ();
my %countryOfState = (); # e.g. $countryOfState{'California'} = 'U.S.A.'

# Flags
my $onlyUS = False;
my $skipNonAsciiURLs = False;
my $skipNonAsciiLocations = False;
my $force = False; # if True, force output even when no 'hole' in record.
my $debug = False; # For now, print select SQL stmts for Marc Condon.


# Utility Functions
sub warning {
	print "Warning: $_[0]\n";
}

sub trim {
	(my $s = $_[0]) =~ s/^\s+|\s+$//g;
	return $s;
}

sub fix_str {
	# Function to remove all kinds of prefixes and suffixes to city names
	my $str = $_[0];
	$str =~ s| Area||gi;
	$str =~ s| Metro$||gi;
	$str =~ s|y alrededores$||gi;
	$str =~ s|en omegeving$||gi;
	$str =~ s|und umgebung$||gi;
	$str =~ s|dan Sekitarnya$||gi;
	$str =~ s|^Greater ||gi;
	$str =~ s|^Région de||gi;
	$str =~ s|^la baie de||gi;
	$str =~ s|Région||gi;
	$str =~ s| e Região||gi;
	$str =~ s| Province$||gi;
	$str =~ s|&amp;|&|gi;
	$str = trim($str);
	$str = unidecode($str);

	if ($str eq "-") {$str = "";}
	return $str;
}

sub is_valid_str {
	# Checks for chars that usually occur in URLs
	my $s = $_[0];
	if ($s !~ /^[\P{Latin}A-za-z0-9_:\-\.\ \?\/]+$/ ) {
		return False;
	}
	if ($s =~ /[\p{ASCII}A-za-z0-9_:\-\.\ \?\/]+$/ ) {
		return True;
	}
	return False;
}

sub loadProxies {
	my $proxiesFile = $_[0];
	open(FILE, $proxiesFile)
		or die "proxies file $proxiesFile not found";
	my @proxies = <FILE>;
	close FILE;
	foreach (@proxies) {
		my $proxy = $_;
		if ($proxy eq '') {
			next;
		}
		my @words = split(TAB_CHAR, $proxy );
		if ( (substr $words[0], 0, 1) eq COMMENT_CHAR) {
			next;
		}
		if (lc($words[1]) eq 'http') {
			$httpProxies[$numHttpProxies] = $proxy;
			$numHttpProxies++;
		} else {
			$httpsProxies[$numHttpsProxies] = $proxy;
			$numHttpsProxies++;
		}
	}
	#print "HTTP Proxies are " . @httpProxies . NEWLINE;
	#print "HTTPS Proxies are " . @httpsProxies . NEWLINE;
}


sub get_vidlink_city_data {
}

sub get_vidlink_state_data {
}

sub load_locations {
# 	File Format:
#		Have to use a different delimiter other than the blank char as
#		states like "North Dakota" have a space char in their names.
#		country countryName
#		state,stateName,optional <countryName>
#		alias,abbreviation,full_name
#		TODO: city,<withAll/OnlyState/OnlyCountry>,<state>,<country>
#		countryNames stored in a hash, check for existence of country name.
#		stateNames hash - key is stateName, value is countryName
#		aliases hash - key is aliasName, value is originalName
#	In addition, read cities, states, countries from vidlink

	my $locationsFile = get_locations_file();
	open(FILE, $locationsFile)
		or die "locations file $locationsFile not found";
	my @data = <FILE>;
	close FILE;

	my $line = '';
	my @words;
	my $cmd = '';
	my $cntry = '';
	my $numWords;
	my $lineNum = 0;
	foreach (@data) {
		chomp;
		$line = trim($_);
		$lineNum++;
		if ($line eq '') {
			next;
		}
		@words = split(',', $line);
		$numWords = @words;
		$cmd = $words[0];
		if ( (substr $cmd, 0, 1) eq COMMENT_CHAR) {
			next;
		}
		$cmd = uc $cmd;
		if ($cmd eq COUNTRY) {
			if ($numWords < 2) {
				warning 'country not specified at line # ' . $lineNum
						. ' in ' . $locationsFile . ', skipping $line';
				next;
			} else {
				# countryDB hash - just check if country name exists.
				$countriesDB{$words[1]} = True;
			}
		} elsif ($cmd eq STATE) {
			if ($numWords < 2) {
				warning 'state not specified at line # ' . $lineNum .
						' in ' . $locationsFile . ', skipping $line';
				next;
			} elsif ($numWords > 2) {
				$cntry = $words[2];
			} else {
				$cntry = '';
			}
			# country hash - key is stateName, value is countryName
			$countryOfState{$words[1]} = $cntry;
		} elsif ($cmd eq ALIAS) {
			if ($numWords < 3) {
				warning 'alias incorrectly specified at line # ' .
						$lineNum . ' in ' . $locationsFile
						. ', skipping $line';
				next;
			}
			# aliases hash - key is aliasName, value is originalName
			$aliases{$words[1]} = $words[2];
		} elsif ($cmd eq CITY) {
			if ($numWords < 3) {
				warning 'city incorrectly specified at line # '
						. $lineNum . ' in ' . $locationsFile
						. ', skipping $line';
				next;
			}
			my $state = $words[2];
			# city hash - key is cityName, value is stateName
		} else {
			warning 'Unknown command ' . $cmd . ' at line # ' . $lineNum
					. ' in ' . $locationsFile . ', skipping $line';
		}
	}

	get_vidlink_city_data();
	get_vidlink_state_data();
}

sub is_hole {
	my $id = $_[0];
	my $field = $_[1];
	if ( defined $personData{$id}{VIDLINK}{$field} ) {
		#print "is_hole: $field is defined for $id\n";
		#print "value is $personData{$id}{VIDLINK}{$field}\n";
		if ( $personData{$id}{VIDLINK}{$field} ne '' ) {
			#print "has_no_hole\n";
			return False;
		}
	}
	#print "id is $id, field is $field, value is undef, is_hole\n";
	return True;
}


sub needs_scraping {
	my $id = $_[0];
	my $verbose = $_[1];

	my $ret = False;
	
	#my @fields = (NAME, CITY, SKILLS, CURRENT_JOB, SCHOOL, PHOTO);
	my @fields = (NAME, SKILLS, CURRENT_JOB, SCHOOL, PHOTO);
	my @fieldNames = ('Name', 'Skills', 'Experience', 'Education', 'Photo');
	my $myStr = '';

	my $index = 0;
	foreach (@fields) {
		my $field = $_;
		my $val = is_hole($id, $field);
		if ($verbose == True) {
			if ($val == True) {
				$myStr = $myStr . $fieldNames[$index] . ', ';
			}
			$index++;
		}
		$ret |= $val;
		#if ($ret == True) {
			#return $ret;
		#}
	}
	#my %s = %{ $personData{$id}{VIDLINK} };
	#print "Record: " . Dumper(\%s);
	#print "needs_scraping is $ret\n";

	if ($verbose == True) {
		if ($ret == True) {
			$myStr = $myStr. " need scraping for $id\n";
		} else {
			$myStr = "No need to scrape $id\n";
		}
		print $myStr;
	}
	return $ret;
}

sub scrape_name {
	my $id = $_[0];

	$personData{$id}{SCRAPED}{NAME} = undef;
	if ( ( is_hole($id, NAME) ) == False ) {
		if ( $force == False ) {
			return False;
		}
	}

	my $name = undef;
	$name = $xpathRoot->findnodes(XPATH_FULL_NAME)->[0];
	if (defined $name) {
		$name = $name->as_text;
		#print "NAME: " . $name->as_text . NEWLINE;
	} else {
		my $fname = $xpathRoot->findnodes(XPATH_GIVEN_NAME)->[0];
		my $lname = $xpathRoot->findnodes(XPATH_FAMILY_NAME)->[0];
		if (defined $fname) {
			$fname = $fname->as_text;
		}
		if (defined $lname) {
			$lname = $lname->as_text;
		}
		if (defined $fname && $fname ne '') {
			$name = $fname;
			if (defined $lname && $lname ne '') {
				if (defined $name && $name ne '') {
					$name = $name . SPACE_CHAR . $lname;
				} else {
					$name = $lname;
				}
			}
		} else {
			$name = $lname;
		}
	}
	if (defined $name) {
		$name =~ s/(\w+)/\u\L$1/g;
		#print "Scraped name is " . $name . NEWLINE;
		$personData{$id}{SCRAPED}{NAME} = $name;
	} else {
		warning "Scraping returned no name for $id";
		return False;
	}
	return True;
}


sub scrape_photo {
	my $id = $_[0];

	$personData{$id}{SCRAPED}{PHOTO} = undef;
	if ( ( is_hole($id, PHOTO) ) == False ) {
		#print "No photo hole for person id $id\n";
		if ( $force == False ) {
			return False;
		}
	}

	my $ph = $xpathRoot->findnodes( XPATH_PHOTO )->[0];
	if (defined $ph) {
		#print "Photo: ";
		$personData{$id}{SCRAPED}{PHOTO} = $ph->attr('src');
		#print "\t" . $personData{$id}{SCRAPED}{PHOTO} . NEWLINE;
		#print $ph->as_text . NEWLINE;
		#print 'photo node is . Dumper(\$ph) . NEWLINE;
	} else {
		print "No photo info for $id\n";
	}
	return True;
}


sub scrape_experience {
	my $id = $_[0];

	my @tmpCompanies;
	$personData{$id}{SCRAPED}{EXPERIENCE} = undef;
	if ( ( is_hole($id, CURRENT_JOB) ) == False ) {
		#print "No experience hole for person id $id\n";
		return False;
		if ( $force == False ) {
			return False;
		}
	}

	my $currJob = $xpathRoot->findnodes( XPATH_CURRENT_JOB )->[0];
	if ( defined $currJob ) {
		my %info = ();
		my $store = False;
		#print "Current Job: \n";
		#print "\t";
		my $currTitle = $currJob->findnodes( '//h4' )->[0];
		if (defined $currTitle) {
			#$store = True;
			$info{TITLE} = $currTitle->as_text;
			#print $info{TITLE} . NEWLINE;
		}
		my $currPeriod = $currJob->findnodes( XPATH_PERIOD )->[0];
		if (defined $currPeriod) {
			#TODO: Parsing period into start and end dates
			#$store = True;
			$info{PERIOD} = unidecode($currPeriod->as_text);
			#print "\t";
			#print $info{PERIOD} . NEWLINE;
		}
		my $currCompany = $currJob->findnodes( '//h5' )->[0];
		if (defined $currCompany) {
			$store = True;
			$info{COMPANY} = $currCompany->as_text;
			#print "\t";
			#print $info{COMPANY} . NEWLINE;
		}
		if ($store == True) {
			#TODO: Replace by checking the size of hash
			push (@tmpCompanies, \%info);
			#if ( not exists $companiesDB{VIDLINK}{$info{COMPANY}} ) {
				$companiesDB{SCRAPED}{$info{COMPANY}} = True;
			#}
		}
	}

	my @pastJobs = $xpathRoot->findnodes( XPATH_PAST_JOB);
	my $numPJ = @pastJobs;
	if ($numPJ > 0) {
		#print "Experience: \n";
		foreach (@pastJobs) {
			my $pj = $_;
			my %info = ();
			my $store = False;
			my $title = $pj->findnodes( '//h4' )->[0];
			if (defined $title) {
				#$store = True;
				$info{TITLE} = $title->as_text;
				#print $info{TITLE} . NEWLINE;
			}
			my $period = $pj->findnodes( XPATH_PERIOD )->[0];
			if (defined $period) {
				#TODO: Parsing period into start and end dates
				#$store = True;
				$info{PERIOD} = unidecode($period->as_text);
				#print "\t";
				#print $info{PERIOD} . NEWLINE;
			}
			my $company = $pj->findnodes( XPATH_PAST_COMPANY )->[0];
			if (defined $company) {
				$store = True;
				$info{COMPANY} = $company->as_text;
				#print "\t";
				#print $info{COMPANY} . NEWLINE;
			}
			if ($store == True) {
				#TODO: Replace by checking the size of hash
				push (@tmpCompanies, \%info);
				#if ( not exists $companiesDB{VIDLINK}{$info{COMPANY}} ) {
					$companiesDB{SCRAPED}{$info{COMPANY}} = True;
				#}
			}
		}
	}

	my $numCom = @tmpCompanies;
	if ($numCom > 0) {
		push @{ $personData{$id}{SCRAPED}{EXPERIENCE} }, @tmpCompanies;
		return True;
	} else {
		print "No experience info for person id $id\n";
	}
	return False;
}


sub scrape_education {
	# ToDo: Handle Degrees and Dates

	my $id = $_[0];

	my @tmpSchools;
	$personData{$id}{SCRAPED}{EXPERIENCE} = undef;
	if ( ( is_hole($id, SCHOOL) ) == False ) {
		#print "No school hole for person id $id\n";
		if ( $force == False ) {
			return False;
		}
	}

	my @s = $xpathRoot->findnodes( XPATH_SCHOOL );
	my $numSch = @s;
	if ($numSch == 0) {
		print "No school info for person id $id\n";
		return False;
	}

	#print "SCHOOLS: \n";
	foreach (@s) {
		my %info = ();
		my $node = $_;
		$info{NAME} = $node->as_text;
		#print "\t";
		#print $info{NAME} . NEWLINE;
		my $major = $node->findnodes( XPATH_MAJOR )->[0];
		if (defined $major) {
			#print "Found major\n";
			$major = $major->as_text;
			#print $major . NEWLINE;
			$info{MAJOR} = $major;
		}
		#print "Info: " . Dumper(\%info);
		push (@tmpSchools, \%info);
		#if ( not exists $schoolsDB{VIDLINK}{$info{NAME}} ) {
			$schoolsDB{SCRAPED}{$info{NAME}} = True;
		#}
	}

	$numSch = @tmpSchools;
	if ($numSch > 0) {
		push @{ $personData{$id}{SCRAPED}{SCHOOL} }, @tmpSchools;
		return True;
	}
	return False;
}


sub scrape_skills {
	my $id = $_[0];

	my @tmpSkills;
	$personData{$id}{SCRAPED}{SKILLS} = undef;
	if ( ( is_hole($id, SKILLS) ) == False ) {
		#print "No skills hole for person id $id\n";
		if ( $force == False ) {
			return False;
		}
	}

	my @s = $xpathRoot->findnodes( XPATH_SKILLS );
	my $numSk = @s;
	if ($numSk == 0) {
		print "No skills info for person id $id\n";
		return False;
	}

	#print "SKILLS: \n";
	foreach (@s) {
		my $sk = $_->as_text;
		#print "\t";
		#print $sk . NEWLINE;
		push (@tmpSkills, $sk);
		#if ( not exists $skillsDB{VIDLINK}{$sk} ) {
			$skillsDB{SCRAPED}{$sk} = True;
		#}
	}
	#foreach (@tmpSkills) {
		#print $_ . NEWLINE;
	#}
	$numSk = @tmpSkills;
	if ( $numSk > 0 ) {
		push @{ $personData{$id}{SCRAPED}{SKILLS} }, @tmpSkills;
		return True;
	}
	return False;
}

sub scrape_location {
	my $id = $_[0];

	$personData{$id}{SCRAPED}{CITY}    = '';
	$personData{$id}{SCRAPED}{STATE}   = '';
	$personData{$id}{SCRAPED}{COUNTRY} = '';
	if ( ( is_hole($id, CITY) ) == False ) {
		#print "No location hole for $id\n";
		if ( $force == False ) {
			return False;
		}
	}

	my $locality = $xpathRoot->findnodes(XPATH_LOCALITY)->[0];
	if (not defined $locality) {
		print "No locality info\n";
		return False;
	}

	$locality = $locality->as_text;
	print "Locality is $locality\n";
	my @location = split(/,/ , $locality );
	print "Location is @location\n";
	my $numItems = @location;
	print "num of items in location is $numItems\n";

	my $index = 0;
	my $loc;
	foreach $loc (@location) {
		# Strip all known prefixes, suffixes etc.
		$location[$index] = fix_str($loc);
		if ( exists $aliases{$location[$index]} ) {
			$location[$index] = $aliases{$location[$index]};
		}

		if ( not is_valid_str($location[$index]) ) {
			$personData{$id}{SCRAPED}{SCRAPE_STATUS} = "NonAsciiLocation";
		}
		$index++;
	}
	print "Fixed Location is @location\n";

	return True;

	if ( $personData{$id}{SCRAPED}{SCRAPE_STATUS} eq 'NonAsciiLocation') {
		$totals{'nonAsciiLocationProfiles'}++;
		warning "Location " . @location . " has non-ASCII chars";
		if ( $skipNonAsciiLocations ) {
			return False;
		}
	}

	my $city;
	my $state;
	my $country;

	my $tmpStr1;
	my $tmpStr2;

	if ($numItems == 3) {
		print "3 items in location\n";
		$city = $location[0];
		$state = $location[1];
		$country = $location[2];
		validate_location($city, $state, $country);
	} elsif ($numItems == 2) {
		print "only 2 items in location\n";
		$state = $location[0];
		$country = $location[1];
		if (not validate_location($city, $state, $country) ) {
			$city = $location[0];
			$state = $location[1];
			$country = '';
			if (not validate_location($city, $state, $country) ) {
				$city = $location[0];
				$state = '';
				$country = $location[1];
				validate_location($city, $state, $country);
			}
		}
	} elsif ($numItems == 1) {
		print "only 1 item in location\n";
		$loc = $location[0];
		$city = '';
		$state = '';
		$country = $location[0];

		$tmpStr1 = checkCountry($location[0]);
		# Handle the special case of Georgia, which is a country
		# 	as well as a U.S. state. We assume it to be U.S. state.
		if ($tmpStr1 and $tmpStr1 ne 'Georgia') {
			$personData{$id}{SCRAPED}{COUNTRY} = $tmpStr1;
			if ( $personData{$id}{SCRAPED}{COUNTRY} ne 'United States' ) {
				$totals{'nonUSCountryProfiles'}++;
				$personData{$id}{SCRAPED}{SCRAPE_STATUS} = 'NotUSCountry';
				if ($onlyUS) {
					warning "Expect country to be U.S. and got " . $location[0];
				}
			}
		} else {
			$tmpStr2 = checkState($location[0]);
			if ($tmpStr2) {
				print "first item $location[0] is a U.S. state\n";
				$personData{$id}{SCRAPED}{STATE} = $tmpStr2;
				#if ( exists $countryOfState{$tmpStr2} ) {
					#$personData{$id}{SCRAPED}{COUNTRY} = $countryOfState{$tmpStr2};
				#}
			} else {
				print "assuming first item is a city\n";
				$personData{$id}{SCRAPED}{CITY} = $location[0];
			}
		}
	} else {
		warning "expect only 1, 2 or 3 items in location";
		$totals{'problemProfiles'}++;
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = 'MoreThan3Items';
		last;
	}

	if ( $personData{$id}{SCRAPED}{SCRAPE_STATUS} eq "" ) {
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = 'OK';
	}
	

	$personData{$id}{SCRAPED}{STATE} =~ s|\.$||g; # Remove period char in the end, only for state
	if ( $personData{$id}{SCRAPED}{SCRAPE_STATUS} eq '' ) {
		# We got the file, but we didn't find locality or name.
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = 'NoData';
		$totals{'noDataProfiles'}++;
	}
	if ( $personData{$id}{SCRAPED}{SCRAPE_STATUS} ne 'OK' ) {
		if ($personData{$id}{SCRAPED}{SCRAPE_STATUS} ne "GetURLFailed") {
			#if ($keepProblemHTMLs) {
				#$fileIndex++;
				#my $tmpFile = 'problems/page' . $fileIndex . '.html';
				#getstore($link, $tmpFile);
			#}
		}
		return False;
	}
	return True;
}


sub get_url_content {
	my $id = $_[0];

	my $url = $personData{$id}{VIDLINK}{URL};

	if ( $url eq "" ) {
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = NO_URL_NAME;
		return False;
	}
	if ($numHttpProxies == 0) {
		return False;
	}
	if ($numHttpsProxies == 0) {
		return False;
	}

	if ( $url !~ m/^http/ ) {
		# Maybe the url looks like www.linkedin.com/foo/bar, prefix http
		$url = "http://" . $url;
		$personData{$id}{SCRAPED}{URL} = $url;
		#print "added http prefix, now url is " . $url . NEWLINE;
	}

	# Escape the quote char if present
	$url =~ s|'|\\'|g;

	if ( $url !~ m/www.linkedin/ ) {
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = FOREIGN;
		$totals{FOREIGN}++;
		if ( $onlyUS ) {
			warning "Foreign Profile found " . $url . " skipping...";
			return False;
		} else {
			warning "Foreign Profile found " . $url;
		}
	}

	if ( is_valid_str($url) == False) {
		$totals{NON_ASCII}++;
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = NON_ASCII;
		if ( $skipNonAsciiURLs ) {
			warning "Non-ASCII chars in URL, probably a foreign URL, " .
					"skipping " . $url . "...";
			return False;
		} else {
			warning "Non-ASCII chars in URL, probably a foreign URL, " .
					$url . "...";
		}
	}

	# set the proxy
	my $currHttpProxyIndex = $urlCount % $numHttpProxies;
	my $httpLine = $httpProxies[$currHttpProxyIndex];
	my @words = split(SPACE_CHAR, $httpLine);
	my $httpProxy = $words[0];
	$ENV{HTTP_PROXY} = $httpProxy;

	my $currHttpsProxyIndex = $urlCount % $numHttpsProxies;
	my $httpsLine = $httpsProxies[$currHttpsProxyIndex];
	@words = split(SPACE_CHAR, $httpsLine);
	my $httpsProxy = $words[0];
	$ENV{HTTPS_PROXY} = $httpsProxy;

	#print "Indexes are $currHttpProxyIndex-$currHttpsProxyIndex\n";
	#print "Proxies are $httpProxy-$httpsProxy \n";

	my $request = new HTTP::Request('GET', $url);
 	$response = $ua->request($request);
 	$httpCode = $response->code;
	$urlCount++;

	if (not $response->is_success) {
		# Switch the protocol between http & https in case of failure 
		my $tryURL = uc $url;
		my $protocol = substr $tryURL, 0, 5;
		if ($protocol eq 'HTTPS') {
			$tryURL =~ s|^HTTPS|HTTP|gi;
		} else {
			$tryURL =~ s|^HTTP|HTTPS|gi;
		}
		$request = new HTTP::Request('GET', $tryURL);
 		$response = $ua->request($request);
 		$httpCode = $response->code;
		if (not $response->is_success) {
			warning "Fetching of $url failed";
			$totals{FETCH_FAIL}++;
			$personData{$id}{SCRAPED}{SCRAPE_STATUS} = FETCH_FAIL;
			return False;
		}
	}

	#print $response->content;
	return True;
}

sub scrape_url {
	my $id = $_[0];

	if ( ( is_hole($id, URL) ) == True ) {
		$personData{$id}{SCRAPED}{SCRAPE_STATUS} = NO_URL_NAME;
		return False;
	}

	if ( (needs_scraping($id, True) ) == False ) {
		if ( $force == False ) {
			$personData{$id}{SCRAPED}{SCRAPE_STATUS} = NOT_NEEDED;
			return True;
		}
	}

	my $url = $personData{$id}{VIDLINK}{URL};

	if ( $url eq '' ) {
		# TODO: Change the query to filter out NULL linkedin URLs, then
		# we would not need this.
		# URL is supposed to be only NULL, not an empty str.
		warning 'Empty LinkedIn URL, should have been NULL for ' . 
				$personData{$id}{VIDLINK}{NAME} . 'with id ' . $id;
		return False;
	}

	#print "scraping URL <$url>\n";
	# Get the URL content
	if ( get_url_content($id) == False ) {
		return False;
	}
	# Grep content for name, locality etc.
	$xpathRoot = HTML::TreeBuilder::XPath->new;
	$xpathRoot->parse($response->decoded_content);
	$xpathRoot->eof();

	scrape_name $id;
	#scrape_location $id;
	if ( scrape_skills($id) == True ) {
		my @sk = @{ $personData{$id}{SCRAPED}{SKILLS} };
		#print "PARENT_FUNC:SKILLS for $id\n";
		#print "Dumper: " . Dumper(\@sk);
	}
	if ( scrape_education($id) == True ) {
		my @sch = @{ $personData{$id}{SCRAPED}{SCHOOL} };
		#print "PARENT_FUNC:EDUCATION for $id\n";
		#print "Dumper: " . Dumper(\@sch);
	}
	if ( scrape_experience($id) == True ) {
		if ( defined $personData{$id}{SCRAPED}{EXPERIENCE} ) {
			my @comp = @{ $personData{$id}{SCRAPED}{EXPERIENCE} };
			#print "PARENT_FUNC:EXPERIENCE for $id\n";
			#print "Dumper: " . Dumper(\@comp);
		}
	}
	scrape_photo $id;
	return True;
}


sub connect_to_vidlink {
	my %attr;
	$attr{mysql_socket} = get_mysql_socket();
	my $dbname = "DBI:mysql:" . get_mysql_db().";host=127.0.0.1";
	#$dbh=DBI->connect(
	#	$dbname,
	#	get_mysql_login(),
	#	get_mysql_password(),
	#	\%attr
	#) || die DBI->errstr;


    #DATA SOURCE NAME
    #my $dsn = "DBI:mysql:$dbname";
    #print $dsn;

    # PERL DBI CONNECT
    $dbh = $dbh=DBI->connect($dbname, get_mysql_login(), get_mysql_password())|| die DBI->errstr;
}

sub print_row {
	# ID has to exist
	my $id = $_[0];

	my $rowStr = ID . ': ' . $id;

	$rowStr = $rowStr . SPACE_CHAR . URL . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{URL} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{URL};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . NAME . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{NAME} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{NAME};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . CITY . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{CITY} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{CITY};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . STATE . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{STATE} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{STATE};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . COUNTRY . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{COUNTRY} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{COUNTRY};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . SKILLS . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{SKILLS} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{SKILLS};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . CURRENT_JOB . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{CURRENT_JOB} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{CURRENT_JOB};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . SCHOOL . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{SCHOOL} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{SCHOOL};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	$rowStr = $rowStr . SPACE_CHAR . PHOTO . ': ' ;
	if ( defined $personData{$id}{VIDLINK}{PHOTO} ) {
		$rowStr = $rowStr . $personData{$id}{VIDLINK}{PHOTO};
	} else {
		$rowStr = $rowStr . 'MISSING';
	}
	print "$rowStr\n";
}


sub init_holes {
	my $id = $_[0];

	$personData{$id}{VIDLINK}{URL_HOLE} = True;
	$personData{$id}{VIDLINK}{NAME_HOLE} = True;
	$personData{$id}{VIDLINK}{LOCATION_HOLE} = True;
	$personData{$id}{VIDLINK}{SKILLS_HOLE} = True;
	$personData{$id}{VIDLINK}{CURRENT_JOB_HOLE} = True;
	$personData{$id}{VIDLINK}{SCHOOL_HOLE} = True;
	$personData{$id}{VIDLINK}{PHOTO_HOLE} = True;
}

sub check_row_for_person_holes {
	my $id = $_[0];

	if ( defined $personData{$id}{VIDLINK}{URL} ) {
		$personData{$id}{VIDLINK}{URL_HOLE} = False;
	} else {
		$totals{URL_HOLE}++;
	}
	if ( defined $personData{$id}{VIDLINK}{NAME} ) {
		$personData{$id}{VIDLINK}{NAME_HOLE} = False;
	} else {
		$totals{NAME_HOLE}++;
	}
	if ( defined $personData{$id}{VIDLINK}{CITY} ) {
		$personData{$id}{VIDLINK}{LOCATION_HOLE} = False;
	} else {
		$totals{LOCATION_HOLE}++;
	}
}


sub get_vidlink_companies {
	my $query = "select c.name from company as c group by c.name;";
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();

	my @row;
	while (@row = $getDataStmt->fetchrow_array()) {
		$companiesDB{VIDLINK}{$row[0]} = True;
	}
	$getDataStmt->finish();
}

sub get_vidlink_schools {
	my $query = "select s.name from school as s group by s.name;";
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();

	my @row;
	while (@row = $getDataStmt->fetchrow_array()) {
		$schoolsDB{VIDLINK}{$row[0]} = True;
	}
	$getDataStmt->finish();
}

sub get_vidlink_skills {
	my $query = "select s.name from skill as s group by s.name;";
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();

	my @row;
	while (@row = $getDataStmt->fetchrow_array()) {
		$skillsDB{VIDLINK}{$row[0]} = True;
	}
	$getDataStmt->finish();
}

sub get_person_stmt {
	#my $testCond = ' where id = 34619 ';
	my $testCond = '';
	if ( defined $startId ) {
		$idCond = $idCond . " (p.id >= ". $startId . " ) and ";
	}
	if ( defined $endId ) {
		$idCond = $idCond . "(p.id <= ". $endId . " )";
	}
	#print "idCond: $idCond\n";
	if ($testCond eq '') {
		$testCond = $idCond;
	}
	if ($testCond eq ' where ') {
		$testCond = '';
	}

	my $query = << "END_QUERY";
	select p.id, p.url_linkedin, p.name
				from person as p
				$testCond
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	if ( $idCond ne ' where ' ) {
		$idCond = $idCond . " and ";
	}
	#print $dbh;
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_person_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		#print @row;
		$numRecords++;

		$id = $row[ID_INDEX];

		$personData{$id}{VIDLINK}{URL}  = $row[LINKEDIN_URL_INDEX];
		$personData{$id}{VIDLINK}{NAME} = $row[NAME_INDEX];

		push (@idList, $id);
		#print "id is $id\n";
		#print_row $id;
	}
	if ($limitRecords ne '') {
		$idStr = ' and p.id in (' . join(',', @idList) . ')';
	} else {
		$idStr = '';
	}
}


sub get_location_stmt {
	my $query = << "END_QUERY";
	select p.id, c.name, s.name, c1.name
				from person as p
				join city as c
				join state as s
				join country as c1
				$idCond
					p.city_id = c.id and
					c.state_id = s.id and
					s.country_id = c1.id
					$idStr
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_location_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		$id = $row[ID_INDEX];
		if ( not exists $personData{$id} ) {
			$numRecords++;
		}

		$personData{$id}{VIDLINK}{CITY}    = $row[CITY_INDEX];
		$personData{$id}{VIDLINK}{STATE}   = $row[STATE_INDEX];
		$personData{$id}{VIDLINK}{COUNTRY} = $row[COUNTRY_INDEX];

		#print_row $id;
	}
}


sub get_skills_stmt {
	my $query = << "END_QUERY";
	select p.id, s.name
				from person as p
				join ownskillset as o
				join skill as s
				$idCond
					p.id = o.person_id and
					o.skill_id = s.id
					$idStr
				group by p.id
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_skills_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		$id = $row[ID_INDEX];
		if ( not exists $personData{$id} ) {
			$numRecords++;
		}
		if ( defined $row[SKILL_INDEX] ) {
			$personData{$id}{VIDLINK}{SKILLS} = $row[SKILL_INDEX];
			#print_row $id;
		}
	}
}


sub get_job_stmt {
	my $query = << "END_QUERY";
	select p.id, c.name
				from person as p
				join companyworkedfor as cw
				join company as c
				$idCond
					p.id = cw.person_id and
					cw.company_id = c.id
					$idStr
				group by p.id
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_job_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		$id = $row[ID_INDEX];
		if ( not exists $personData{$id} ) {
			$numRecords++;
		}
		if ( defined $row[COMPANY_INDEX] ) {
			$personData{$id}{VIDLINK}{CURRENT_JOB} = $row[COMPANY_INDEX];
			#print_row $id;
		}
	}
}


sub get_school_stmt {
	my $query = << "END_QUERY";
	select p.id, s.name
				from person as p
				join schoolattended as sa
				join school as s
				$idCond
					p.id = sa.person_id and
					sa.school_id = s.id
					$idStr
				group by p.id
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_school_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		$id = $row[ID_INDEX];
		if ( not exists $personData{$id} ) {
			$numRecords++;
		}
		if ( defined $row[SCHOOL_INDEX] ) {
			$personData{$id}{VIDLINK}{SCHOOL} = $row[SCHOOL_INDEX];
			#print_row $id;
		}
	}
}


sub get_photo_stmt {
	my $query = << "END_QUERY";
	select p.id, i.path
				from person as p
				join images as i
				$idCond
					p.id = i.person_id
					$idStr
				group by p.id
				$limitRecords;
END_QUERY
	if ($debug == True) {
		print $query . NEWLINE;
	}
	$getDataStmt = $dbh->prepare($query);
	$getDataStmt->execute();
}


sub read_photo_data {
	my @row;
	my $id;

	while (@row = $getDataStmt->fetchrow_array()) {
		$id = $row[ID_INDEX];
		if ( not exists $personData{$id} ) {
			$numRecords++;
		}
		if ( defined $row[PHOTO_INDEX] ) {
			$personData{$id}{VIDLINK}{PHOTO} = $row[PHOTO_INDEX];
		}
		#print_row $id;
	}
}


sub scrape_person {
	my $id = $_[0];

	if ( ( is_hole($id, URL) ) == True ) {
		return False;
	}

	# TODO: Add a status column to vidlink
	# $personData{$id}{VIDLINK}{SCRAPE_STATUS} = $row[SCRAPE_STATUS_INDEX];
	#print "status is $personData{$id}{VIDLINK}{SCRAPE_STATUS}\n";
	#if ($status == 200) {
		#next;
	#}

	my $scrapeStatus = scrape_url $id;
	# It may be a good idea to pause between reading URLs
	# sleep 1;

	if ($scrapeStatus == False) {
		 #Scrape failed, log failure
		if ($httpCode eq '404') {
			warning "Scraping of " . $personData{$id}{VIDLINK}{URL} . " failed with 404";
			 #TODO: Set linkedin field to NULL as URL doesn't exist
		} else {
			# Not needed is a not a problem, no need to warn
			warning "Scraping of " . $personData{$id}{VIDLINK}{URL} .
				" failed with " . $personData{$id}{SCRAPED}{SCRAPE_STATUS} . NEWLINE;
		}
		return False;
	}
	#my %scrapedRecord = %{ $personData{$id}{SCRAPED} };
	#print "Scraped Record: " . Dumper(\%scrapedRecord);
}


sub scrape_data {
	my $id;

	for $id (sort keys %personData ) {
		scrape_person $id;
	}
}


sub hole_stats {
	$totals{NEEDS_SCRAPING}   = 0;
	$totals{URL_HOLE}         = 0;
	$totals{NAME_HOLE}        = 0;
	$totals{LOCATION_HOLE}    = 0;
	$totals{SKILLS_HOLE}      = 0;
	$totals{CURRENT_JOB_HOLE} = 0;
	$totals{SCHOOL_HOLE}      = 0;
	$totals{PHOTO_HOLE}       = 0;

	$totals{'Can Scrape Names'}    = 0;
	$totals{'Can Scrape Location'} = 0;
	$totals{'Can Scrape Skills'}   = 0;
	$totals{'Can Scrape Job'}      = 0;
	$totals{'Can Scrape School'}   = 0;
	$totals{'Can Scrape Photo'}    = 0;

	my $id;

	for $id (keys %personData ) {
		my $canBeScraped = True;
		if ( is_hole($id, URL) == True ) {
			$totals{URL_HOLE}++;
			$canBeScraped = False;
		} else {
			if (needs_scraping($id, False)) {
				$totals{NEEDS_SCRAPING}++;
			}
		}
		if ( is_hole($id, NAME) == True ) {
			$totals{NAME_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape Names'}++;
			}
		}
		if ( is_hole($id, CITY) == True ) {
			$totals{LOCATION_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape Location'}++;
			}
		}
		if ( is_hole($id, SKILLS) == True ) {
			$totals{SKILLS_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape Skills'}++;
			}
		}
		if ( is_hole($id, CURRENT_JOB) == True ) {
			$totals{CURRENT_JOB_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape Job'}++;
			}
		}
		if ( is_hole($id, SCHOOL) == True ) {
			$totals{SCHOOL_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape School'}++;
			}
		}
		if ( is_hole($id, PHOTO) == True ) {
			$totals{PHOTO_HOLE}++;
			if ($canBeScraped == True) {
				$totals{'Can Scrape Photo'}++;
			}
		}
	}
}


sub save_companies {
	foreach my $comp (sort keys %{ $companiesDB{SCRAPED} } ) {
		my $str = unidecode($comp);
		if ($str ne '' ) {
			print SQLF 'insert ignore into company (name) values("' . "$str" . '");'. NEWLINE;
		}
	}
}

sub save_skills {
	foreach my $sk (sort keys %{ $skillsDB{SCRAPED} } ) {
		my $str = unidecode($sk);
		if ($str ne '' ) {
			print SQLF 'insert ignore into skill (name) values("' . "$str" . '");'. NEWLINE;
		}
	}
}

sub save_schools {
	foreach my $sch (sort keys %{ $schoolsDB{SCRAPED} } ) {
		my $str = unidecode($sch);
		if ($str ne '' ) {
			print SQLF 'insert ignore into school (name) values("' . "$str" . '");' . NEWLINE;
		}
	}
}

sub save_scraped_data {
	my $sqlFile = $_[0];
	open(SQLF, '>', $sqlFile)
		or die "Cannot dump output, trouble opening $sqlFile";
	binmode(SQLF, ":utf8");

	save_skills;
	save_schools;
	save_companies;

	my $id;
	for $id (sort keys %personData ) {
		if ( is_hole($id, URL) == True ) {
			next;
		}
		#if ( is_hole($id, NAME) == True ) {
			if (defined $personData{$id}{SCRAPED}{NAME}) {
				my $name = $personData{$id}{SCRAPED}{NAME};
				if ( $name ne '' ) {
					#print "Going to save the name for $id\n";
					my $str = unidecode($name);
					print SQLF "update person set name = " . '"$str"' . "where id = $id;\n";

				}
			}
		#}

		#if ( is_hole($id, SKILLS) == True ) {
			if ( defined $personData{$id}{SCRAPED}{SKILLS} ) {
				my @skills = @{ $personData{$id}{SCRAPED}{SKILLS} };
				foreach (@skills) {
					my $sk = unidecode($_);
					if ($sk eq '' ) {
						next;
					}
					my $stmt = << "END_STMT";
insert ignore into ownskillset
	( person_id, skill_id)
	values( $id, (select id from skill where name = "$sk") );
END_STMT
					print SQLF $stmt;
				}
			}
		#}

		#if ( is_hole($id, SCHOOL) == True ) {
			#my @schools = @{ $personData{$id}{SCRAPED}{SCHOOL} };
			#foreach (@schools) {
				#my %sch = %{$_};
				#my $schName = unidecode($sch{NAME});
				#my $stmt;
				#my $major = '';
				#if (exists $sch{MAJOR} ) {
					#$major = unidecode($sch{MAJOR});
					#$stmt = << "END_STMT";
#insert ignore into schoolattended
	#( person_id, school_id, major)
	#values( $id, (select id from school where name = "$schName"), "$major" );
#END_STMT
				#} else {
 					#$stmt = << "END_STMT";
#insert ignore into schoolattended
	#( person_id, school_id)
	#values( $id, (select id from school where name = "$schName") );
#END_STMT
				#}
				#print SQLF $stmt;
			#}
		#}

		#if ( is_hole($id, SCHOOL) == True ) {
			if ( defined $personData{$id}{SCRAPED}{SCHOOL} ) {
				my @schools = @{ $personData{$id}{SCRAPED}{SCHOOL} };
				foreach (@schools) {
					my %sch = %{$_};
					my $output = False;
					my $ins = 'insert ignore into schoolattended (person_id';
					my $valClause = 'values(' . $id;
					if (exists $sch{NAME} ) {
						$output = True;
						my $schName = unidecode($sch{NAME});
						if ($schName eq '' ) {
							next;
						}
						$ins = $ins . ', school_id';
						$valClause = $valClause
								. ', (select id from school where name = "'
										. $schName . '")';
					}
					my $major = '';
					if (exists $sch{MAJOR} ) {
						$output = True;
						$major = unidecode($sch{MAJOR});
						$ins = $ins . ', major) ';
						$valClause = $valClause . ', "' . $major . '"); ';
					} else {
						$ins = $ins . ') ';
						$valClause = $valClause . '); ';
					}
					if ($output == True) {
						print SQLF $ins . $valClause . NEWLINE;
					}
				}
			}
		#}

		#if ( is_hole($id, EXPERIENCE) == True ) {
			if ( defined $personData{$id}{SCRAPED}{EXPERIENCE} ) {
				my @experiences = @{ $personData{$id}{SCRAPED}{EXPERIENCE} };
				foreach (@experiences) {
					my %exp = %{$_};
					my $output = False;
					my $ins = 'insert ignore into companyworkedfor (person_id';
					my $valClause = 'values(' . $id;
					if (exists $exp{COMPANY} ) {
						$output = True;
						my $compName = unidecode($exp{COMPANY});
						if ($compName eq '' ) {
							next;
						}
						$ins = $ins . ', company_id';
						$valClause = $valClause
								. ', (select id from company where name = "'
										. $compName . '")';
					}
					my $title = '';
					if (exists $exp{TITLE} ) {
						$output = True;
						$title = unidecode($exp{TITLE});
						$ins = $ins . ', jobTitle) ';
						$valClause = $valClause . ', "' . $title . '"); ';
					} else {
						$ins = $ins . ') ';
						$valClause = $valClause . '); ';
					}
					if ($output == True) {
						print SQLF $ins . $valClause . NEWLINE;
					}
				}
			}
		#}

		#if ( is_hole($id, PHOTO) == True ) {
			if (defined $personData{$id}{SCRAPED}{PHOTO}) {
				my $photo = $personData{$id}{SCRAPED}{PHOTO};
				if ( $photo ne '' ) {
					#print "Going to save the photo for $id\n";
					print SQLF "insert ignore into images (person_id, path) values($id, '$photo');\n";
				}
			}
		#}
	}
	close SQLF;
}


sub usage() {
	print "USAGE: perl $0 <-start <start_id>> <-end <end_id>>\n";
	print "\tstart_id is the minimum value of person.id\n";
	print "\tend_id is the maximum value of person.id\n";
	print "\tperl $0 -help prints this message\n";
	print "\tDependencies:\n";
	my @deps = ('DBI', 'DBD::mysql', 'LWP::Simple', 'HTTP::Request',
				'Data::Dumper', 'HTML::TreeBuilder 5',
				'HTML::TreeBuilder::XPath', 'Text::Unidecode');
	foreach (@deps) {
		print "\t\t $_\n";
	}
	exit;
}

sub my_main {
	binmode(STDOUT, ":utf8");
	$Data::Dumper::Sortkeys = True;

	my $argc = @ARGV;
	my $sqlFile = 'out.sql';
	#print "ARGV: @ARGV\n";
	while ($argc > 0) {
		if ($ARGV[0] eq '-start') {
			shift @ARGV; $argc--;
			#print "ARGV: @ARGV\n";
			$startId = $ARGV[0];
		} elsif ($ARGV[0] eq '-end') {
			shift @ARGV; $argc--;
			$endId = $ARGV[0];
		} elsif ($ARGV[0] eq '-limit') {
			shift @ARGV; $argc--;
			my $limit = $ARGV[0];
			if (lc($limit) eq 'none') {
				$limitRecords = '';
			} else {
				$limitRecords = " limit " . $limit;
			}
		} elsif ($ARGV[0] eq '-outsql') {
			shift @ARGV; $argc--;
			$sqlFile = $ARGV[0];
		} elsif ($ARGV[0] eq '-force') {
			$force = True;
		} elsif ($ARGV[0] eq '-debug') {
			$debug = True;
		} elsif ($ARGV[0] eq '-help') {
			usage();
		} else {
			usage();
		}
		shift @ARGV; $argc--;
	}

	loadProxies get_proxies_file();

	connect_to_vidlink();

	get_vidlink_companies();
	get_vidlink_schools();
	get_vidlink_skills();

	get_person_stmt();
	read_person_data();
	$getDataStmt->finish();
	#print "Got $numRecords (person) records\n";

	get_location_stmt();
	read_location_data();
	$getDataStmt->finish();
	#print "Got $numRecords (location) records\n";

	get_skills_stmt();
	read_skills_data();
	$getDataStmt->finish();
	#print "Got $numRecords (skills) records\n";

	get_job_stmt();
	read_job_data();
	$getDataStmt->finish();
	#print "Got $numRecords (job) records\n";

	get_school_stmt();
	read_school_data();
	$getDataStmt->finish();
	#print "Got $numRecords (school) records\n";

	get_photo_stmt();
	read_photo_data();
	$getDataStmt->finish();
	#print "Got $numRecords (photo) records\n";

	scrape_data();

	$dbh->disconnect();

	save_scraped_data($sqlFile);

	hole_stats();
	print "Number of Records: $numRecords\n";
	#print "idList: @idList\n";
	#print "personData: " . Dumper(\%personData);
	print "Totals: " . Dumper(\%totals);
}

my_main();

