#!/usr/bin/perl

use LWP::Simple;
use HTTP::Request;
use DBD::MySQL;
use warnings;
use strict;

use constant { true => 1, false =>0 };
use constant { NO_CHANGE => 0, PSEUDO_CHANGE =>1, REAL_CHANGE =>2 };
use constant { COUNTRY => 2, STATE =>1, CITY =>0 };
use constant { NUMFIELDS => 41 };

BEGIN {
	#$ENV{HTTPS_PROXY} = 'https://174.58.191.88:30569';
	#$ENV{HTTPS_PROXY} = 'https://123.138.68.170:9000';
	$ENV{HTTPS_PROXY} = 'https://208.69.232.156:8080';
	$ENV{HTTP_PROXY} = 'https://208.69.232.156:8080';
	$ENV{HTTPS_DEBUG} = 1;
}

# For collecting stats
my %totals = ();

# Data
my %countriesDB = ();
my %aliases = ();
my %countryOfState = (); # e.g. $countryOfState{'California'} = 'United States';
my %vidlinkStateOfCity = (); # Store the cities in vidlink db here
my %vidlinkIdOfState = (); # Store the states in vidlink db here

# Configuration Settings
my $onlyUS = false;
my $skipNonAsciiLinks = false;
my $skipNonAsciiLocations = false;
my $returnName = true;
my $returnCity = true;
my $returnState = true;
my $returnCountry = true;
my $returnPhoto = true;
my $delimiter = '	';
my $outputDelimiter = '	';
my $inputDelimiter = '	';
my $keepProblemHTMLs = false;
my $tmpLinkedInProfileFile = "out/tmp_linkedin_profile.html";
my @content;
my $response;
my $httpCode;
my $ua = new LWP::UserAgent;
my $fileIndex = 1;

my @personData;
my @httpsProxies;
my @httpProxies;
my $numHttpProxies = 0;
my $numHttpsProxies = 0;
my $urlCount = 0;

my %inputs = ();
$inputs{'id'} = '';
$inputs{'link'} = '';
$inputs{'name'} = '';
$inputs{'city'} = '';
$inputs{'state'} = '';
$inputs{'country'} = '';
$inputs{'photo'} = '';

my %outputs = ();
$outputs{'link'} = '';
$outputs{'firstName'} = '';
$outputs{'lastName'} = '';
$outputs{'city'} = '';
$outputs{'state'} = '';
$outputs{'country'} = '';
$outputs{'status'} = '';
$outputs{'photo'} = '';


my $proxiesFile = "proxies.tsv";
my $vidlinkPersonDumpFile = "vidlink_person.tsv";
my $inFile = ''; # For excel/tsv files
my $locationsFile = "locations.txt";
my $vidlinkCitiesFile = 'vidlink_city.tsv';
my $vidlinkStatesFile = 'vidlink_state.tsv';
my $outputDir = '.';

sub trim {
	(my $s = $_[0]) =~ s/^\s+|\s+$//g;
	return $s;
}

sub fixStr {
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

	if ($str eq "-") {$str = "";}
	return $str;
}

sub isValidStr {
	#Checks for chars that usually occur in URLs
	my $s = $_[0];
	if ($s !~ /^[\P{Latin}A-za-z0-9_:\-\.\ \?\/]+$/ ) {
		return false;
	}
	if ($s =~ /[\p{ASCII}A-za-z0-9_:\-\.\ \?\/]+$/ ) {
		return true;
	}
	return false;
}

sub warning {
	print "Warning: $_[0]\n";
}

sub msg {
	#print "Message: $_[0]\n";
}

