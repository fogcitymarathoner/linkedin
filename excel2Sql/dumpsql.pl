#!/usr/bin/perl

#-----------------------------------------------------------------------
# Script:		dumpsql_from_excel.pl
# Purpose:		Read output from excel.pl and dump out insert/update stmts
#			 	to add/update candidate info into vidlink
# Author:	 	RV
# Creation:		Sep/Oct 2014
# Notes:	 	Multiple formats of excel files meant several revisions
# Algorithm:
#-----------------------------------------------------------------------

use warnings;
use strict;
use Data::Dumper;

use constant { true => 1, false =>0 };
use constant { REPEAT => 0};
use constant { NEWLINE => "\n"};
#Output columns: (41)
#	ID	Name	Email	Phone	City
#	State School1	Degree1	Major1	School2
#	Degree2	Major2	School3	Degree3	Major3
#	School4	Degree4	Major4	Title	Company
#	Skillset	Linkedin PersonalUrl	ResumeUrl	GitHub
#	Quora	StackOverflow	AngelList	Twitter	Facebook
#	Indeed	About.me	URL	URL2	URL3
#	Email2	Email3	Location	NewCity	NewState
#	NewCountry
use constant { ID              => 0,
				NAME           => 1,
				EMAIL          => 2,
				PHONE          => 3,
				CITY           => 4,
				STATE          => 5,
				SCHOOL1        => 6,
				DEGREE1        => 7,
				MAJOR1         => 8,
				SCHOOL2        => 9,
				DEGREE2        => 10,
				MAJOR2         => 11,
				SCHOOL3        => 12,
				DEGREE3        => 13,
				MAJOR3         => 14,
				SCHOOL4        => 15,
				DEGREE4        => 16,
				MAJOR4         => 17,
				TITLE          => 18,
				COMPANY        => 19,
				SKILLSET       => 20,
				LINKEDIN       => 21,
				PERSONAL_URL   => 22,
				RESUME_URL     => 23,
				GITHUB         => 24,
				QUORA          => 25,
				STACK_OVERFLOW => 26,
				ANGELS_LIST    => 27,
				TWITTER        => 28,
				FACEBOOK       => 29,
				INDEED         => 30,
				ABOUT_ME       => 31,
				OTHER_URL1     => 32,
				OTHER_URL2     => 33,
				OTHER_URL3     => 34,
				EMAIL2         => 35,
				EMAIL3         => 36,
				LOCATION       => 37,
				NEW_CITY       => 38,
				NEW_STATE      => 39,
				NEW_COUNTRY    => 40 };

######		Globals			############
my %countryOfState = (); # state->country mapping
my %stateOfCity = (); # city->state mapping

my %personCountOfCountry = (); # Number of Candidates from this country
my %personCountOfState   = (); # Number of Candidates from this state
my %personCountOfCity    = (); # Number of Candidates from this city

# Keep a count of candidates for each skill, company, school etc.
# Also insert # each skill, company, school only once
my %personCountOfSkill   = ();
my %personCountOfSchool  = ();
my %personCountOfCompany = ();

# Sometimes, a uniq id (say, a linkedin URL) is repeated twice. This will
#	count the number of entries for each uniq id
my %personCountOfIdentifier = ();

# Names used in the input may be an alias (e.g. CA for California)
# My own auxilliary file to store aliases in 'locations.txt' 
# Format is alias,alias_name,original_name
my %aliases = ();

# This should never be filled up, as linkedIn is the default identifier
#my %linkedInOfIdentifier = ();

my %nameOfIdentifier = ();
my %emailOfIdentifier = ();
my %phoneOfIdentifier = ();
my %facebookOfIdentifier = ();
my %twitterOfIdentifier = ();
my %githubOfIdentifier = ();
my %stackOverflowOfIdentifier = ();
my %angelsListOfIdentifier = ();
my %quoraOfIdentifier = ();
my %personalUrlOfIdentifier = ();
my %resumeUrlOfIdentifier = ();
my %cityOfIdentifier = ();
my %stateOfIdentifier = ();
my %countryOfIdentifier = ();

#my %indeedOfIdentifier = (); # Unused
#my %aboutMeOfIdentifier = (); # Unused


# Number of unique candidates added (Count duplication of identifiers)
my $personCount = 0;

