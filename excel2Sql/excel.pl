#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Spreadsheet::Read;

use constant { true => 1, false =>0 };

my $delim = '	'; # Using tab char as the delimiter
my $inFile = "./in.xlsx";
my $outFile = "";
my $trimURL = true; # trim URLs after the first occurence of "&" char

my $ARGC = @ARGV;
while ($ARGC > 0) {
	if ($ARGV[0] eq '-outFile') {
		shift; $ARGC--;
		$outFile = $ARGV[0];
	} elsif ($ARGV[0] eq '-noTrimURL') {
		$trimURL = false;
	} else {
		$inFile = $ARGV[0];
	}
	shift; $ARGC--;
}

if ($outFile eq "") {
	$outFile = (substr $inFile, 0, -5) . ".inp";
}
my $schemaFile = (substr $inFile, 0, -5) . ".schema";
my %schema = ();
my %defaults = ();


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

open(OUTF, ">", $outFile)
		or die "cannot open file $outFile for output";
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

my @outputFields = (
					"ID",
					"Name",
					"Email",
					"Phone",
					"City",
					"State",
					"School1",
					"Degree1",
					"Major1",
					"School2",
					"Degree2",
					"Major2",
					"School3",
					"Degree3",
					"Major3",
					"School4",
					"Degree4",
					"Major4",
					"Title",
					"Company",
					"Skillset",
					"LinkedIn",
					"PersonalURL",
					"ResumeURL",
					"GitHub",
					"Quora",
					"StackOf",
					"AngelsList",
					"Twitter",
					"Facebook",
					"Indeed",
					"About.me",
					"URL",
					"URL2",
					"URL3",
					"Email2",
					"Email3",
					"Location",
					"NewCity",
					"NewState",
					"NewCountry",
					"Phone2" # This is not output
					);

my $tmp = 0;
my $numOutputFields = @outputFields;
foreach my $f (@outputFields) {
	$schema{$f} = "";
	print OUTF $f;
	$tmp++;
	if ($tmp < $numOutputFields) {print OUTF $delim;}
	else {print OUTF "\n";}
}

# Read the schema
open(INFILE, $schemaFile)
		or die "schema file $schemaFile not found";
my @data = <INFILE>;
close INFILE;

foreach (@data) {
	# Schema file has a simple format
	# The colname we require,col in which this is present
	# e.g. Name,A; LinkedIn,F; and so on.
	my $line = $_;
	chomp $line;
	$line =~ s|\||gi;
	my @words = split(',', $line);
	my $numWords = @words;
	if ($numWords > 1) {
		$schema{$words[0]} = $words[1];
	}
	if ($numWords > 2) {
		$defaults{$words[0]} = $words[2];
	}
}



my $xlsx = ReadData($inFile);
if (not defined $xlsx) {
	print "Error in reading $inFile\n";
	exit;
}
#print Dumper(\$xlsx);
my $numSheets = ${@$xlsx[0]}{sheets};
#print "numSheets is $numSheets\n";

for (my $sheetNum=1; $sheetNum <= $numSheets; $sheetNum++) {
	my %sheet = %{@$xlsx[$sheetNum]};
	my $maxRow = $sheet{'maxrow'};
	#print "sheetNum is $sheetNum\n";
	#print "maxrow is $maxRow\n";
	for (my $rowNum=2; $rowNum <= $maxRow; $rowNum++) {
		foreach my $f (@outputFields) {
			if ($schema{$f} ne '') {
				# This field is present in the input file
				my $col = $schema{$f};
				my $cell = $col . $rowNum;
				#print "cell is $cell\n";
				if (exists $sheet{$cell}) {
					my $val = $sheet{$cell};
					#print "value is $val\n";
					#$val =~ s|\||gi;
					$val =~ s|\n|,|gi;
					$val =~ s|\r|,|gi;
					$val =~ tr/\cM//d; # Remove ^M chars
					if ($f eq "Skillset") {
						$val =~ s|  |,|g;
					} elsif ($f eq "LinkedIn") {
						if ( ($val !~ 'linkedin') && ($val !~ 'lnkd.in') ) {
							# This is not a linkedin URL
							print OUTF $delim;
							next;
						}
						if ($trimURL) {
							my $andCharLoc = index($val, '&');
							if ($andCharLoc != -1) {
								my $tmpstr = substr $val, 0, $andCharLoc;
								$val = $tmpstr;
							}
						}
						my $prefix = substr $val, 0, 3;
						if ( $prefix eq 'www' ) {
							# http prefix is missing.
							$val = "http:\/\/" . $val;
						}
					} elsif ($f eq "Twitter") {
						if ($val !~ 'twitter') {
							# This is not a Twitter URL
							print OUTF $delim;
							next;
						}
					} elsif ($f eq "PersonalURL") {
						if ($val =~ 'twitter') {
							# This is a Twitter URL
							print OUTF $delim;
							next;
						}
						if ( ($val =~ 'linkedin') || ($val =~ 'lnkd.in') ) {
							# This is a LinkedIn URL
							print OUTF $delim;
							next;
						}
					} elsif ($f eq "Phone") {
						# If there is a phone2, just attach it here
						if ($schema{"Phone2"} ne '') {
							my $phone2Col = $schema{"Phone2"};
							my $phone2Cell = $phone2Col . $rowNum;
							my $phone2 = $sheet{$phone2Cell};
							if ( (defined $phone2) && ($phone2 ne '') ) {
								$phone2 =~ s|\n|,|gi;
								$phone2 =~ s|\r|,|gi;
								$phone2 =~ tr/\cM//d; # Remove ^M chars
								if ($val ne '' ) {
									$val = $val . ', ' . $phone2;
								} else {
									$val = $phone2;
								}
							}
						}
					}
					$val = fixStr($val);
					if ( ($val eq "") && (exists $defaults{$f}) ) {
						$val = $defaults{$f};
					}
					print OUTF $val;
				}
			}
			print OUTF $delim;
		}
		print OUTF "\n";
	}
}
close OUTF;