sub loadLocations {
# 	Our file Format:
#		Have to use a different delimiter other than the blank char as
#		states like "North Dakota" have a space char in their names.
#		country countryName
#		state,stateName,optional <countryName>
#		alias,abbreviation,full_name
#		TBD: city,<withAll/OnlyState/OnlyCountry>,<state>,<country>
#		countryNames stored in a hash, check for existence of country name.
#		stateNames hash - key is stateName, value is countryName
#		aliases hash - key is aliasName, value is originalName
#	In addition, read cities, states, countries db from vidlink dump.

	my $locationsFile = 'locations.txt';
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
		@words = split(',', $line);
		$numWords = @words;
		$cmd = $words[0];
		if ($cmd eq 'country') {
			if ($numWords < 2) {
				warning 'country not specified at line # ' . $lineNum
						. ' in ' . $locationsFile . ', skipping $line';
				next;
			} else {
				#$personCountOfCountry{$words[1]} = 0;
				# countryDB hash - just check if country name exists.
				$countriesDB{$words[1]} = true;
			}
		} elsif ($cmd eq 'state') {
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
			#$personCountOfState{$words[1]} = 0;
		} elsif ($cmd eq 'alias') {
			if ($numWords < 3) {
				warning 'alias not specified correctly at line # ' .
						$lineNum . ' in ' . $locationsFile
						. ', skipping $line';
				next;
			}
			# aliases hash - key is aliasName, value is originalName
			$aliases{$words[1]} = $words[2];
		} elsif ($cmd eq 'city') {
			if ($numWords < 3) {
				warning 'city incorrectly specified at line # ' . $lineNum .
						' in ' . $locationsFile . ', skipping $line';
				next;
			}
			my $state = $words[2];
			# city hash - key is cityName, value is stateName
			#$stateOfCity{$words[1]} = $state;
		} else {
			warning 'Unknown command ' . $cmd . ' at line # ' . $lineNum
					. ' in ' . $locationsFile . ', skipping $line';
		}
	}

	# vidlink Dump to have cityId|CityName|stateID|stateName
	# vidlinkStateOfCity Hash - key is cityName, value is stateName
	open(FILE, $vidlinkCitiesFile)
		or die "vidlink cities file $vidlinkCitiesFile not found";
	@data = <FILE>;
	close FILE;

	foreach (@data) {
		chomp;
		$line = trim($_);
		@words = split('	', $line);
		$numWords = @words;
		if ( $numWords > 3) {
			$vidlinkStateOfCity{$words[0]} = $words[1];
		}
	}

	# vidlink Dump to have stateId|stateName|countryName
	# vidlinkIdOfState Hash - key is stateName, value is stateId
	open(FILE, $vidlinkStatesFile)
		or die "vidlink states file $vidlinkStatesFile not found";
	@data = <FILE>;
	close FILE;
	foreach (@data) {
		chomp;
		$line = trim($_);
		@words = split('	', $line);
		$numWords = @words;
		if ( $numWords > 1) {
			$vidlinkIdOfState{$words[1]} = $words[0];
		}
	}
}

sub checkCountry {
	my $str = $_[0];

	if ( exists $countriesDB{$str} ) {
		#msg "$str exists";
		return $str;
	}
	return "";
}

sub checkState {
	my $str = $_[0];

	# Handle the special case of Washington D.C, which can clash with the Washington state
	if ( $str eq 'Washington D.C.' ) {return ""; } # returning false

	# Handle the case of a period char in the end.
	$str =~ s|\.$||g;

	if ( exists $countryOfState{$str} ) { return $str; }

	# Handle the case of state being specified as e.g. California (San Francisco Bay Area)
	my @tmp = split(' ', $str);
	if ( exists $aliases{$tmp[0]} ) {
		$str = $aliases{$tmp[0]};
	}
	if ( exists $countryOfState{$tmp[0]} ) { return $str; }
	return ""; # return false
}

sub getURLContent {
	my $link = $_[0];
	my $outFile = $_[1];

	if ( $link eq "" ) {
		$outputs{'status'} = "NoLink";
		return false;
	}

	if ( $link !~ m/^http/ ) {
		# Maybe the link is of the type www.linkedin.com/foo/bar, add http
		$link = "http://" . $link;
		$outputs{'link'} = $link;
		#msg "added http prefix, now link is " . $link;
	}

	# Escape the quote char if present
	$link =~ s|'|\\'|g;

	if ( $link !~ m/www.linkedin/ and $onlyUS ){
		warning "Non US Profile found, skipping " . "$link";
		$totals{'nonUSDomainProfiles'}++;
		$outputs{'status'} = "NonUSDomain";
		return false;
	}

	if ( $skipNonAsciiLinks and !isValidStr($link) ) {
		warning "Non-ASCII chars in link, skipping " . "$link" . "...";
		$totals{'nonAsciiProfiles'}++;
		$outputs{'status'} = "NonAsciiLink";
		return false;
	}

	#set the proxy
	my $currHttpProxyIndex = $urlCount % $numHttpProxies;
	my $httpLine = $httpProxies[$currHttpProxyIndex];
	my @words = split(' ', $httpLine);
	my $httpProxy = $words[0];
	$ENV{HTTP_PROXY} = $httpProxy;

	my $currHttpsProxyIndex = $urlCount % $numHttpsProxies;
	my $httpsLine = $httpsProxies[$currHttpsProxyIndex];
	@words = split(' ', $httpsLine);
	my $httpsProxy = $words[0];
	$ENV{HTTPS_PROXY} = $httpsProxy;

	#print "indexes are $currHttpProxyIndex-$currHttpsProxyIndex, proxy is $httpProxy-$httpsProxy \n";

	my $request = new HTTP::Request('GET', $link);
 	$response = $ua->request($request);
 	$httpCode = $response->code;
	$urlCount++;

	#TODO: Switch the protocol in case of failure between http & https
	if (not $response->is_success) {
		warning "ua->request of $link failed";
		$totals{'failedProfiles'}++;
		$outputs{'status'} = "GetURLFailed";
		return false;
	}

	#print $response->content;
	return true;
}

