#!/usr/local/bin/perl -w
use strict;
require 'lib.pl';

my @globals = qw! $VERSION %FORM %security $auth %const @str %STATE @user_attribs_ro @user_attribs_rw @user_attribs_internal %privileges @privdo !;

my $basedir = '../..';

my $err_msg = '';
Err: {

	local $_ = $ARGV[0] || '';

	if (m!^(query|q)$!) {
		$err_msg = &query_scripts( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(build_map|b)$!) {
		$err_msg = &build_dependency_map( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(extract_comments|e)$!) {
		$err_msg = &extract_function_comments( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(restore_comments|r)$!) {
		$err_msg = &restore_function_comments( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(assert_on|aon)$!) {
		$err_msg = &assert_on( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(assert_off|aoff)$!) {
		$err_msg = &assert_off( $basedir );
		next Err if ($err_msg);
		}
	elsif (m!^(no_require|nq)$!) {
		$err_msg = &build_no_require( $basedir );
		next Err if ($err_msg);
		}

	else {
print <<"EOM";

Usage:
	hacksubs.pl action

	action = query
		lists all subs defined with call count

	action = build_map
		builds inter-dependency map

	action = extract_comments
		pulls out all function comments

	action = restore_comments
		restores all function comments

	action = assert_on
		activate all &Assert warnings

	action = assert_off
		silence all &Assert warnings

	action = no_require || nq
		creates the search_nrq.pl file

This tool rewrites source code (in restore_comments).  Make backups.

EOM
		}
	last Err;
	}
continue {
	print "<P><B>Error:</B> $err_msg.</P>\n";
	}


sub extract_function_comments {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {
		my @files = (
			"$basedir/index.pl",
			);

		my $text = '';
		my $file = ();


		my %func = ();

		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);
			print "Opened file '$file'\n";

			my $newtext = '';
			while ($text =~ m!^(.*?)=item (\w+)(.*?)=cut(.*?)sub (\w+) (.*)$!s) {
				if ($2 eq $5) {
					$newtext .= "$1\n$4sub $5 ";
					$text = $6;
					$func{$2} = "\n=item $2$3=cut\n\n";
					print "extract: $2\n";
					}
				else {
					$newtext .= "$1=item $2$3=cut$4sub $5 ";
					$text = $6;
					}
				}
			$newtext .= $text;
			$err_msg = &WriteFile($file, $newtext);
			next Err if ($err_msg);
			}

		unless (keys %func) {
			print "Warning: found no function specs - have you already run extract?\n";
			last Err;
			}

		my $date_str = scalar localtime();
		my $spec = <<"EOM";

Extracted function comments
$date_str


EOM

		foreach (sort keys %func) {
			my $func_data = $func{$_};
			$func_data =~ s!Dependencies:.*?=cut!=cut!sg;
			$spec .= $func_data;
			}
		$err_msg = &WriteFile('function_spec.txt', $spec);
		next Err if ($err_msg);

		last Err;
		}
	return $err_msg;
	}



sub assert_on {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {
		my @files = (
			"$basedir/index.pl",
			);
		my $text = '';
		my $file = ();
		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);
			my $count = 0 + scalar ($text =~ s!\#+\s*\&Assert!&Assert!sg) + scalar ($text =~ s!\#+\s*\&main::Assert!&main::Assert!sg);
			print "Replaced $count calls in file '$file'\n";
			$err_msg = &WriteFile( $file, $text );
			next Err if ($err_msg);
			}
		last Err;
		}
	return $err_msg;
	}
sub assert_off {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {
		my @files = (
			"$basedir/index.pl",
			);
		my $text = '';
		my $file = ();
		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);
			my $count = 0 + scalar ($text =~ s!\&Assert!#&Assert!sg) + scalar ($text =~ s!\&main::Assert!#&main::Assert!sg);
			print "Replaced $count calls in file '$file'\n";
			$err_msg = &WriteFile( $file, $text );
			next Err if ($err_msg);
			}
		last Err;
		}
	return $err_msg;
	}


sub restore_function_comments {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {
		my @files = (
			"$basedir/index.pl",
			);
		my $text = '';
		my $file = ();

		unless (-e 'dependency_map.txt') {
			print "Error: file 'dependency_map.txt' doesn't exist. Run 'hacksubs.pl build_map' first.\n";
			last Err;
			}

		($err_msg, $text) = &ReadFile('dependency_map.txt');
		next Err if ($err_msg);

		my %depends = ();
		foreach (split(m!Function: !s, $text)) {
			next unless (m!^(\S+)\s+(.*?)$!s);
			$depends{$1} = &Trim($2);
			}

		($err_msg, $text) = &ReadFile('function_spec.txt');
		next Err if ($err_msg);

		my %func = ();
		foreach (split(m!=item!s, $text)) {
			next unless (m!^ (\w+)(.*?)=cut!s);
			$func{$1} = &Trim($2);
			print "Loaded function comments for '$1'\n";
			}

		foreach (keys %func) {
			# strip "dependencies" and add the values from 'dependency_map.txt'
			if ($depends{$_}) {
				$func{$_} =~ s!Dependencies:.*?$!!so;
				$func{$_} = &Trim($func{$_});
				$func{$_} .= "\n\nDependencies:\n\n\t$depends{$_}";
				}
			}


		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);
			print "Opened file '$file'\n";

			my $key = ();
			foreach $key (reverse sort keys %func) {
				my $qmkey = quotemeta($key);
				$text =~ s!=item $qmkey\W.*?=cut.*?sub $qmkey !=item $qmkey\n\n$func{$key}\n\n=cut\n\nsub $qmkey !sg;
				$text =~ s!\}\s*sub $qmkey !\}\n\n\n=item $qmkey\n\n$func{$key}\n\n=cut\n\nsub $qmkey !sg;

				# correct for first function

				$text =~ s!=head1([^\=]+)=cut\s*sub $qmkey !=head1$1=cut\n\n\n=item $qmkey\n\n$func{$key}\n\n=cut\n\nsub $qmkey !sg;

				}
			$err_msg = &WriteFile($file,$text);
			next Err if ($err_msg);
			}
		last Err;
		}
	return $err_msg;
	}