########	Utility Functions	##############
sub warning {
	print "Warning: $_[0]\n";
}

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

	if ($str eq '-') {$str = '';}
	return $str;
}


# Load alias info
sub loadLocations {
# 	Copied from scraper.pl

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
			$stateOfCity{$words[1]} = $state;
		} else {
			warning 'Unknown command ' . $cmd . ' at line # ' . $lineNum
					. ' in ' . $locationsFile . ', skipping $line';
		}
	}
}


# Insert/update functions
sub insertSkills {
# Insert skills into skill table.
	my $skillset = $_[0];

	if ($skillset eq '') {return;}

	my @skills = split(',', $skillset);
	my $tmp = 0;
	foreach my $s (@skills) {
		$skills[$tmp] = trim($s);
		$tmp++;
	}

	foreach my $skill (@skills) {
		if ($skill eq '') {next;}
		if ( not exists $personCountOfSkill{$skill} ) {
			print OUTF 'insert ignore into `skill` set `name` = "'
						. $skill . '";' . NEWLINE;
			$personCountOfSkill{$skill} = 1;
		} else { $personCountOfSkill{$skill}++; }
	}
}

sub insertSchool {
# Insert school into school table.
	my $school = $_[0];

	if ($school eq '') {return;}

	if ( not exists $personCountOfSchool{$school} ) {
		print OUTF 'insert ignore into `school` set `name` = "'
					. $school . '";' . NEWLINE;
		$personCountOfSchool{$school} = 1;
	} else { $personCountOfSchool{$school}++; }
}

sub insertCompany {
# Insert company into company table.
	my $company = $_[0];

	if ($company eq '') {return;}

	if ( not exists $personCountOfCompany{$company} ) {
		print OUTF 'insert ignore into `company` set `name` = "'
					. $company . '";' . NEWLINE;
		$personCountOfCompany{$company} = 1;
	} else { $personCountOfCompany{$company}++; }
}

sub insertCountry {
# Insert country into country table.
	my $country = $_[0];
	if ( not exists $personCountOfCountry{$country} ) {
		$personCountOfCountry{$country} = 0;
	}
	if ( $personCountOfCountry{$country} == 0 ) {
		print OUTF 'insert ignore into `country` set `name` = "'
					. $country . '";' . NEWLINE;
	}
	$personCountOfCountry{$country}++;
}

sub insertState {
# Insert state into state table.
	my $state = $_[0];
	my $country = $_[1];

	if ( not exists $personCountOfState{$state} ) {
		$personCountOfState{$state} = 0;
	}
# Working SQL example
# insert into state (name,country_id)
#	values ('California',
#		(select id from country where name = 'United States'))
#	on duplicate key
#		update state.country_id =
#			(select id from country where name = 'United States');

	if ( $personCountOfState{$state} == 0 ) {
		print OUTF 'insert ignore into `state` (name, country_id) '
					. 'values ("' . $state . '", '
					. '(select id from country where name = "' . $country . '")) '
					. 'on duplicate key '
					. 'update state.country_id = '
					. '(select id from country where name = "'
					. $country . '");' . NEWLINE;
	}
	$personCountOfState{$state}++;
}

sub insertCity {
# Insert city into city table.
	my $city = $_[0];
	my $state = $_[1];
	my $country = $_[2];

	my $fullName = $country . '-' . $state . '-' . $city;
	if ( not exists $personCountOfCity{$fullName} ) {
		print OUTF 'insert ignore into `city` (name, state_id) '
					. 'values ("' . $city . '", '
					. '(select s.id from state s join country c '
					. 'where s.name = "' . $state . '" and '
					. 'c.name = "' . $country . '")) '
					. 'on duplicate key '
					. 'update city.state_id = '
					. '(select s.id from state s join country c '
					. 'where s.name = "' . $state . '" and '
					. 'c.name = "' . $country . '");' . NEWLINE;
		$personCountOfCity{$fullName} = 1;
	} else { $personCountOfCity{$fullName}++; }
}