sub getURLContentOld {
	my $link = $_[0];
	my $outFile = $_[1];

	if ( $link eq "" ) {
		$outputs{'status'} = "NoLink";
		return false;
	}

	if ( $link !~ m/^http/ ) {
		# Maybe the link is of the type www.linkedin.com/foo/bar, add http
		$link = "http://" . $link;
		$outputs{'link'} = $link;
		#msg "added http prefix, now link is " . $link;
	}

	# Escape the quote char if present
	$link =~ s|'|\\'|g;

	if ( $link !~ m/www.linkedin/ and $onlyUS ){
		warning "Non US Profile found, skipping " . "$link";
		$totals{'nonUSDomainProfiles'}++;
		$outputs{'status'} = "NonUSDomain";
		return false;
	}

	if ( $skipNonAsciiLinks and !isValidStr($link) ) {
		warning "Non-ASCII chars in link, skipping " . "$link" . "...";
		$totals{'nonAsciiProfiles'}++;
		$outputs{'status'} = "NonAsciiLink";
		return false;
	}

	my $retStatus;
	my $tries = 0;
	my $maxTries = 4;
	do {
		# Try at least 4 times.
		$retStatus = getstore($link, $outFile);
		$tries++;
	} while ( (is_error($retStatus)) and ($tries < $maxTries) );

	# Try a different protocol (http vs https)
	if (is_error($retStatus)) {
		my $protocol = substr($link, 0, 5); # Should get https or http:
		my $url;
		#msg "current protocol is " . $protocol;
		if ($protocol eq 'https' ) {
			$protocol = 'http';
			$url = substr($link, 5);
		} else {
			$protocol = 'https';
			$url = substr($link, 4);
		}

		#msg "trying " . $protocol;
		$link = $protocol . $url;
		$tries = 0;
		do {
			$retStatus = getstore($link, $outFile);
			$tries++;
		} while ( (is_error($retStatus)) and ($tries < $maxTries) );
		if (is_error($retStatus)) {
			warning "getstore of $link failed with $retStatus";
			$totals{'failedProfiles'}++;
			$outputs{'status'} = "GetURLFailed";
			return false;
		}
	}
	return true;
}

