Purpose: Convert excel files with candidate data to SQL files. These SQL
files can be run to add the candidate data to vidlink database.

            Steps to add an excel file to vidlink
1. Make sure that all sheets of the excel file have the same fields. If
other sheets have junk values, delete those sheets.

2. If the excel spreadsheet has two columns for first name and last name,
but none for a combined name, create a column 'name' with this formula
name_col = <firstname_col> & ' ' & <lastname_col>
e.g. C1 = A1 & ' ' & B
Make sure that this is copied for all rows of the sheet

3. Create a schema file. If the excel spreadsheet is called data.xlsx, the
schema file should be called data.schema
This is a csv file, and it should describe what is in the list.
An example schema file below:
	Name,C
	Email,D
	City,G
	State,H
	Phone,I
	LinkedIn,J
All valid field names are given as an appendix at the bottom

4. Run excel.pl like this
	perl excel.pl data.xlsx
This will produce a file called data.inp

5. Determine whether you need to run scraper, or the city/state/location
info is trustworthy.

6. If scraper.pl has to be run,
	perl scraper.pl data.inp
This will produce a file called data.tsv
Caveat: proxy list can get outdated easily, you have to periodically
refresh this.

7. data.tsv and data.inp file will have a header line like this -
	ID	Name	Email	Phone	City...

8. Dump the SQL for this data like this:
	perl dumpsql.pl -skipHeader data.tsv
This will produce a file called data.sql
The skipHeader option skips the header line and processes the rest

9. All updates to vidlink are gated through Don Tran. Ask Don to run
data.sql whenever he can.

10. You are done!



FILES:

	Perl Scripts:
	excel.pl:	Reads an excel file, a mandatory "schema" file and produces
				an inp file. This inp file is tab separated list of
				candidate attributes (name, email, linkedin_url etc.)
	scraper.pl:	Optional step. Sometimes the excel file does not have
				location info, but provides a LinkedIn URL. In those cases,
				we scrape the location info from the given LinkedIn URL. We
				may also scrape the info if we don't have confidence in the
				location info in the spreadsheet.
				CAVEAT: proxies.tsv file gets outdated every few days. It
					may need to be refreshed with new proxies. Just copy a
					few http/https proxies from sites like hidemyass.com
	dumpsql.pl:	Reads the output of excel.pl (inp file) or scraper.pl (tsv 
				file) and produce an SQL file. This SQL file will have 
				insert/update stmts to insert/update candidate info in
				vidlink.

	Auxilliary Files:
	locations.txt, vidlink_city.tsv, vidlink_state.tsv: Auxilliary files
				used by various scripts
	proxies.tsv: Auxillary file used by scraper. Repeating the caveat
				below. CAVEAT: proxies.tsv file gets outdated every few
				days. It may need to be refreshed with new proxies. Just
				copy a few http/https proxies from sites like hidemyass.com

	Data Files:
	example.xlsx:	An example excel spreadsheet
	backup.schema:	You should look at the spreadsheet and try to create a
					schema file. This schema file you create should be the
					same as backup.schema


						APPENDIX
			Valid Schema Entries and Their Meanings
ID			- Usually available in only vidlink dumps
Name		- Candidate's full name, expected like <FirstName LastName>
Email		- Multiple emails can be specified here, separated by a comma
Email2		- This will be added to email
Email3		- This will be added to email
Phone		- Multiple phones can be specified here, separated by a comma
Title		- Job title
Skillset 	- Multiple skills allowed, separated by a comma or double spacing
PersonalUrl	- Multiple URLS allowed, separated by a comma
Indeed		- This will be added to PersonalURL
About.me	- This will be added to PersonalURL
URL			- This will be added to PersonalURL
URL2		- This will be added to PersonalURL
URL3		- This will be added to PersonalURL
Location	- expected in the format of 'city, state'. Some excel files
				don't break this info into two separate fields

The names below have their obvious meanings
City
State
School1
Degree1
Major1
School2
Degree2
Major2
School3
Degree3
Major3
School4
Degree4
Major4
Company
Linkedin
ResumeUrl
GitHub
Quora
StackOverflow
AngelList
Twitter
Facebook

		How to install Perl and required modules
1. If you don't have perl already installed, follow the steps at this URL:
	http://learn.perl.org/installing/

2. The following modules are required for these scripts
	Data::Dumper
	Spreadsheet::Read
	DBD::mysql
	HTTP::Request
	LWP::Simple;
To install these modules, please follow the following steps.
	a. First read this URL (http://www.cpan.org/modules/INSTALL.html) and
		make sure you understand the requirements
	b. The recommended way to install modules is to install cpan (Read the
		Quick Start section) and then install each of the modules by typing
		the commands:
			cpanm Data::Dumper
			cpanm Spreadsheet::Read
			cpanm DBD::mysql
			cpanm HTTP::Request
			cpanm LWP::Simple;
	c. If that doesn't work, follow up the steps in this URL to resolve issues.


							FAQ
1. Why do we need a schema file?

	Excel files come from third parties. They do not follow a consistent naming
mechanism for the columns. LinkedIn may be called "Linke Din" as in
example.xlsx. It may even be called "foobar". It may not have a name. But
somehow we need to tell the script this column - column J - has the linkedIn
info.

	We cannot use the column headers in the spreadsheet for this, they do not
matter at all.  If I can use them, I wouldn't need a schema file, I would just
read the column names from the Spreadsheet. But there is no way to figure out
"LinkedIn", "Linked In", "LnkdIn", "nlkdlin" all mean LinkedIn. There are
hundreds of ways to type LinkedIn.

	But we can look at the spreadsheet and clearly identify that "Linke Din"
means "LinkedIn". The schema file is a mechanism to convey that identification
to perl scripts. In example.xlsx:
	The only columns that we will store in the vidlink are Name, Email, City,
State, Phone, and LinkedIn.
	We will read Email2 & Email3, but we will append them to Email and store
the Email in vidlink.

	So excel.pl is interested only in Name, Email1, Email 2, Email 3, City,
State, Phone and Linke Din columns. After running all the scripts, these
columns will be converted into Name,Email,City,State,Phone,LinkedIn.

	So the schema file needs to convey the column numbers where the Spreadsheet
has info for Name,Email,Email2,Email3,City,State,Phone and LinkedIn.

	In a nutshell, the column headers in the Spreadsheet are meaningless. You
are essentially using the schema file to tell excel.pl what the column headers
should be.