sub findUniqIdentifierAndValue {
# Expect the unique identifier for a candidate to be his/her linkedIn URL.
#	But this may not be true. So if linkedIn URL does not exist, then we
#	look for one identifier among the following:
#	email, phone, twitter_url, facebook_url, github_url, stack overflow
#		url, quora url, angels list url, personal url, resume url.
#	last parameter to this routine is used as personal url if personal url
#		does not exist.

	my $linkedIn   = $_[0];
	my $email      = $_[1];
	my $phone      = $_[2];
	my $twitter    = $_[3];
	my $facebook   = $_[4];
	my $github     = $_[5];
	my $stackof    = $_[6];
	my $quora      = $_[7];
	my $angelslist = $_[8];
	my $personal   = $_[9];
	my $resume     = $_[10];

	my $uniqField;
	my $uniqVal;

	my $upEmail = uc $email;
	if ($linkedIn ne '') {
		$uniqField = 'url_linkedin';
		$uniqVal = $linkedIn;
	} elsif (($email ne '') and ($upEmail ne 'CONFIDENTIAL@MONSTER.COM')) {
		$uniqField = 'email';
		$uniqVal = $email;
	} elsif ($phone ne '') {
		$uniqField = 'phone';
		$uniqVal = $phone;
	} elsif ($quora ne '') {
		$uniqField = 'url_quora';
		$uniqVal = $quora;
	} elsif ($github ne '') {
		$uniqField = 'url_github';
		$uniqVal = $github;
	} elsif ($stackof ne '') {
		$uniqField = 'url_stakeof';
		$uniqVal = $stackof;
	} elsif ($angelslist ne '') {
		$uniqField = 'url_angelslist';
		$uniqVal = $angelslist;
	} elsif ($twitter ne '') {
		$uniqField = 'url_twitter';
		$uniqVal = $twitter;
	} elsif ($facebook ne '') {
		$uniqField = 'url_facebook';
		$uniqVal = $facebook;
	} elsif ($personal ne '') {
		$uniqField = 'url_person';
		$uniqVal = $personal;
	} elsif ($resume ne '') {
		$uniqField = 'url_resume';
		$uniqVal = $resume;
	} else {
		# No unique field
		$uniqField = '';
		$uniqVal = '';
	}

	return ($uniqField, $uniqVal);
}

sub insertPerson {
# Insert a candidate into the person table using the unique identifier
#	and value

	my $identifier = $_[0];
	my $identifierVal = $_[1];

	print OUTF 'insert ignore into `person` (' . $identifier . ') '
					. 'select * from (select "' . $identifierVal . '") as tmp '
					. 'where not exists '
					. '(select ' . $identifier . ' from person '
					. 'where ' . $identifier . ' = "' . $identifierVal . '");' . NEWLINE;

	if ( not exists $personCountOfIdentifier{$identifier} ) {
		$personCount++;
	} else {
		$personCountOfIdentifier{$identifier}++;
		warning $identifier . " being added again";
	}
}

sub updatePerson {
# Candidate is identified with the condition identifier == identifierValue
# Update the identified candidate's field with value in person table.
#
# Future: Store the field and values to be updated, identify conflicts in
#	updates, and avoid duplicate updates.

	my $identifier = $_[0];
	my $identifierVal = $_[1];
	my $field = $_[2];
	my $value = $_[3];

	if ($value eq '') {return;}
	if ($identifier eq $field) {return;}

	print OUTF 'update person set '
				. $field . ' = "' . $value . '" '
				. 'where ' . $identifier . ' = "'
				. $identifierVal . '";' . NEWLINE;
}

sub updateLocation {
# Candidate is identified with the condition identifier == identifierValue
# Update the identified candidate's cityId
#
# CityId is special, as it depends on state and country as well.
# Future: Store the field and values to be updated, identify conflicts in
#	updates, and avoid duplicate updates.

	my $identifier = $_[0];
	my $identifierVal = $_[1];
	my $city = $_[2];
	my $state = $_[3];
	my $country = $_[4];

	if ($city eq '') {return;}
	if ($state eq '') {return;}
	if ($country eq '') {return;}

	my $cityId = '(select c.id from city c join state s '
				. 'on c.state_id = s.id join country c1 '
				. 'on s.country_id = c1.id '
				. 'where c.name = "' . $city . '"'
				. ' and s.name = "' . $state . '"'
				. ' and c1.name = "' . $country . '"' . ')';

	print OUTF 'update person set city_id = '. $cityId 
				. ' where ' . $identifier . ' = "' . $identifierVal . '";'
				. NEWLINE;
}