sub scrapeLink {
	my $link = $_[0];
	#msg "scraping link <$link>";

	#Reset everything to null
	$outputs{'status'} = '';
	$outputs{'link'} = $link;
	$outputs{'firstName'} = '';
	$outputs{'lastName'} = '';
	$outputs{'city'} = '';
	$outputs{'state'} = '';
	$outputs{'country'} = '';
	$outputs{'photo'} = '';

	# Local flags, to make sure that location and name is read only once
	my $localitySet = false;
	#my $nameSet = false;

	# Used when we are scraping linkedin Dirs like "pub/p-1-1-1" for profiles
	#$link = "http://www.linkedin.com" . $link;

	$totals{'processedProfiles'}++;

	# Get the URL content
	if ( !getURLContent($link, $tmpLinkedInProfileFile) ) {
		return false;
	}

	# Grep content for name, locality etc.
	my @content = split(/\n/, $response->content);
	while (@content) {
		my $line = shift @content;
		#print "profile line is $line\n";
		chomp $line;
		$line = trim($line);

		#if ($localitySet and $nameSet) {
		#}
		if ($localitySet) {
			if ( $outputs{'status'} eq "" ) {
				$outputs{'status'} = 'OK';
			}
			last;
		}

		# Don't bother about name right now
		#if ( $line =~ m/<span class="given-name">(.*?)<\/span>/ ) {
			#$outputs{'firstName'} = "$1";
		#}

		#if ( $line =~ m/<span class="family-name">(.*?)<\/span>/ ) {
			#$outputs{'lastName'} = "$1";
			#$nameSet = true;
		#} elsif ( $line =~ m/<span class="full-name">(.*?)<\/span>/ ) {
			#$outputs{'lastName'} = "$1";
			#$nameSet = true;
		#}

		if ( $line =~ m/<span class="locality">/ ) {
			my $locality = "";

			if ( $line eq '<span class="locality">' ) {
				#$locality = <FILE1>;
				$locality = shift @content;
				#msg "1. locality is $locality";
			} else {
				#msg "locality is in current line itself";
				if ( $line =~ m/<span class="locality">(.*?)<\/span>/ ) {
					$locality = "$1";
					#print "2. locality is $locality";
				}
			}
			#msg "locality line is $line";
			$locality = trim($locality);
			#msg "locality is $locality";
			$localitySet = true;

			my	@location = split(/,/ , $locality );
			my $index = 0;
			foreach my $loc (@location) {
				# Strip all known prefixes, suffixes etc.
				$location[$index] = fixStr($loc);
				if ( exists $aliases{$location[$index]} ) {
					$location[$index] = $aliases{$location[$index]};
				}

				if ( $skipNonAsciiLocations and !isValidStr($location[$index]) ) {
					$outputs{'status'} = "NonAsciiLocation";
				}
				$index++;
			}
			if ( $outputs{'status'} eq 'NonAsciiLocation') {
				$totals{'nonAsciiLocationProfiles'}++;
				warning "Location has non-ASCII chars";
				last;
			}
			#msg "location is @location";
			my $numItems = @location;
			#msg "num of items in location is $numItems";
			my $tmpStr1;
			my $tmpStr2;
			if ($numItems == 3) {
				#msg "3 items in location";

				$outputs{'country'} = checkCountry( $location[2] );
				if ( $outputs{'country'} ) {
					if ( $outputs{'country'} ne "United States" ) {
						$totals{'nonUSCountryProfiles'}++;
						$outputs{'status'} = 'NotUSCountry';
						if ($onlyUS) {
							warning "Expect country to be U.S. and got " . $location[2];
							#last;
						}
					}
				} else {
					$totals{'unknownCountryProfiles'}++;
					$outputs{'status'} = 'UnknownCountry';
					warning $location[2] . " is not in countries db";
					# ToDO: check against vidlink_countries, add if necessary
					#last;
				}

				$outputs{'state'} = $location[1];
				my $tmpStr = checkState($outputs{'state'});
				if ( !$tmpStr ) {
					warning 'State <' . $location[1] . "> is not in states db";
					$totals{'unknownStateProfiles'}++;
				}

				$outputs{'city'} = $location[0];
			} elsif ($numItems == 2) {
				#msg "only 2 items in location";

				# Handle the special case of Georgia, which is a country
				# as well as a U.S. state. We assume it to be U.S. state.
				$tmpStr1 = checkCountry($location[1]);
				if ($tmpStr1 and $tmpStr1 ne 'Georgia') {
					$outputs{'country'} = $tmpStr1;
					if ( $outputs{'country'} ne 'United States' ) {
						$totals{'nonUSCountryProfiles'}++;
						$outputs{'status'} = 'NotUSCountry';
						if ($onlyUS) {
							warning "Expect country to be U.S. and got " . $location[1];
							last;
						}
					}
					$tmpStr2 = checkState($location[0]);
					if ($tmpStr2) {
						#msg "first item $location[0] is a U.S. state";
						$outputs{'state'} = $tmpStr2;
					} else {
						#msg "assuming first item is a city";
						$outputs{'city'} = $location[0];
					}
				} else {
					$tmpStr2 = checkState($location[1]) ;
					if ($tmpStr2) {
						#msg "second item $location[1] is a U.S. state";
						$outputs{'state'} = $tmpStr2;
						if ( exists $countryOfState{$tmpStr2} ) {
							$outputs{'country'} = $countryOfState{$tmpStr2};
						}
					} else {
						warning "Sanity Check: second item $location[1] - $outputs{'country'} - is neither a country nor a U.S. state";
						$totals{'problemProfiles'}++;
						$outputs{'status'} = 'UnknownStateOrCountry';
						# TODO: Need to add this to a country (as all U.S.
						# states are known, and we care about only U.S.
						# right now.)
						#last;
					}
					$outputs{'city'} = $location[0];
				}
			} elsif ($numItems == 1) {
				#msg "only 1 item in location";

				$tmpStr1 = checkCountry($location[0]);
				# Handle the special case of Georgia, which is a country
				# as well as a U.S. state. We assume it to be U.S. state.
				if ($tmpStr1 and $tmpStr1 ne 'Georgia') {
					$outputs{'country'} = $tmpStr1;
					if ( $outputs{'country'} ne 'United States' ) {
						$totals{'nonUSCountryProfiles'}++;
						$outputs{'status'} = 'NotUSCountry';
						if ($onlyUS) {
							warning "Expect country to be U.S. and got " . $location[0];
						}
					}
				} else {
					$tmpStr2 = checkState($location[0]);
					if ($tmpStr2) {
						#msg "first item $location[0] is a U.S. state";
						$outputs{'state'} = $tmpStr2;
						if ( exists $countryOfState{$tmpStr2} ) {
							$outputs{'country'} = $countryOfState{$tmpStr2};
						}
					} else {
						#msg "assuming first item is a city";
						$outputs{'city'} = $location[0];
					}
				}
			} else {
				warning "expect only 1, 2 or 3 items in location";
				$totals{'problemProfiles'}++;
				$outputs{'status'} = 'MoreThan3Items';
				last;
			}
		}
	}

	$outputs{'state'} =~ s|\.$||g; # Remove period char in the end, only for state
	if ( $outputs{'status'} eq '' ) {
		# We got the file, but we didn't find locality or name.
		$outputs{'status'} = 'NoData';
		$totals{'noDataProfiles'}++;
	}
	if ( $outputs{'status'} ne 'OK' ) {
		if ($outputs{'status'} ne "GetURLFailed") {
			if ($keepProblemHTMLs) {
				$fileIndex++;
				my $tmpFile = 'problems/page' . $fileIndex . '.html';
				getstore($link, $tmpFile);
			}
		}
		return false;
	}
	return true;
}

