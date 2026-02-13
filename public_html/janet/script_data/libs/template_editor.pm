use strict;

sub ui_ListTemplates {
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_template_editor');
		next Err if ($err);


print <<"EOM";

		<p><b>$str[52]</b></p>

		<p>$str[263]</p>

EOM



		my $p_start = sub {
			print '<ul>';
			return '';
			};

		my $p_stop = sub {
			print '</ul>';
			return '';
			};

		my $p_entry = sub {
			my ($path, $basename, $depth) = @_;
			my $err = '';
			Err: {

				$path = $path . '/' . $basename;

				my $true = '';
				my $qmbase = quotemeta($const{'preferences folder'});
				if ($path =~ m!^$qmbase/sample_sites/(.+)$!) {
					$true = $1;
					}

				# skip legacy folders

				last Err if ($path =~ m!/(images|start_site)(/|$)!);

				# if we are path-restricted, exist unless $true has at least one right-ward match on an existing pattern
				if ($STATE{'use_template_editor'} == 2) {
					my @allow_paths = split(m!\,!, $STATE{'use_templates'} );
					my $b_allow = 0;
					foreach (@allow_paths) {
						my $qm_this_path = quotemeta(&url_decode($_));
						next unless ($true =~ m!^$qm_this_path($|/)!);
						$b_allow = 1;
						last;
						}
					last Err unless ($b_allow);
					}



				# if this is a folder entry, print the name:

				if (-d $path) {
					my $name = $basename;
					$name =~ tr!_! !;
					$name =~ s!^T\d*\.!!g;
					$name = &he($name);
					print qq!<li><p><b>$name</b></p></li>\n!;
					last Err;
					}



				# if it is a template, print it:

				last Err unless ($basename =~ m!\.template$!);
				last Err unless ($true);

				# strip sort-prefix
				$basename =~ s!^T\d*\.!!;

				my ($temp_err, $is_cgi) = &CheckName( $basename, 1 );
				if ($temp_err) {
					&ppstr(6, $temp_err );
					last Err;
					}

				$basename =~ m!^(.*)\.template$!;

				my $public_name = $1;
				$public_name =~ s!_no_include$!!;
				$public_name =~ tr!_! !;
				$public_name =~ s!^T\d*\.!!g;
				$public_name = &he($public_name);

				$true = &ue($true);

				print qq!\n\t<li><p><a href="$const{'admin_url'}Action=BT&amp;Template=$true"><b>$public_name</b></a></p></li>\n\n!;
				last Err;
				}
			return $err;
			};

		$err = &recurse( $const{'preferences folder'}, 'sample_sites', 0, $p_start, $p_entry, $p_stop );
		next Err if ($err);


		last Err;
		}
	return $err;
	}