sub insertOwnSkillSet {
# Insert skills of the candidate into the ownskillset table.
# Candidate is identified with the condition identifier == identifierValue

	my $identifier = $_[0];
	my $identifierVal = $_[1];
	my $skillset = $_[2];

	if ($skillset eq '') {return;}

	my $personId = "(select person.id from person where " . $identifier
					. " = " . '"' . $identifierVal . '")';

	my @skills = split(',', $skillset);
	foreach my $skill (@skills) {
		$skill = trim($skill);
		if ($skill eq '') {next;}
		my $skillId = '(select skill.id from skill where name = ' . '"'
						. $skill . '")';
		print OUTF "insert ignore into \`ownskillset\` "
					. "(person_id, skill_id) "
					. "values( $personId, $skillId );\n";
	}
}

sub insertSchoolAttended {
# Insert schools the candidate attended the schoolattended table.
# Candidate is identified with the condition identifier == identifierValue

	my $identifier = $_[0];
	my $identifierVal = $_[1];
	my $school = $_[2];
	my $degree = $_[3];
	my $major = $_[4];

	if ($school eq '') {return;}

	my $personId = '(select person.id from person where ' . $identifier
					. ' = ' . '"' . $identifierVal . '")';
	my $schoolId = '(select school.id from school where name = ' . '"'
						. $school . '")';

	print OUTF 'insert ignore into `schoolattended` (person_id, school_id) '
				. 'values( ' . $personId . ', ' . $schoolId . ' );'
				. NEWLINE;
	my $updateStmt = 'update schoolattended set ';
	if ($degree ne '') {
		$updateStmt = $updateStmt . 'degree = "' . $degree . '"';
	}
	if ($major ne '') {
		if ($degree ne '') {
			$updateStmt = $updateStmt . ', ';
		}
		$updateStmt = $updateStmt . 'major = "' . $major . '"';
	}
	if ( ($major ne '') || ($degree ne '') ) {
		$updateStmt = $updateStmt . ' where person_id = ' . $personId;
		$updateStmt = $updateStmt . ' and school_id = ' . $schoolId . ';'
						. NEWLINE;
		print OUTF $updateStmt;
	}
}

sub insertCompanyWorkedFor {
# Insert company where the candidate works (only one company so far)
# Candidate is identified with the condition identifier == identifierValue

	my $identifier = $_[0];
	my $identifierVal = $_[1];
	my $company = $_[2];
	my $title = $_[3];

	if ($company eq '') {return;}

	my $personId = '(select person.id from person where ' . $identifier
					. ' = "' . $identifierVal . '")';
	my $companyId = '(select company.id from company where name = "'
						. $company . '")';

	print OUTF 'insert ignore into `companyworkedfor` '
				. '(person_id, company_id) '
				. 'values( ' . $personId . ', ' . $companyId . ' );' . NEWLINE;
	if ($title ne '') {
		print OUTF 'update companyworkedfor set jobTitle = "'
					. $title . '" where person_id = ' . $personId
					. ' and company_id = ' . $companyId . ';' . NEWLINE;
	}
}

my $inFile = 'in.tsv';
my $outFile = '';

my $skipHeader = false; # First line of data file is a header line
my $nameCheck = true; # If false, skip the check for name = NULL;
my $onlyLocation = false; # if true, only output city/state/country related stmts.
my $ARGC = @ARGV;
while ($ARGC > 0) {
	if ($ARGV[0] eq '-outFile') {
		shift; $ARGC--;
		$outFile = $ARGV[0];
	} elsif ($ARGV[0] eq '-skipHeader') {
		$skipHeader = true;
	} elsif ($ARGV[0] eq '-skipNameCheck') {
		$nameCheck = false;
	} elsif ($ARGV[0] eq '-onlyLocation') {
		$onlyLocation = true;
		$nameCheck = false;
	} else {
		$inFile = $ARGV[0];
	}
	shift; $ARGC--;
}

#loadCountries;
#loadStates;
#loadCities;
loadLocations;

# Read the inputs
open(INFILE, $inFile)
	or die "data file $inFile not found";
my @data = <INFILE>;
close INFILE;

if ($outFile eq '') {
	$outFile = (substr $inFile, 0, -3) . 'sql';
}