sub printTotals {
	my $statFile = $outputDir . '/' . (substr $inFile, 0, -4) . "_stats.txt";
	open(STATF, '>', $statFile)
		or die "Cannot dump output, trouble opening $statFile";

	my $successes = $totals{'processedProfiles'}
						- $totals{'failedProfiles'}
						- $totals{'noDataProfiles'}
						- $totals{'problemProfiles'};
	if ($onlyUS) {
		$successes = $successes
						- $totals{'nonUSDomainProfiles'}
						- $totals{'nonAsciiProfiles'}
						- $totals{'nonAsciiLocationProfiles'}
						- $totals{'nonUSStateProfiles'}
						- $totals{'nonUSCountryProfiles'}
						- $totals{'unknownStateProfiles'}
						- $totals{'unknownCountryProfiles'};
	}

	# Log the totals
	print STATF "\n\nProcessed $totals{'processedProfiles'} profiles\n";
	print STATF "Successes = $successes\n\n";
	print STATF "New cities = $totals{'cityNotInDB'}\n";
	print STATF "City changes from db = $totals{'cityDiffs'}\n";
	print STATF "State changes from db = $totals{'stateDiffs'}\n";
	print STATF "Country changes from db = $totals{'countryDiffs'}\n";
	print STATF "No differences from db = $totals{'noDiffs'}\n\n";

	print STATF "Unknown State Profiles = $totals{'unknownStateProfiles'}\n";
	print STATF "Unknown Country Profiles = $totals{'unknownCountryProfiles'}\n";
	print STATF "Non-US Domain Profiles = $totals{'nonUSDomainProfiles'}\n";
	print STATF "Non-US Country Profiles = $totals{'nonUSCountryProfiles'}\n";
	print STATF "Non-US State Profiles = $totals{'nonUSStateProfiles'}\n";
	print STATF "Profiles with non-ASCII chars = $totals{'nonAsciiProfiles'}\n";
	print STATF "Profiles I could not read = $totals{'failedProfiles'}\n";
	print STATF "Profiles that didn't have the data we need = $totals{'noDataProfiles'}\n";
	print STATF "Profiles with non-ASCII chars in their location = $totals{'nonAsciiLocationProfiles'}\n";
	print STATF "Profiles with locations we could not parse correctly = $totals{'problemProfiles'}\n";

	close STATF;

	# print them as well
	print "\n\nProcessed $totals{'processedProfiles'} profiles\n";
	print "Successes = $successes\n\n";
	print "New cities = $totals{'cityNotInDB'}\n";
	print "City changes from db = $totals{'cityDiffs'}\n";
	print "State changes from db = $totals{'stateDiffs'}\n";
	print "Country changes from db = $totals{'countryDiffs'}\n";
	print "No differences from db = $totals{'noDiffs'}\n\n";

	print "Unknown State Profiles = $totals{'unknownStateProfiles'}\n";
	print "Unknown Country Profiles = $totals{'unknownCountryProfiles'}\n";
	print "Non-US Domain Profiles = $totals{'nonUSDomainProfiles'}\n";
	print "Non-US Country Profiles = $totals{'nonUSCountryProfiles'}\n";
	print "Non-US State Profiles = $totals{'nonUSStateProfiles'}\n";
	print "Profiles with non-ASCII chars = $totals{'nonAsciiProfiles'}\n";
	print "Profiles I could not read = $totals{'failedProfiles'}\n";
	print "Profiles that didn't have the data we need = $totals{'noDataProfiles'}\n";
	print "Profiles with non-ASCII chars in their location = $totals{'nonAsciiLocationProfiles'}\n";
	print "Profiles with locations we could not parse correctly = $totals{'problemProfiles'}\n";
}