=item build_dependency_map($)

Requires that all subs be defined at the end of the file - no mixing of subs and code.  All code goes at the top.

=cut

sub build_dependency_map {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {

		my @files = (
			"$basedir/index.pl",
			);

		my %subs = (
			'connect'          => 1,
			'disconnect'       => 1,
			'errstr'           => 1,
			'execute'          => 1,
			'fetchrow_array'   => 1,
			'fetchrow_hashref' => 1,
			'finish'           => 1,
			'prepare'          => 1,
			'quote'            => 1,
			'rows'             => 1,
			'can_read'  => 1,
			'can_write' => 1,
			'new'       => 1,
			'PF_INET'   => 1,
			'AF_INET'   => 1,
			'SOCK_STREAM' => 1,
			);
		my %subdepend = ();

		my %globals_used_by_subs = ();

		my %people_who_use_me = ();

		my %homefiles = (
			'connect'          => 'DBI.pm',
			'disconnect'       => 'DBI.pm',
			'errstr'           => 'DBI.pm',
			'execute'          => 'DBI.pm',
			'fetchrow_array'   => 'DBI.pm',
			'fetchrow_hashref' => 'DBI.pm',
			'finish'           => 'DBI.pm',
			'prepare'          => 'DBI.pm',
			'quote'            => 'DBI.pm',
			'rows'             => 'DBI.pm',
			'can_read'  => 'IO::Select',
			'can_write' => 'IO::Select',
			'new'       => 'IO::Select',
			'PF_INET'   => 'Socket',
			'AF_INET'   => 'Socket',
			'SOCK_STREAM' => 'Socket',
			);
			# key - sub ; value - file


		my %globes = ();
		foreach (@globals) {
			my $xstr = $_;
			$xstr =~ s!\W!!g;
			$globes{$xstr} = $_;
			}


		my $map = '';

		my $glob = '';
		my $text = '';
		my $file = ();
		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);

			print "Opened file '$file'\n";

			$text = " sub main " . $text;

			my $new = '';
			foreach (split(m!\r|\n!s, $text)) {
				next if (m!^\s*\#!);

				# strip stuff that's inside a sub regex:
				s!s\!.*?\!.*?\!\w*\;!!g;
				s!s\'.*?\'.*?\'\w*\;!!g;

				$new .=  " $_ ";
				}
			$text = $new;

			$text =~ s!(\r|\n)! !gs;

			$text =~ s!=item.*?=cut! !gs;
			$text =~ s!package .*?sub! sub!gs; # strip package declarations

			$glob .= $text;




			my @x = split(m! sub !is, $text);
			$x[0] = '';
			foreach (@x) {
				next unless (m!^\s*(\w+)\s+(.*)!);
				my ($name,$code) = ($1,$2);
				if ($subs{$name}) {
					print "Warning: duplicate sub declared: '$name' - rename\n" unless ($name eq 'main');
					}
				$subs{$name}++;
				$homefiles{$name} = $file;

				my %depend = ();

				my $savecode = $code;

				while ($code =~ m!\&(\w+)(\W)(.*)$!) {
					my ($substring, $nextch, $end) = ($1, $2, $3);
					$code = $end;

					next if ($substring =~ m!^(gt|lt|nbsp)$!i); # just html, kids, nothing to be afraid of - just rmemeber not to use these for any of your sub names
					next if ($nextch eq '='); # there are HTML link creations - foo.cgi?bob=1&jane=2 -> thinks &jane is a function call


					next if (($nextch eq ':') and ($end !~ m!^\:!)); # used in HTML namespace

					if (($nextch eq ':') and ($end =~ m!^\:(\w+)!)) {
						$substring = $1;
						}

					$depend{$substring}++;

					$people_who_use_me{$substring} .= " $name ";
					}

				$code = $savecode;
				while ($code =~ m!\-\>(\w+)(\W)(.*)$!) {
					my ($substring, $nextch, $end) = ($1, $2, $3);
					$code = $end;
					$depend{$substring}++;
					$people_who_use_me{$substring} .= " $name ";
					}
				$subdepend{$name} = \%depend;


				$code = $savecode;
				my %global_usage_count = ();
				foreach (keys %globes) {
					next unless ($code =~ m!$_!s);
					$global_usage_count{$_} = scalar ($code =~ s!$_!$_!sg);
					}
				$globals_used_by_subs{$name} = \%global_usage_count;


				}


			}

		foreach (sort keys %subs) {
			my $p_depend = $subdepend{$_};
			my $home = $homefiles{$_};
			my $p_global = $globals_used_by_subs{$_};

			print "Function: $_\n\n";
			$map .= "Function: $_\n\n";

			my @clients = split(m!\s+!, $people_who_use_me{$_} || '' );
			my %uniq = ();
			foreach (sort @clients) {
				next unless $_;
				next if ($uniq{$_});
				$uniq{$_} = 1;
				$map .= "	Called by: $_\n";
				}
			$map .= "\n";

			my $g_count = 0;
			foreach (keys %$p_global) {
				$g_count++;
				$map .= "	Global: $globes{$_} - $$p_global{$_}\n";
				}
			if ($g_count == 0) {
				$map .= "	Global: none\n";
				}
			$map .= "\n";

			my %required_libs = ();
			my $d_count = 0;
			foreach (sort keys %$p_depend) {
				my $libfile = $homefiles{$_};
				unless ($libfile) {
					print "Error: homefiles{$_} not defined - $$p_depend{$_}  \n";
					exit;
					next;
					}
				$required_libs{$libfile} = 0 unless (defined($required_libs{$libfile}));
				$required_libs{$libfile}++;
				$d_count++;
				$map .= "	Dependency: $_ - $$p_depend{$_}\n";
				unless ($subs{$_}) {
					print "	Warning: sub '$_' referenced but not defined in this group\n";
					exit;
					}
				}
			if ($d_count == 0) {
				$map .= "	Dependency: none\n";
				}
			$map .= "\n";

			foreach (sort keys %required_libs) {
				$map .= "	Required library: $_\n";

				if (($_ =~ m!common_admin!) and ($home =~ m!(common.pl|common_parse_page.pl)!)) {
					print "This won't do... improper load sequence... fix it\n";
					exit;
					}
				if (($_ =~ m!common_parse_page!) and ($home =~ m!common.pl!)) {
					print "This won't do... improper load sequence... fix it\n";
					exit;
					}

				}
						$map .= "\n\n";

						$map .= "\n";
			}

		print $map;

		$err_msg = &WriteFile('dependency_map.txt', $map);
		last Err;
		}
	return $err_msg;
	}