open(OUTF, '>', $outFile)
	or die "cannot open $outFile for writing output";

print OUTF 'alter table `person` drop index `rv_idx1`;' . NEWLINE;
print OUTF 'alter table `person` drop index `rv_idx2`;' . NEWLINE;
print OUTF 'alter table `person` drop index `rv_idx3`;' . NEWLINE;
print OUTF 'alter table `person` add index `rv_idx1` (`url_linkedin`);' . NEWLINE;
print OUTF 'alter table `person` add index `rv_idx2` (`phone`);' . NEWLINE;
print OUTF 'alter table `person` add index `rv_idx3` (`email`);' . NEWLINE;

my $lineCount = 0;
foreach (@data) {
	my $line = $_;
	$lineCount++;
	# Skip the header line if skipHeader flag is set.
	if ( ($skipHeader) && ($lineCount == 1) ) { next; }
	#print $line;
	chomp $line;
	#my @words = split(',', $line); # Expect a csv file here.
	my @words = split(/	/, $line); # Expect a tsv file here.
	
	my $tmp = 0;
	foreach my $w (@words) {
		#print 'word is <' . $w . . NEWLINE;

		#if (not defined $w) {
			# You cannot come here!
			#print "null word\n";
			#$w = '';
		#} elsif ($w eq '-') {
			#print "hyphen word\n";
			#$w = '';
		#};
		$w = fixStr($w);
		if ( exists $aliases{$w} ) {
			$words[$tmp] = $aliases{$w};
		} else {
			$words[$tmp] = $w;
		}
		#print "$tmp. $words[$tmp]\n";
		$tmp++;
	}

	#Input columns:	ID	Name	Email	Phone	City	State
	#					School1	Degree1	Major1	School2	Degree2	Major2
	#					School3	Degree3	Major3	School4	Degree4	Major4
	#					Title	Company	Skillset	Linkedin
	#					PersonalWebsiteUrl	ResumeUrl	GitHub Profile
	#					Quora Profile	StackOverflow Profile
	#					AngelList Profile	Tweeter	Facebook	Indeed
	#					About.me	URL	URL2	URL3	Email2	Email3
	#					Location	NewCity	NewState	NewCountry

	# First get the fields that can serve as identifier for the candidate
	my $linkedIn = $words[LINKEDIN];
	my $email = $words[EMAIL];
	my $phone = $words[PHONE];
	my $personal = $words[PERSONAL_URL];
	my $resume = $words[RESUME_URL];
	my $github = $words[GITHUB];
	my $quora = $words[QUORA];
	my $stackof = $words[STACK_OVERFLOW];
	my $angelslist = $words[ANGELS_LIST];
	my $twitter = $words[TWITTER];
	my $facebook = $words[FACEBOOK];

	if ( not defined $email ) {$email = '';}
	if ( not defined $phone ) {$phone = '';}
	if ( not defined $linkedIn ) {$linkedIn = '';}
	if ( not defined $quora ) {$quora = '';}
	if ( not defined $github ) {$github = '';}
	if ( not defined $stackof ) {$stackof = '';}
	if ( not defined $angelslist ) {$angelslist = '';}
	if ( not defined $personal ) {$personal = '';}
	if ( not defined $resume ) {$resume = '';}
	if ( not defined $twitter ) {$twitter = '';}
	if ( not defined $facebook ) {$facebook = '';}

	my $email2 = $words[EMAIL2];
	if ( not defined $email2 ) {$email2 = '';}
	if ( $email2 ne '' ) {
		if ($email ne '') {
			$email = $email . ',';
		}
		$email = $email . $email2;
	}

	my $email3 = $words[EMAIL3];
	if ( not defined $email3 ) {$email3 = '';}
	if ( $email3 ne '' ) {
		if ($email ne '') {
			$email = $email . ',';
		}
		$email = $email . $email3;
	}

	my $url = $words[OTHER_URL1];
	if ( not defined $url ) {$url = '';}
	if ( $url ne '' ) {
		if ( $personal ne '' ) {
			warning 'Both personal and another url are specified'
					. ', appending ' . $url . ' to ' . $personal;
			$personal = $personal . ',' . $url;
		} else {
			$personal = $url;
		}
	}

	my $url2 = $words[OTHER_URL2];
	if ( not defined $url2 ) {$url2 = '';}
	if ( $url2 ne '' ) {
		if ( $personal ne '' ) {
			warning 'Both personal and another url are specified'
					. ', appending ' . $url2 . ' to ' . $personal;
			$personal = $personal . ',' . $url2;
		} else {
			$personal = $url2;
		}
	}

	my $url3 = $words[OTHER_URL3];
	if ( not defined $url3 ) {$url3 = '';}
	if ( $url3 ne '' ) {
		if ( $personal ne '' ) {
			warning 'Both personal and another url are specified'
					. ', appending ' . $url3 . ' to ' . $personal;
			$personal = $personal . ',' . $url3;
		} else {
			$personal = $url3;
		}
	}

	my $indeed = $words[INDEED];
	if ( not defined $indeed ) {$indeed = '';}
	if ( $indeed ne '' ) {
		if ($personal eq '') {
			warning 'Treating ' . $indeed . 'as the personal URL';
			$personal = $indeed;
		} else {
			warning 'Both personal and indeed url are specified'
					. ', appending ' . $indeed . ' to ' . $personal;
			$personal = $personal . ',' . $indeed;
		}
	}

	my $aboutMe = $words[ABOUT_ME];
	if ( not defined $aboutMe ) {$aboutMe = '';}
	if ( $aboutMe ne '' ) {
		if ($personal eq '') {
			warning 'Treating ' . $aboutMe . ' as the personal URL';
			$personal = $aboutMe;
		} else {
			warning 'Both personal and about.me url are specified'
					. ', appending ' . $aboutMe . ' to ' . $personal;
			$personal = $personal . ',' . $aboutMe;
		}
	}

	my $prefix = substr $linkedIn, 0, 3;
	if ( $prefix eq 'www' ) {
		# http prefix is missing.
		$linkedIn = 'http://' . $linkedIn;
	}
	my ($identifier, $identifierVal) = findUniqIdentifierAndValue
										$linkedIn, $email, $phone,
										$twitter, $facebook, $github,
										$stackof, $quora, $angelslist,
										$personal, $resume;

	if ($identifier eq '') {
		warning "cannot add $line, no unique identifier";
		next;
	}
	my $name = $words[NAME];
	if ( not defined $name ) {$name = '';}
	if ( ($nameCheck) && ($name eq '') ) {
		warning 'No name specified for line # ' . $lineCount
				. ' in file, ' . $inFile . ' skipping';
		next;
	}

	my $city = $words[CITY];
	my $state = $words[STATE];
	my $newCity = $words[NEW_CITY];
	my $newState = $words[NEW_STATE];
	my $newCountry = $words[NEW_COUNTRY];
	my $country;
	if ( (defined $newCity) && ($newCity ne '') ) { $city = $newCity; }
	if ( (defined $newState) && ($newState ne '') ) { $state = $newState; }
	if ( (defined $newCountry) && ($newCountry ne '') ) { $country = $newCountry; }

	if ( not defined $city )    {$city = '';}
	if ( not defined $state )   {$state = '';}
	if ( not defined $country ) {$country = '';}

	if ( ($city eq '') or ($city eq 'United States') ) {
		#Check for info in location field - like this - "San Francisco, CA"
		# Location like this was available in all_data only (so far)
		my $location = $words[LOCATION];
		if ( (defined $location) and ($location ne '') ) {
			my @loc = split(',', $location);
			my $i = 0;
			foreach my $l (@loc) {
				#Strip all known prefixes, suffixes etc.
				$loc[$i] = fixStr($l);
				if ( exists $aliases{$loc[$i]} ) {
					$loc[$i] = $aliases{$loc[$i]};
				}
				if ($i == 0) { $city = $loc[$i]; } #city
				if ($i == 1) { $state = $loc[$i]; } #state
				$i++;
			}
		}
	}

	#if ( ($state eq '') && (exists $stateOfCity{$city}) ) {
		#$state = $stateOfCity($city);
	#}
	#if ( ($country eq '') && (exists $countryOfState{$state}) ) {
		#$country = $countryOfState($state);
	#}
	# Right now, this is my last ditch attempt to fix state & country.
	# Override any value here.
	# Rememeber cities can have the same name e.g. Newark in CA & NJ, try
	# not to specify them
	# Get around this by specifying city as e.g. Charlotte#North Carolina
	# Wrong spec like Charlotte#United States will point to North Carolinas as the state.
	my $fullName = $city . "#" . $state;
	if ( exists $stateOfCity{$fullName} ) {
		$state = $stateOfCity{$fullName};
	}
	if ( ($state ne '') && ( exists $countryOfState{$state} ) ) {
		$country = $countryOfState{$state};
	}


	my $school1  = $words[SCHOOL1];
	my $degree1  = $words[DEGREE1];
	my $major1   = $words[MAJOR1];
	my $school2  = $words[SCHOOL2];
	my $degree2  = $words[DEGREE2];
	my $major2   = $words[MAJOR2];
	my $school3  = $words[SCHOOL3];
	my $degree3  = $words[DEGREE3];
	my $major3   = $words[MAJOR3];
	my $school4  = $words[SCHOOL4];
	my $degree4  = $words[DEGREE4];
	my $major4   = $words[MAJOR4];
	my $title    = $words[TITLE];
	my $company  = $words[COMPANY];
	my $skillset = $words[SKILLSET];

	# These fields are unused;
	#my $id = $words[ID];

	if ( $country ne '') {
		insertCountry $country;
		if ( $state ne '') {
			insertState $state, $country;
			if ( $city ne '') {
				insertCity $city, $state, $country;
			}
		}
	}

	if ( not defined $school1 ) {$school1 = '';}
	if ( not defined $degree1 ) {$degree1 = '';}
	if ( not defined $major1 ) {$major1 = '';}
	if ( not defined $school2 ) {$school2 = '';}
	if ( not defined $degree2 ) {$degree2 = '';}
	if ( not defined $major2 ) {$major2 = '';}
	if ( not defined $school3 ) {$school3 = '';}
	if ( not defined $degree3 ) {$degree3 = '';}
	if ( not defined $major3 ) {$major3 = '';}
	if ( not defined $school4 ) {$school4 = '';}
	if ( not defined $degree4 ) {$degree4 = '';}
	if ( not defined $major4 ) {$major4 = '';}
	if ( not defined $title ) {$title = '';}
	if ( not defined $company ) {$company = '';}
	if ( not defined $skillset ) {$skillset = '';}

	if ( not $onlyLocation ) {
		insertSkills $skillset;
		insertSchool $school1;
		insertSchool $school2;
		insertSchool $school3;
		insertSchool $school4;
		insertCompany $company;

		insertPerson $identifier, $identifierVal;

		updatePerson $identifier, $identifierVal, 'name',           $name;
		updatePerson $identifier, $identifierVal, 'email',          $email;
		updatePerson $identifier, $identifierVal, 'phone',          $phone;
		updatePerson $identifier, $identifierVal, 'url_person',     $personal;
		updatePerson $identifier, $identifierVal, 'url_resume',     $resume;
		updatePerson $identifier, $identifierVal, 'url_github',     $github;
		updatePerson $identifier, $identifierVal, 'url_quora',      $quora;
		updatePerson $identifier, $identifierVal, 'url_stakeof',    $stackof;
		updatePerson $identifier, $identifierVal, 'url_angelslist', $angelslist;
		updatePerson $identifier, $identifierVal, 'url_twitter',    $twitter;
		updatePerson $identifier, $identifierVal, 'url_facebook',   $facebook;

	}
	updateLocation $identifier, $identifierVal, $city, $state, $country;

	if ( not $onlyLocation ) {
		insertSchoolAttended $identifier, $identifierVal,
							$school1, $degree1, $major1;
		insertSchoolAttended $identifier, $identifierVal,
							$school2, $degree2, $major2;
		insertSchoolAttended $identifier, $identifierVal,
							$school3, $degree3, $major3;
		insertSchoolAttended $identifier, $identifierVal,
							$school4, $degree4, $major4;

		insertCompanyWorkedFor $identifier, $identifierVal, $company, $title;

		insertOwnSkillSet $identifier, $identifierVal, $skillset;
	}

}
close OUTF;

#print Dumper(\%personCountOfCountry);
#print Dumper(\%personCountOfState);
#print Dumper(\%personCountOfCity);
#print Dumper(\%personCountOfIdentifier);
#print Dumper(\%personCountOfSkill);
print "Num Candidates = $personCount\n";

