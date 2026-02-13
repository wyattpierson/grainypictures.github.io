#!/usr/bin/perl -w
use strict;
require 'lib.pl';

my $basedir = '../..';

my $description = <<"EOM";

manages the \@str array and associated strings.txt files

Usage:

lang.pl show
lang.pl switch num1 num2
lang.pl audit

[show]
Scans all codes files in 'dir' and displays how many times each
str[] is used.  Will print warnings for strings that aren't
used, or strings that are referenced as a range.

[switch]
Replaces the positions of str[] "num1" and "num2" in all
the code files and in the English strings.txt file.  This is
used to move holes in strings.txt to the end where they can
be safely stripped, and to move public strings to the top of
the file so that the public process can abort reading of
strings.txt early on.

Warning: bands 21-40 and 121-200 are reserved for Common.pm
modules which are shared across multiple scripts.  Do not switch
strings into or out of those bands.

[audit]
Checks non-English language strings to confirm that \$s1/\$s2
sequences are preserved.

EOM

my $action = $ARGV[0] || '';

if ($action eq 'switch') {
	&remap( $ARGV[1], $ARGV[2] );
	}
elsif ($action eq 'show') {
	&show_lang_usage();
	}
elsif ($action eq 'audit') {
	&audit();
	}
else {
	print $description;
	}