sub initStats {
	$totals{'cityDiffs'} = 0;
	$totals{'cityNotInDB'} = 0;
	$totals{'countryDiffs'} = 0;
	$totals{'failedProfiles'} = 0;
	$totals{'noDataProfiles'} = 0;
	$totals{'noDiffs'} = 0;
	$totals{'nonAsciiLocationProfiles'} = 0;
	$totals{'nonAsciiProfiles'} = 0;
	$totals{'nonUSCountryProfiles'} = 0;
	$totals{'nonUSDomainProfiles'} = 0;
	$totals{'nonUSStateProfiles'} = 0;
	$totals{'problemProfiles'} = 0;
	$totals{'stateDiffs'} = 0;
	$totals{'unknownStateProfiles'} = 0;
	$totals{'unknownCountryProfiles'} = 0;
	$totals{'processedProfiles'} = 0;
}

sub loadVidlinkPersons {
	# Read the records
	# vidlink dump expected to have id|url|name|city|state|country
	open(FILE, $vidlinkPersonDumpFile)
		or die "vidlink persons file $vidlinkPersonDumpFile not found";
	@personData = <FILE>;
	close FILE;
	#msg "person data is " . @personData;
}

sub loadTSV {
	# Read the records
	# Ruby xlsx has name|email1|email2|email3|Phone|URL|FieldWithNoName
	open(FILE, $inFile)
		or die "candidate data file $inFile not found";
	@personData = <FILE>;
	close FILE;
	#msg "person data is " . @personData;
}

sub loadProxies {
	open(FILE, $proxiesFile)
		or die "proxies file $proxiesFile not found";
	my @proxies = <FILE>;
	close FILE;
	foreach (@proxies) {
		my $proxy = $_;
		my @words = split('\t', $proxy );
		if (lc($words[1]) eq 'http') {
			$httpProxies[$numHttpProxies] = $proxy;
			$numHttpProxies++;
		} else {
			$httpsProxies[$numHttpsProxies] = $proxy;
			$numHttpsProxies++;
		}
	}
	#$numProxies = @proxies;
	msg "HTTP Proxies are " . @httpProxies;
	msg "HTTPS Proxies are " . @httpsProxies;
}

sub setCity {
	my $inp = $inputs{'city'};
	my $outp = $outputs{'city'};

	if ($outp eq "") {
		my $trimmedInput = fixStr($inp);
		if ( $trimmedInput eq $inp ) {
			return NO_CHANGE;
		}
		$outputs{'city'} = $trimmedInput;
		return REAL_CHANGE;
	}
	if ($outp eq $inp) { return NO_CHANGE };

	if ( $inp eq "" ) { return PSEUDO_CHANGE; }
	if ( $inp eq "-" ) { return PSEUDO_CHANGE; }

	return REAL_CHANGE;
}

sub setState {
	my $inp = $inputs{'state'};
	my $outp = $outputs{'state'};

	if ($outp eq "") {
		my $trimmedInput = fixStr($inp);
		if ( $trimmedInput eq $inp ) {
			return NO_CHANGE;
		}
		$outputs{'state'} = $trimmedInput;
		return REAL_CHANGE;
	}
	if ($outp eq $inp) { return NO_CHANGE };

	if ( $inp eq "" ) { return PSEUDO_CHANGE; }
	if ( $inp eq "-" ) { return PSEUDO_CHANGE; }

	if ($outp eq "United States") {
		# If database has more specific info than linkedin, don't update
		if ( ( exists $countryOfState{$inp} )
				and ($countryOfState{$inp} eq "United States") ) {
				return NO_CHANGE;
		}
	}

	return REAL_CHANGE;
}

sub setCountry {
	my $inp = $inputs{'country'};
	my $outp = $outputs{'country'};

	if ($outp eq "") {
		my $trimmedInput = fixStr($inp);
		if ( $trimmedInput eq $inp ) {
			return NO_CHANGE;
		}
		$outputs{'country'} = $trimmedInput;
		return REAL_CHANGE;
	}
	if ($outp eq $inp) { return NO_CHANGE };

	if ( $inp eq "" ) { return PSEUDO_CHANGE; }
	if ( $inp eq "-" ) { return PSEUDO_CHANGE; }

	return REAL_CHANGE;
}

