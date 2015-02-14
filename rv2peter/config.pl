#!/usr/bin/perl

use warnings;
use strict;

sub get_mysql_login		{ return 'vidlink'; }
sub get_mysql_password	{ return 'vidpass'; }
sub get_mysql_db		{ return 'vidlink'; }
sub get_mysql_socket	{ return '/Applications/MAMP/tmp/mysql/mysql.sock'; }
sub get_proxies_file	{ return 'proxies.tsv'; }
sub get_locations_file	{ return 'locations.txt'; }

1;