sub str_used {
	my ($p_str_used, $p_glob, @files) = @_;
	my $err_msg = '';
	Err: {
		my ($glob, $text) = ('', '');
		foreach (@files) {
			($err_msg, $text) = &ReadFile( $_ );
			next Err if ($err_msg);
			$glob .= $text;
			}
		$$p_glob .= $glob;
		$glob =~ s!=item.*?=cut!!sg;
		while ($glob =~ m!^.*?(str\[|pstr\()\s*(\d+)(.*)$!s) {
			$$p_str_used[$2]++;
			$glob = $3;
			}
		}
	return $err_msg;
	}


sub audit {
	my $err_msg = '';
	Err: {
		my $engfile = "$basedir/script_data/templates/english/strings.txt";
		my $text = '';
		($err_msg, $text) = &ReadFile($engfile);
		my @expect = ();
		my @words = ();
		my $i = 0;
		foreach (split(m!\n!,$text)) {
			$i++;

			$expect[$i] = 0;
			my $n = 0;
			for $n (1..100) {
				last unless ($_ =~ m!\$s$n!);
				$expect[$i] = $n;
				}

			print "Line $i - $expect[$i]\n";
			}

		unless (opendir(DIR,"$basedir/script_data/templates")) {
			$err_msg = "unable to open dir - $!";
			next Err;
			}

		my $lang = ();
		foreach $lang (readdir(DIR)) {
			my $file = "$basedir/script_data/templates/$lang/strings.txt";
			next unless (-e $file);
			print "Auditing $lang translation...\n";
			($err_msg, $text) = &ReadFile($file);
			next Err if ($err_msg);
			my $i = 0;
			my $value = ();
			foreach (split(m!\n!,$text)) {
				$i++;

				my $ev = $expect[$i];

				# make sure that all ev are present & accounted for:

				my $n = 0;
				for $n (1..$ev) {
					unless ($_ =~ m!\$s$n!) {
						print "Error: lang:$lang; line $i; missing \$s$n\n";
						}
					}

				# make sure that upper-range ev aren't present:

				for $n (($ev+1)..($ev+10)) {
					if ($_ =~ m!\$s$n!) {
						print "Error: lang:$lang; line $i; reference to \$s$n is not found in English version\n";
						}
					}
				}
			print "Checked $i lines\n";
			}
		closedir(DIR);
		last Err;
		}
	continue {
		print "Error: $err_msg.\n";
		}
	}


sub show_lang_usage {
	my $err_msg = '';
	Err: {

		my $glob = '';

		my (@pub, @semipub, @admin) = ();

		$err_msg = &str_used( \@pub, \$glob,
			"$basedir/index.pl",
			"$basedir/script_data/libs/manage_users.pm",
			"$basedir/script_data/libs/html_editor.pm",
			"$basedir/script_data/libs/template_editor.pm",
			"$basedir/script_data/libs/my_account.pm",
			"$basedir/script_data/libs/system_settings.pm",
			"$basedir/script_data/libs/user_defined.pm",
			"$basedir/script_data/libs/network.pm",
			);
		next Err if ($err_msg);

		my %holes = ();
		my $maxpub = 1;
		my $maxsemipub = 1;

		my $max = $#pub;
		$max = $#semipub if ($#semipub > $max);
		$max = $#admin if ($#admin > $max);

		my $engtext = '';
		($err_msg, $engtext) = &ReadFile("$basedir/script_data/templates/english/strings.txt");
		next Err if ($err_msg);
		my @eng = (0,split(m!\n!s, $engtext));

		if ($max > ($#eng + 1)) {
			print "Warning: references are made to str which do not exist!\n";
			}

		my %engstr = ();
		for (1..$#eng) {
			my $lcstr = lc($eng[$_]);
			if ($engstr{$lcstr}) {
				print "Hey - english string $_ similar to $engstr{$lcstr} - poss. dupe:\n";
				print substr($eng[$_],0,60) . "\n";
				print substr($eng[$engstr{$lcstr}],0,60) . "\n";
				print "\n";
				}
			$engstr{$lcstr} = $_;
			}

		my $openp = 0;
		my $opens = 0;

		my $i = 1;
		while ($i < ($max + 2)) {
			my ($p, $s, $a) = ($pub[$i] || 0, $semipub[$i] || 0, $admin[$i] || 0);
			my $word = substr(($eng[$i] || ''), 0, 30);
			print "$i	$p	$s	$a	$word\n";
			$maxpub = $i if ($p);
			$maxsemipub = $i if ($s);
			$holes{$i} = 1 unless ($p or $s or $a);
			$openp = $i if (($p == 0) and ($openp == 0));
			$opens = $i if (($s == 0) and ($opens == 0) and ($openp));
			$i++;
			}

		print '-' x 78 . "\n";
		foreach (sort keys %holes) {
			print "Not used: $_	" . substr(($eng[$_] || ''),0,30) . "\n";
			}
		print '-' x 78 . "\n";

		print "Max pub: $maxpub\n";
		print "Max semipub: $maxsemipub\n";

		print '-' x 78 . "\n";
		print "Searching for range descriptors:\n";
		while ($glob =~ m!^.*?str\[(.*?)\](.*)$!s) {
			my ($x, $y) = ($1, $2);
			print "Range (do not switch): $x\n" if ($x !~ m!^\d+$!);
			$glob = $y;
			}

		print '-' x 78 . "\n";

		if ($openp < $maxpub) {
			print "Recommend switch $openp with $maxpub to condense public strings.\n";
			}
		else {
			print "Congrats: public strings are properly condensed to first $maxpub strings.\n";
			if ($opens < $maxsemipub) {
				print "Recommend switch $opens with $maxsemipub to condense semi-public strings.\n";
				}
			else {
				print "Congrats: semi-public strings are properly condensed to first $maxsemipub strings.\n";
				}
			}

		print '-' x 78 . "\n";


=item cut

		my $text = '';
		($err_msg, $text) = &ReadFile("$basedir/index.pl");
		next Err if ($err_msg);

		if ($text =~ m!(\d+)\)\;\#strdepth!s) {
			my $curr = $1;
			print "Currently reading to $curr for non-admin requests.\n";
			if ($curr != ($maxsemipub + 1)) {
				$curr = $maxsemipub + 1;
				$text =~ s!(\d+)\)\;\#strdepth!$curr\)\;\#strdepth!os;
				$err_msg = &WriteFile("$basedir/index.pl", $text);
				next Err if ($err_msg);
				print "Success: updated index.pl\n";
				}
			else {
				print "Read depth correct.\n";
				}
			}

=cut


		last Err;
		}
	continue {
		print "Error: $err_msg.\n";
		}
	}


sub remap {
	my $err_msg = '';
	Err: {

		my ($a, $b) = @_;
		if ($a == $b) {
			$err_msg = "$a == $b";
			next Err;
			}

		# switch order in strings.txt
		my $file = "$basedir/script_data/templates/english/strings.txt";
		open(FILE, "<$file") || die $!;
		my @current = <FILE>;
		close(FILE);

		# remember, there's a #1 offset:
		my $temp = $current[$a-1];
		$current[$a-1] = $current[$b-1];
		$current[$b-1] = $temp;

		my $newtext = '';
		foreach (@current) {
			$newtext .= $_;
			}
		$err_msg = &WriteFile($file, $newtext);
		next Err if ($err_msg);

		my @files = (
			"$basedir/index.pl",
			"$basedir/script_data/libs/manage_users.pm",
			"$basedir/script_data/libs/html_editor.pm",
			"$basedir/script_data/libs/template_editor.pm",
			"$basedir/script_data/libs/my_account.pm",
			"$basedir/script_data/libs/system_settings.pm",
			"$basedir/script_data/libs/user_defined.pm",
			"$basedir/script_data/libs/network.pm",
			);

		foreach $file (@files) {
			my $text = '';
			($err_msg, $text) = &ReadFile( $file );
			next Err if ($err_msg);

			my $counta2b = scalar ($text =~ s!str\[$a\]!str[4000$b]!sg);
			  $counta2b += scalar ($text =~ s!pstr\(\s*$a\s*,!pstr\(4000$b,!sg);

			my $countb2a = scalar ($text =~ s!str\[$b\]!str[4000$a]!sg);
			  $countb2a += scalar ($text =~ s!pstr\(\s*$b\s*,!pstr\(4000$a,!sg);
			$text =~ s!str\[4000$a\]!str[$a]!sg;
			$text =~ s!str\[4000$b\]!str[$b]!sg;

			$text =~ s!pstr\(4000$a,!pstr\($a,!sg;
			$text =~ s!pstr\(4000$b,!pstr\($b,!sg;

			print "Replaced $counta2b a2b and $countb2a b2a in $file\n";

			$err_msg = &WriteFile( $file, $text );
			}

		last Err;
		}
	continue {
		print "Error: $err_msg\n";
		}
	return $err_msg;
	}