sub scrapeBlock {
	my $start = $_[0];
	my $step = $_[1];
	my $end = $start + $step - 1;

	my $currLineNum = 0;
	foreach (@personData) {
		my $line = $_;

		# Skip the first $start lines, then read the next $step lines
		$currLineNum++;
		if ($currLineNum < $start) { next; }
		if ($currLineNum > $end) { last; }
		if ($currLineNum % 500 == 0) { sleep 60; }

		# Clean the line
		chomp $line;
		$line =~ s|'|\\'|g;
		$line =~ s|"|\\"|g;

		# Parse the line
		my @data = split($inputDelimiter, $line );
		my $len = @data;
		#print "line is " . $line . "<>\n";
		#print "len is " . $len . "<>\n";
		# Force len to be 41, perl seems to ignore delimiters at the end
		#	of a line. Maybe something do with the fact that delim is a
		#	"space".
		$len = NUMFIELDS;
		my $tmp = 0;
		while ($tmp < $len) {
			if (not exists $data[$tmp]) {
				$data[$tmp] = "";
			}
			if ($data[$tmp] ne '') {
				trim($data[$tmp]);
			}
			#print $tmp . ".	" . $data[$tmp] . "\n";
			$tmp++;
		}
		#print "line is $line\n";
		print LOGF "INPUT" . $delimiter . $line . "\n";

		# Init the inputs hash

		# This works for union of all the files that we have seen
		#ID	Name	Email	Phone	City	State	School1	Degree1	Major1
		#School2	Degree2	Major2	School3	Degree3	Major3	School4	Degree4
		#Major4	Title	Company	Skillset	LinkedIn	PersonalURL
		#ResumeURL	GitHub	Quora	StackOf	AngelsList	Twitter	Facebook
		#Indeed	About.me	URL	URL2	URL3	Email2	Email3	Location
		#NewCity	NewState	NewCountry	FirstName	LastName
		# We will be filling NewCity, NewState and NewCountry

		$inputs{'name'}      = $data[1];
		$inputs{'link'}      = $data[21];
		$inputs{'phone'}     = $data[7];
		$inputs{'city'}    = $data[4];
		$inputs{'state'}   = $data[5];
		if ( exists $countryOfState{$inputs{'state'}} ) {
			$inputs{'country'} = $countryOfState{$inputs{'state'}};
		} else { $inputs{'country'} = ''; }

		#msg $inputs{'city'} . " " . $inputs{'state'} . " " . $inputs{'link'};

		# Process the URL
		my $status;
		if ( $inputs{'link'} ne '' ) {
			$status = scrapeLink $inputs{'link'};
		} else {
			print TSVF $line . "\n";
			next;
		}
		# It may be a good idea to pause between reading URLs
		#sleep 1;
		my $currStatus = $outputs{'status'};
		if (!$status) {
			# ScrapeLink failed, log failure
			print LOGF $currStatus . $delimiter . $line . "\n";
			print PROBS $currStatus . $delimiter . $line . "\n";
			# If the status is one of the following, we have no location
			# data.
			if ( $currStatus eq 'GetURLFailed'
				or $currStatus eq 'NoLink'
				or $currStatus eq 'MoreThan3Items'
				or $currStatus eq 'NoData' ) {
					if ($httpCode eq '404') {
						warning "Scraping of " . $outputs{'link'} . " failed with 404";
						# Set linkedin field to NULL as this URL doesn't exist
						$data[21] = '';
						$line = join( '	', @data);
					
					} else {
						warning "Scraping of " . $outputs{'link'} . " failed";
					}
					print TSVF $line . "\n";
					next;
			}
		}

		# Make sure that city,state,country values are filled appropriately
		#	if one of them is NULL.
		if ( $outputs{'state'} eq "" ) {
			# See whether you can fill this up from db
			if ( exists $vidlinkStateOfCity{$outputs{'city'}} ) {
				$outputs{'state'} = $vidlinkStateOfCity{$outputs{'city'}};
			}
		}
		if ( $outputs{'country'} eq "" ) {
			if ( exists $countryOfState{$outputs{'state'}} ) {
				$outputs{'country'} = $countryOfState{$outputs{'state'}};
			}
		}

		if ( $outputs{'city'} eq "" ) {
			if ( $outputs{'state'} ne "" ) {
				$outputs{'city'} = $outputs{'state'};
			} else {
				if ( $outputs{'country'} ne "" ) {
					$outputs{'city'} = $outputs{'country'};
					$outputs{'state'} = $outputs{'country'};
				}
			}
		} else {
			if ( $outputs{'state'} eq "" ) {
				if ( $outputs{'country'} ne "" ) {
					$outputs{'state'} = $outputs{'country'};
				}
			}
		}

		print LOGF $currStatus . $delimiter . $line . "\n";

		# Fill our data from outputs.
		my $someChange = false;
		my $changeCity = setCity;
		my $currCity = $outputs{'city'};
		if ( $changeCity != NO_CHANGE ) {
			$totals{'cityDiffs'}++;
			$someChange = true;
		}

		my $changeState = setState;
		my $currState = $outputs{'state'};
		if ($changeState != NO_CHANGE) {
			$totals{'stateDiffs'}++;
			$someChange = true;
		}

		my $changeCountry = setCountry;
		my $currCountry = $outputs{'country'};
		if ($changeCountry != NO_CHANGE) {
			$totals{'countryDiffs'}++;
			$someChange = true;
		}

		if (not $someChange) {
			$totals{'noDiffs'}++;
		}
		# Check for vidlink
		print LOGF "RESULT" . $delimiter . join($delimiter, @data) . "\n";

		# Write the appropriate SQL command
		if ($changeCity != NO_CHANGE) {
			if ( not exists $vidlinkStateOfCity{$currCity} ) {
				# Add city to the city table
				# We are dealing with U.S. only right now, so don't worry
				# about state & country for now,
				$totals{'cityNotInDB'}++;
				print LOGF "Warning: city " . $currCity . " doesn't exist in db, adding it" . "\n";
				if ( not exists $vidlinkIdOfState{$currState} ) {
					print LOGF "state <" . $currState . "> doesn't exist in db, skipping this" . "\n";
					print TSVF $line . "\n";
					next;
				} else {
					my $stateId = $vidlinkIdOfState{$currState};
					if ( $currState ne "" ) {
						$vidlinkStateOfCity{$currCity} = $currState;
					}

				}
			}
		}

		if ($changeState) {
			print LOGF "Warning: state changed from " . $inputs{'state'} . " to " . $currState . "\n";
		}

		if ($changeCountry) {
			print LOGF "Warning: country changed from " . $inputs{'country'} . " to " . $outputs{'country'}. "\n";
		}
		if ($changeCity or $changeState or $changeCountry) {
			print DIFFS "INPUT : " . $inputs{'city'} . ", " . $inputs{'state'} . ", " . $inputs{'country'} . ".\n";
			print DIFFS "RESULT: " . $currCity . ", " . $currState . ", " . $currCountry . ".\n";
		}

		$data[38] = $currCity;
		$data[39] = $currState;
		$data[40] = $currCountry;
		$line = join( '	', @data);
		print TSVF $line . "\n";
	}

	if ($end < $currLineNum) {$end = $currLineNum;}
	print LOGF "Processed records # " . $start . " to " . $end . ".\n";
}