sub query_scripts {
	my ($basedir) = @_;
	my $err_msg = '';
	Err: {

		my ($subcount, $subcalls) = (0, 0);

		my @files = (
			"$basedir/index.pl",
			);
		my %subs = ();

		my $glob = '';

		my $text = '';

		my $file = ();
		foreach $file (@files) {
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);

			print "Opened file '$file'\n";

			my $new = '';
			foreach (split(m!\r|\n!s, $text)) {
				next if (m!^\s*\#!);
				$new .=  " $_ ";
				}
			$text = $new;

			$text =~ s!(\r|\n)! !gs;

			$text =~ s!=item.*?=cut! !gs;

			$glob .= $text;


			my @x = split(m! sub !is, $text);
			$x[0] = '';
			foreach (@x) {
				next unless (m!^\s*(\w+)\s+!);
				my $name = $1;
				if (($subs{$name}) and ($name ne 'main')) {
					print "Warning: duplicate sub declared: '$name' - rename\n";
					}
				$subs{$name}++;
				$subcount++;
				}
			}

		if ($glob =~ m!(.{100})foreach \$?\w*\s*\(\%(.{100})!s) {
			print "Possible foreach over hash instead of keys %hash:\n";
			print "$1$2\n";
			exit;
			}
		if ($glob =~ m!(.{100})(push|pop|scalar|sort|reverse)\s*\(?\%(.{100})!s) {
			print "Possible array operation on hash instead of keys %hash:\n";
			print "$1$2$3\n";
			exit;
			}

		foreach (sort keys %subs) {
			my @words = ();
			my $count = scalar (@words = ($glob =~ m!\W$_\W!og));
			my $excount = scalar (@words = ($glob =~ m!\&$_\W!og));
			my $pkcount = scalar (@words = ($glob =~ m!\:\:$_\W!og));
			my $obcount = scalar (@words = ($glob =~ m!\-\>$_\W!og));

			$subcalls += $excount + $pkcount + $obcount;

			if ($count != ($excount + $pkcount + $obcount + 1)) {
				print "Warning: check for non-explicit calls to sub \&$_() - $count vs $excount + $pkcount + $obcount\n";
				}

			print "sub: $_ - $count\n";

			if ($count == 1) {
				print "WARNING:\n";
				exit;
				}
			}

		print '-' x 78 . "\n";
		print "Total $subcount functions defined - total $subcalls calls to them.\n";
		print '-' x 78 . "\n";

		last Err;
		}
	return $err_msg;
	}