sub BuildTemplate {
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_template_editor');
		next Err if ($err);


		unless ($FORM{'Template'}) {
			$err = "no template selected";
			next Err;
			}


		# changed 0021 - we allow folders in the 'Template' variable, i.e. Template = T0.Simple/T1.Foo/T33.Bar.template
		# we still want the protections of &CheckName(), but we'll now call it piece-wise on the parts within the slashes
		# this will still catch // and /../ and ^/ which are all illegal


		# boundary tests (because split() will strip boundary fields)
		if ($FORM{'Template'} =~ m!^/!) {
			$err = "Template value cannot begin with a slash";
			next Err;
			}
		elsif ($FORM{'Template'} =~ m!/$!) {
			$err = "Template value cannot end with a slash";
			next Err;
			}

		my $is_cgi;
		my $component;
		foreach $component (split(m!/!s, $FORM{'Template'})) {
			$component =~ s!^T\d*\.!!; # strip sort prefix
			($err, $is_cgi) = &CheckName( $component, 1 );
			next Err if ($err);
			}


		# if we are path-restricted, make sure that $FORM{'Template'} has at least one right-ward match on an existing pattern
		if ($STATE{'use_template_editor'} == 2) {
			my @allow_paths = split(m!\,!, $STATE{'use_templates'} );
			my $b_allow = 0;
			foreach (@allow_paths) {
				my $qm_this_path = quotemeta(&url_decode($_));
				next unless ($FORM{'Template'} =~ m!^$qm_this_path($|/)!);
				$b_allow = 1;
				last;
				}
			unless ($b_allow) {
				$err = "your account is allowed access only to certain groups of templates. The template you have selected is not in one of your allowed groups";
				next Err;
				}
			}

		my $FILE = $const{'preferences folder'} . 'sample_sites/' . $FORM{'Template'};

		# Read in the template file, and strip any comments:

		my $template = '';
		($err, $template) = &ReadFile( $FILE );
		next Err if ($err);

		&force_CRLF(\$template);

		my $new = '';
		foreach (split(m!\n!s, $template)) {
			next if (m!^\s*\#!);
			$new .= "$_\n";
			}
		$template = $new;


		my $text = '';
		# Has this template been used before?
		my %replace = ();

		my $datafile = ".$FORM{'Template'}";
		$datafile =~ s!/!.!g;

		if (-e $datafile) {
			($err, $text) = &ReadFile($datafile);
			next Err if ($err);
			}
		elsif ($template =~ m!<Genesis:Defaults>(.*?)</Genesis:Defaults>!is) {
			$text = $1;
			}


		foreach (split(m!\n!s, $text)) {
			next unless (m!^(.+)\=(.*)$!);
			my ($name, $value) = (&url_decode(&Trim($1)), &url_decode(&Trim($2)));
			$replace{$name} = $value;
			}


		if (-e '.shared.template') {
			($err, $text) = &ReadFile('.shared.template');
			foreach (split(m!\n!, $text)) {
				next unless (m!^(.+)\=(.*)$!);
				$replace{"shared_" . &url_decode(&Trim($1))} = &url_decode(&Trim($2));
				}
			}

print <<"EOM";

$const{'AdminFormFile'}
<input type="hidden" name="Action" value="VT" />
<input type="hidden" name="Template" value="$FORM{'Template'}" />

		<p>$str[149]</p>
		<hr size="1" />
EOM


		# reverse compatibility: insert the replace values:

		foreach (reverse sort keys %replace) {
			$template =~ s!\%$_\%!$replace{$_}!isg;
			}

		# extract the user input section:

		unless ($template =~ m!<Genesis:UserInput>(.*?)</Genesis:UserInput>!is) {
			$err = $str[154];
			next Err;
			}
		print &SetDefaults($1,\%replace);


print <<"EOM";

		<hr size="1" />

		<input type="submit" class="submit" value="$str[153]" />

</form>

		<p>$str[150]</p>
		<ul>
EOM

		foreach (split(m!</Genesis:File>!si, $template)) {
			next unless (m!<Genesis:File name=\"(.*?)\">(.*)!si);
			my ($file) = ($1);
			print "\t" x 3, '<li>';
			if (-e $file) {
				print qq!<a href="$STATE{'web_path'}$file">$file</a> - $str[152]!;
				}
			elsif ($file =~ m!\%!) {
				print "$file - $str[151]";
				}
			else {
				print $file;
				}
			print "</li>\n";
			}
		print "\t\t</ul>\n";
		last Err;
		}
	return $err;
	}




sub SaveTemplate {
	my ($p_upload_files) = @_;
	my $err = '';
	Err: {
		$err = &priv_check(1,'use_template_editor');
		next Err if ($err);


		# changed 0021 - we allow folders in the 'Template' variable, i.e. Template = T0.Simple/T1.Foo/T33.Bar.template
		# we still want the protections of &CheckName(), but we'll now call it piece-wise on the parts within the slashes
		# this will still catch // and /../ and ^/ which are all illegal


		# boundary tests (because split() will strip boundary fields)
		if ($FORM{'Template'} =~ m!^/!) {
			$err = "Template value cannot begin with a slash";
			next Err;
			}
		elsif ($FORM{'Template'} =~ m!/$!) {
			$err = "Template value cannot end with a slash";
			next Err;
			}

		my $is_cgi;
		my $component;
		foreach $component (split(m!/!s, $FORM{'Template'})) {
			$component =~ s!^T\d*\.!!; # strip sort prefix
			($err, $is_cgi) = &CheckName( $component, 1 );
			next Err if ($err);
			}


		# if we are path-restricted, make sure that $FORM{'Template'} has at least one right-ward match on an existing pattern
		if ($STATE{'use_template_editor'} == 2) {
			my @allow_paths = split(m!\,!, $STATE{'use_templates'} );
			my $b_allow = 0;
			foreach (@allow_paths) {
				my $qm_this_path = quotemeta(&url_decode($_));
				next unless ($FORM{'Template'} =~ m!^$qm_this_path($|/)!);
				$b_allow = 1;
				last;
				}
			unless ($b_allow) {
				my $ht = &he($FORM{'Template'});
				$err = "your account is allowed access only to certain groups of templates. The template you have selected is not in one of your allowed groups (selected template $ht)";
				next Err;
				}
			}


		# does this template include file uploads?
		my $text;
		($err, $text) = &ReadFile( "$const{'preferences folder'}sample_sites/$FORM{'Template'}" );
		next Err if ($err);

		unless ($text =~ m!<Genesis:UserInput>(.*?)</Genesis:UserInput>!is) {
			$err = $str[154];
			next Err;
			}
		my $ui = $1;
		if ($ui =~ m! type=\"?file!i) {
			# changed 0021 - do not save files unless there is an input type="file" in the UserInput portion of the template

			# upload some files?
			if (%$p_upload_files) {
				$err = &ui_Upload($p_upload_files);
				next Err if ($err);
				my $key = '';
				foreach $key (keys %$p_upload_files) {
					my $p_hash = $$p_upload_files{$key};
					next unless (($p_hash) and (defined($$p_hash{'server file name'})));
					$FORM{$key . "_filename"} = $$p_hash{'server file name'};
					delete $FORM{$key};
					}
				}
			}

		my %replace = ();

		$text = '';
		my ($name, $value) = ();
		while (($name, $value) = each %FORM) {
			$replace{$name} = $value;
			$text .= &ue($name) . '=' . &ue($value) . "\n" unless ($name =~ m!^shared_!);
			}

		my $datafile = ".$FORM{'Template'}";
		$datafile =~ s!/!.!g;

		$err = &WriteFile( $datafile, $text );
		next Err if ($err);



		# update the shared template:
		my $shared = '';
		if (-e '.shared.template') {
			($err, $text) = &ReadFile('.shared.template');
			foreach (split(m!\n!, $text)) {
				next unless (m!^(.+)\=(.*)$!);
				next if (defined($FORM{"shared_$1"}));
				$shared .= "$_\n";
				}
			}
		foreach (keys %FORM) {
			next unless (m!^shared_(.+)$!);
			$shared .= &ue($1) . '=' . &ue($FORM{$_}) . "\n";
			}
		$err = &WriteFile('.shared.template', $shared);
		next Err if ($err);




		my $key;
		foreach $key (keys %FORM) {
			# don't map if the sample contains HTML tags itself
			next if ($FORM{$key} =~ m!\<.*\>!s);
			# don't map if the key is a noconvert_ key
			next if ($key =~ m!^noconvert_!);
			$FORM{$key} =~ s!\cM!!sg;
			$FORM{$key} =~ s!\n!<br />\n!sg;
			}

		my (%visited, %cache) = ();
		my $b_no_parse_ssi = ($FORM{'Template'} =~ m!_no_include.template$!i) ? 1 : 0;

		$text = &ParseTemplate( $FORM{'Template'}, "$const{'preferences folder'}sample_sites", \%FORM, \%visited, \%cache, $b_no_parse_ssi );
		$text =~ s!\cM!!sg;

		my @temp_errors = ();
		my $temp_err_msg = '';

		my $prime_file = '';
		my $prime_complete = 0;


		# extract the fragments and then re-mix the file:

		foreach (split(m!<Genesis:Fragment Name=!is, $text)) {
			next unless (m!^\"(.+?)\".*?>(.*?)</Genesis:Fragment>!is);
			my ($name, $content) = ($1, $2);
			# strip leading and trailing vertical whitespace
			$content =~ s!^(\015|\012)*!!s;
			$content =~ s!(\015|\012)*$!!s;
			$FORM{"fragment:$name"} = $content;
			}


		# remix the file, using the fragments this time:

		%visited = ();

		$text = &ParseTemplate( $FORM{'Template'}, "$const{'preferences folder'}sample_sites", \%FORM, \%visited, \%cache, $b_no_parse_ssi );
		$text =~ s!\cM!!sg;

		%cache = (); # free memory


		foreach (split(m!\015|\012!s, $text)) {
			next unless (m!<Genesis:Import from=\"(.*?)\" to=\"(.*?)\">!i);
			my ($rel_old_file, $new_file) = ($1, $2);
			my $abs_old_file = "$const{'preferences folder'}sample_sites/$rel_old_file";

			my $is_cgi = 0;
			($temp_err_msg, $is_cgi) = &CheckName( $new_file,1 );
			if ($temp_err_msg) {
				push(@temp_errors, $temp_err_msg);
				next;
				}
			my $contents = '';
			($temp_err_msg, $contents) = &ReadFile( $abs_old_file );
			if ($temp_err_msg) {
				push(@temp_errors, $temp_err_msg);
				next;
				}
			$temp_err_msg = &WriteFile( $new_file, $contents );
			if ($temp_err_msg) {
				push(@temp_errors, $temp_err_msg);
				next;
				}
			&Mask( $new_file, $is_cgi );
			}



		foreach (split(m!</Genesis:Replace>!si, $text)) {
			next unless (m!<Genesis:Replace file="(.+)" pattern="(.+)">(.*)$!si);
			my ($file, $pattern, $replace_text) = ($1, $2, &Trim($3));

			my $hfile = &he($file);

			$err = &check_regex($pattern);
			next Err if ($err);

			unless (-e $file) {
				print "<p><b>Warning:</b> cannot update file '$hfile' - file does not exist.</p>\n";
				next;
				}

			my $is_cgi;
			($err, $is_cgi) = &CheckName( $file, 1 );
			next Err if ($err);

			my $text = '';
			($err, $text) = &ReadFile( $file );
			next Err if ($err);

			unless ($text =~ s!$pattern!$replace_text!isg) {
				my $hpattern = &he($pattern);
				print "<p><b>Warning:</b> unable to update file '$hfile' - pattern '$hpattern' not found.</p>\n";
				next;
				}

			$err = &WriteFile( $file, $text );
			next Err if ($err);

			&ppstr( 4, &pstr( 16, &he($file) ) );
			}




		foreach (split(m!</Genesis:File>!si, $text)) {
			next unless (m!<Genesis:File name=\"(.*?)\">(.*)!si);
			my ($file, $text) = ($1, $2);

			# strip leading and trailing vertical whitespace
			$text =~ s!^(\015|\012)*!!s;
			$text =~ s!(\015|\012)*$!!s;

			my $is_cgi = 0;
			($temp_err_msg, $is_cgi) = &CheckName( $file,1 );
			if ($temp_err_msg) {
				push(@temp_errors, $temp_err_msg);
				next;
				}

			$prime_file = $file unless ($prime_file);

			my $file_size = length($text);
			$file_size -= (-s $file) if (-s $file);
			if (not (($file_size < 0) or (&CheckFreeSpace($file_size)))) {
				push(@temp_errors, &pstr(9, $file, $str[29] ));
				last;
				}

			$temp_err_msg = &WriteFile( $file, $text );
			if ($temp_err_msg) {
				push(@temp_errors, $temp_err_msg);
				next;
				}
			&Mask( $file, $is_cgi );
			if ($file eq $prime_file) {
				$prime_complete = 1;
				}
			}

		foreach (@temp_errors) {
			&Report( &pstr(6,$_) );
			}



		&pppstr(155, "$STATE{'web_path'}$prime_file");


		if ($FORM{'Template'} =~ m!^(.+)\.template$!) {
			my $public_name = $1;
			$public_name =~ s!_no_include$!!;
			$public_name =~ tr!_! !;
			$public_name =~ s!(^|/)T\d*\.!$1!g;
			$public_name =~ s!/! / !g;
			my $true = &ue($FORM{'Template'});

			my $url = qq!$const{'admin_url'}Action=BT&amp;Template=$true!;

			&pppstr( 359, $url, $public_name );
			}


		last Err;
		}
	return $err;
	}




1;