my $start = 0;
my $step = 0;
my $end = 0;

my $ARGC = @ARGV;
while ($ARGC > 0) {
	if ($ARGV[0] eq '-start') {
		shift; $ARGC--;
		$start = $ARGV[0];
	} elsif ($ARGV[0] eq '-end') {
		shift; $ARGC--;
		$end = $ARGV[0];
	} elsif ($ARGV[0] eq '-step') {
		shift; $ARGC--;
		$step = $ARGV[0];
	} elsif ($ARGV[0] eq '-outputDir') {
		shift; $ARGC--;
		$outputDir = $ARGV[0];
	} else {
		$inFile = $ARGV[0]; # Excel/tsv file
		$inputDelimiter = '	';
		#warning "Unknown arg $ARGV[0], ignoring";
	}
	shift; $ARGC--;
}

if ($inFile eq '') {
	loadVidlinkPersons;
	$inFile = $outputDir . "/" . 'vidlink_person.inp';
} else {
	# Excel files from Hung (which are converted to tsv) have differnet
	#	number of columns, need to check every time whether we get the
	#	URL column correctly.
	loadTSV;
}
my $numData = @personData;

if ($start == 0) { $start = 1; }
if ($end == 0) { $end = 50000; }
if ($end > $numData) { $end = $numData; }
if ($end <= $start) { $end = $start; }
if ($step == 0) { $step = 5000; }
if ($step > ($end-$start)) { $step = $end-$start+1; }

if ($outputDir eq '') { $outputDir = "$start" . "_" . "$end"; }

loadLocations;
loadProxies;

# Write URLs that failed into problems file
my $probFile = $outputDir . '/' . (substr $inFile, 0, -4) . "_failed_urls.txt";
open(PROBS, '>', $probFile)
	or die "Cannot dump output, trouble opening $probFile";

my $diffFile = $outputDir . '/' . (substr $inFile, 0, -4) . "_diffs.txt";
open(DIFFS, '>', $diffFile)
	or die "Cannot dump output, trouble opening $diffFile";

# Log whatever happens
my $logFile = $outputDir . '/' . (substr $inFile, 0, -4) . ".log";
open(LOGF, '>', $logFile)
	or die "Cannot dump output, trouble opening $logFile";

# Print a tsv file with the same fields
my $tsvOutFile = $outputDir . '/' . (substr $inFile, 0, -4) . ".tsv";
open(TSVF, '>', $tsvOutFile)
	or die "Cannot dump output, trouble opening $tsvOutFile";

my $curr = $start;
my $currProxyNum = 0;

initStats;
while ($curr <= $end) {

	# scrape a block, wait for 10 mins, scrape the next block.
	scrapeBlock($curr,$step);
	#sleep 600;
	$curr = $curr + $step;
}

printTotals;

close LOGF;
close PROBS;
close DIFFS;
close TSVF;
