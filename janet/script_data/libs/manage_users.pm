use strict;

=item desc

Contains Manage Users interface, Anon Signup interface, and related utility functions.

=cut



sub init_user_folder($$);
sub init_user_folder($$) {
	my ( $folder, $username ) = @_;
	my $err = '';
	Err: {

		unless ($folder) {
			$err = "invalid argument. Must supply the 'folder' parameter";
			next Err;
			}

		# strip any trailing slash; mkdir() prefers it that way sometimes:
		$folder =~ s!/$!!;

		unless (-e $folder) {
			unless (mkdir( $folder, 0777 )) {
				$err = &pstr( 21, $folder, $! );
				next Err;
				}
			&Mask( $folder, 0 );
			}
		unless (-d $folder) {
			$err = "user home folder '$folder' does not exist";
			next Err;
			}

		# we support the setup of non-writable folders as home directory.
		# but we do warn about it:
		my $stub = $folder . '/.is_user_dir';
		$err = &WriteFile( $stub, $username );
		if ($err) {
			&ppstr( 5, $err );
			$err = '';
			}
		&Mask( $stub, 0 );






		my $start_site_dir = "$const{'preferences folder'}sample_sites/start_site";
		unless (opendir(DIR, $start_site_dir)) {
			$err = "unable to open folder '$start_site_dir' - $!";
			next Err;
			}
		my @files = readdir(DIR);
		closedir(DIR);

		my $err_x = '';
		my $contents = '';
		my $b_is_cgi = 0;
		foreach (@files) {
			my $file;
			($err_x, $b_is_cgi, $file) = &CheckName( $_, 1 );
			#NOTE: no error handling here...
			my $abs_old_file = "$start_site_dir/$file";
			my $abs_new_file = $folder . '/' . $file;
			next if (-e $abs_new_file);

			($err, $contents) = &ReadFile( $abs_old_file );
			next Err if ($err);

			# we support the setup of non-writable folders as home directory.
			# but we do warn about it:
			$err = &WriteFile( $abs_new_file, $contents );
			if ($err) {
				&ppstr( 5, $err );
				$err = '';
				}

			&Mask( $abs_new_file, $b_is_cgi );
			}

		}
	return $err;
	};



sub anon_create_account {
	my $err = '';
	Err: {
		my %webmaster_info = ();

		my $warnings;
		($err, $warnings) = &LoadUserPrefs( $private{'super user'}, \%webmaster_info );
		next Err if ($err);

		unless ($system_eff{'/Users/Add/automatic'}) {
			$err = $str[233];
			next Err;
			}

		unless (($system_eff{'Mail Server'}) or ($system_eff{'Sendmail Program'})) {
			$err = $str[7];
			next Err;
			}

		if (($system_eff{'/Users/Add/admin-approve'}) and (not $webmaster_info{'email_address'})) {
			$err = $str[54];
			next Err;
			}


		my $sa = $FORM{'SA'} || '';

		if ($sa eq 'CA') {

			&ppstr( 161, $str[330] );

			my $is_cgi = 0;
			($err, $is_cgi) = &CheckName( $FORM{'Username'}, 1, 1 );
			next Err if ($err);

			foreach ($private{'super user'}, '_default') {
				if ($FORM{'Username'} eq $_) {
					$err = &pstr(38,$_);
					next Err;
					}
				}

			$err = &fd_validate( $FORM{'email_address'}, 'email', 1, 0 );
			next Err if ($err);


			my $UserFile = "$const{'preferences folder'}accounts/$FORM{'Username'}.txt";
			if (-e $UserFile) {
				$err = &pstr(232,&he($FORM{'Username'}));
				next Err;
				}


			my %TMP = ();

			my $warnings;
			($err, $warnings) = &LoadUserPrefs( '_default', \%TMP );
			next Err if ($err);

			# the default guy doesn't have a name or email
			delete $TMP{'full_name'};
			delete $TMP{'email_address'};

			$TMP{'AccountCreated'} = time();
			$TMP{'LastLogin'} = 0;
			$TMP{'LastLoginFrom'} = '';


			my $UserDIR = $TMP{'Author:UserFolder'};
			$UserDIR =~ s!\%username\%!$FORM{'Username'}!ig;

			if (-e $UserDIR) {
				$err = &pstr(18,&he($UserDIR));
				next Err;
				}

			my %UserData = %TMP;

			foreach ('Username', 'full_name', 'email_address') {
				$UserData{$_} = $FORM{$_};
				}

			$UserData{'WaitAdminApprove'} = $system_eff{'/Users/Add/admin-approve'};
			$UserData{'WaitEmailValidate'} = 1;
			$UserData{'WaitEmailValidateCode'} = $auth->InventPassword();


			$err = &user_data_validate( $FORM{'Username'}, \%UserData );
			next Err if ($err);

			my $warn_msg;
			($err, $warn_msg) = &user_data_save( $FORM{'Username'}, \%UserData, 0, 1 );
			next Err if ($err);
			print $warn_msg;



			my %replace = %FORM;
			local $_;
			foreach (keys %const) {
				$replace{$_} = $const{$_};
				}
			foreach (keys %webmaster_info) {
				my $name = "webmaster_" . $_;
				$replace{$name} = $webmaster_info{$_};
				}
			$replace{'date_smtp'} = &FormatDateTime( time(), 'smtp' );
			$replace{'full_form'} = $replace{'full_env'} = '';

			foreach (sort keys %FORM) {
				$replace{'full_form'} .= "$_ = $FORM{$_}\015\012";
				}
			foreach (sort keys %ENV) {
				$replace{'full_env'} .= "$_ = $ENV{$_}\015\012\015\012";
				}

			if ($system_eff{'/Users/Add/admin-approve'}) {

				# Parse the welcome message up here - some fields will be deleted inside &SaveUserPrefs

				my $welcome_message = &ParseTemplate('account_request_email_2.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );

				if ($webmaster_info{'email_address'}) {
					require 'network.pm';
					my $trace = '';
					($err, $trace) = &SendMailEx(
						'host' => $system_eff{'Mail Server'},
						'pipeto' => $system_eff{'Sendmail Program'},
						'from' => $FORM{'email_address'} || $webmaster_info{'email_address'},
						'to' => $webmaster_info{'email_address'},
						'raw' => $welcome_message,
						);
					next Err if ($err);
					&Report( &pstr(4, $str[17] ) );
					}
				}
			else {

				$replace{'password'} = $auth->InventPassword();

				$err = &password_force( $FORM{'Username'}, $replace{'password'}, $replace{'password'} );
				next Err if ($err);


				&Report(&pstr(4,&pstr(15,&he($FORM{'Username'}))));

				$err = &init_user_folder( $UserDIR, $FORM{'Username'} );
				next Err if ($err);

				if ($FORM{'email_address'}) {
					require 'network.pm';
					my $trace = '';

					my $welcome_message = &ParseTemplate('welcome_email_2.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );
					($err, $trace) = &SendMailEx(
						'host' => $system_eff{'Mail Server'},
						'pipeto' => $system_eff{'Sendmail Program'},
						'to' => $FORM{'email_address'},
						'from' => $webmaster_info{'email_address'} || $FORM{'email_address'},
						'raw' => $welcome_message,
						);
					next Err if ($err);


					if ($webmaster_info{'email_address'}) {
						require 'network.pm';
						my $message = &ParseTemplate('account_notify_email_2.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );
						($err, $trace) = &SendMailEx(
							'host' => $system_eff{'Mail Server'},
							'pipeto' => $system_eff{'Sendmail Program'},
							'from' => $FORM{'email_address'},
							'to' => $webmaster_info{'email_address'},
							'raw' => $message,
							);
						next Err if ($err);
						}

					&Report( &pstr(4, &pstr(11,&he($FORM{'email_address'})) ) );
					}

				}
			last Err;
			}
		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}

		my $action = $str[266];
		if ($system_eff{'/Users/Add/admin-approve'}) {
			$action = $str[267];
			}

print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="AnonCreate" />
<input type="hidden" name="SA" value="CA" />

<table border="0">
<tr>
	<th align="center" colspan="2">$str[49]</th>
</tr>
<tr>
	<td align="right"><b>$str[36]:</b></td>
	<td><input name="Username" /></td>
</tr>
<tr>
	<td align="right"><b>$str[98]:</b></td>
	<td><input name="email_address" /></td>
</tr>
<tr>
	<td align="right"><b>$str[97]:</b></td>
	<td><input name="full_name" /></td>
</tr>
<tr>
	<td align="right"><b>$str[265]:</b></td>
	<td><textarea name="comments" rows="6" cols="40"></textarea></td>
</tr>
<tr>
	<td><br /></td>
	<td><input type="submit" class="submit" value="$action" /></td>
</tr>
</table>

</form>


EOM

		last Err;
		}
	return $err;
	}



sub CreateUser {

	my $err = '';
	Err: {

		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);


		local $_; # init



		# Create User makes an entry (username.txt) in the preferences directory,
		# and creates a home directory for the new user.  The format is
		# &CreateUser with $FORM{$Name} = $Value defined. This procedure exits,
		# with an error code, if directory or userfile already exist.



		# validation steps - perform first before writing to disk:



		# choose a password for this user -- either a webmaster-defined one, or a random one:
		#	then save it to $FORM{'password'} and perform validation

		$FORM{'password'} = '';
		foreach ('NewPass', 'NewPass2') {
			next if (defined($FORM{$_}));
			$FORM{$_} = '';
			}

		if (($FORM{'NewPass'}) or ($FORM{'NewPass2'})) {
			if ($FORM{'NewPass'} eq $FORM{'NewPass2'}) {
				$FORM{'password'} = $FORM{'NewPass'};
				}
			else {
				$err = $str[40];
				next Err;
				}
			}
		else {
			$FORM{'password'} = $auth->InventPassword();
			}
		if (length($FORM{'password'}) < $system_eff{'Min Password Length'}) {
			$err = &pstr(229,$system_eff{'Min Password Length'});
			next Err;
			}





		my $is_cgi = 0;
		($err, $is_cgi) = &CheckName( $FORM{'Username'}, 1, 1 );
		next Err if ($err);

		local $_;
		foreach ($private{'super user'}, '_default') {
			if ($FORM{'Username'} eq $_) {
				$err = &pstr(38,$_);
				next Err;
				}
			}

		# check whether the user-file or user-folder already exists:

		my $UserFile = "$const{'preferences folder'}accounts/$FORM{'Username'}.txt";
		if (-e $UserFile) {
			$err = &pstr(232,$FORM{'Username'});
			next Err;
			}

		my $UserDIR = $FORM{'Author:UserFolder'};
		$UserDIR =~ s!\%username\%!$FORM{'Username'}!ig;
		if (-e $UserDIR) {
			&ppstr(5, &pstr(18,$UserDIR));
			}


		my %userdata = ();

		$err = &user_data_from_form( $FORM{'Username'}, \%userdata );
		next Err if ($err);

		$err = &user_data_from_form_admin( $FORM{'Username'}, \%userdata );
		next Err if ($err);

		$err = &user_data_validate( $FORM{'Username'}, \%userdata );
		next Err if ($err);

		my $warnings;
		($err, $warnings) = &user_data_save( $FORM{'Username'}, \%userdata );
		next Err if ($err);
		print $warnings;


		# create and prepare the user's home directory:

		$err = &init_user_folder( $UserDIR, $FORM{'Username'} );
		next Err if ($err);


		# save the user's password:

		$err = &password_force( $FORM{'Username'}, $FORM{'password'}, $FORM{'password'} );
		next Err if ($err);


		# Parse the welcome message up here:

		my %replace = %const;

		# Initialize:
		$replace{'webmaster_full_name'} = '';
		$replace{'webmaster_email_address'} = '';

		foreach (keys %FORM) {
			$replace{$_} = $FORM{$_};
			}

		my %webmaster_info = ();
		($err, $warnings) = &LoadUserPrefs( $private{'super user'}, \%webmaster_info );
		next Err if ($err);
		print $warnings;

		foreach (keys %webmaster_info) {
			my $name = "webmaster_" . $_;
			$replace{$name} = $webmaster_info{$_};
			}

		$replace{'password'} = $FORM{'password'};
		$replace{'date_smtp'} = &FormatDateTime( time(), 'smtp' );

		my $welcome_message = &ParseTemplate('welcome_email_2.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );

		&Report( &pstr(4, "created new user '$FORM{'Username'}'" ) );

		if (($FORM{'email_address'}) and ($system_eff{'Mail Server'} or $system_eff{'Sendmail Program'})) {
			require 'network.pm';
			my $trace = '';
			($err, $trace) = &SendMailEx(
				'host'       => $system_eff{'Mail Server'},
				'pipeto'     => $system_eff{'Sendmail Program'},
				'to'         => $FORM{'email_address'},
				'from'       => $webmaster_info{'email_address'} || $FORM{'email_address'},
				'raw'    => $welcome_message,
				);
			if ($err) {
				&Report( &pstr(6,$err) );
				$err = '';
				}
			else {
				&Report( &pstr(4, &pstr(11, &he($FORM{'email_address'}))));
				last Err;
				}
			}
		&ppstr(4, &pstr(178, $FORM{'password'}));
		last Err;
		}
	return $err;
	}





sub ui_Confirmed {
	my ($object_name) = @_;
	if (($FORM{'Y'}) and ($FORM{'Y'} eq 'Y1')) {
		delete $FORM{'Y'};
		return 1;
		}

	&pppstr(164, $object_name);

print <<"EOM";


	<blockquote>

$const{'AdminForm'}
		<input type="hidden" name="Y" value="Y1" />

EOM

	my ($name, $value);
	while (($name, $value) = each %FORM) {
		next if ($name =~ m!^(cwd|web_auth_cp|y|sw)$!i);
		printf( '<input type="hidden" name="%s" value="%s" />', &he($name,$value));
		}

print <<"EOM";

		<p><input type="submit" class="submit" value="$str[165]" /></p>

		</form>

	</blockquote>

EOM
	return 0;
	}




sub Give_Password {
	&pppstr(192, $FORM{'UN'});

print <<"EOM";

$const{'AdminForm'}

	<input type="hidden" name="Action" value="UA" />
	<input type="hidden" name="sa" value="SA" />
	<input type="hidden" name="UN" value="$FORM{'UN'}" />
	<table border="0">
	<tr>
		<td align="right"><b>$str[101]:</b></td>
		<td><input type=password name="NewPass" /></td>
	</tr>
	<tr>
		<td align="right"><b>$str[102]:</b></td>
		<td><input type=password name="NewPass2" /></td>
	</tr>
	</table>
	<p><input type="submit" class="submit" value="$str[72]" /></p>
	</form>

EOM

	}








sub ui_ManageUsers {

	my $err = '';
	Err: {

print <<"EOM";

<p><b>
	<a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=UA">$str[57]</a> &gt;

EOM


		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);


		my $u_username = '';
		if (defined($FORM{'UN'})) {
			$u_username = &ue($FORM{'UN'});
			}


		my $sa = $FORM{'sa'} || '';

		# delete user
		if ($sa eq 'DU') {
			print " $str[166]</b></p>";

			my $username = $FORM{'UN'};

			last Err unless &ui_Confirmed($username);

			my $warnings = 0;

			my %TMP = ();

			my $load_warnings;
			($err, $load_warnings) = &LoadUserPrefs( $username, \%TMP );
			next Err if ($err);

			my $UserDIR = $TMP{'Author:UserFolder:parsed'};

			my $file = "$UserDIR.is_user_dir";
			if ((-e $file) and (not (unlink($file)))) {
				$err = &pstr(13, $file, $! );
				&Report( &pstr(5, $err ) );
				$warnings++;
				}

			my $UserFile = "$const{'preferences folder'}accounts/$username.txt";
			if ((-e $UserFile) and (not (unlink($UserFile)))) {
				$err = &pstr(13, $UserFile, $! );
				&Report( &pstr(5, $err ) );
				$warnings++;
				}

			$err = $auth->DeleteUser($username,1);
			if ($err) {
				&Report( &pstr(5, $err ) );
				$warnings++;
				}

			if ($warnings) {
				&Report( &pstr(4, &pstr(167,$username) ) );
				}
			else {
				&Report( &pstr(4, &pstr(168,$username) ) );
				}
			&pppstr(169,$UserDIR);
			last Err;
			}


		# edit user
		if ($sa eq 'EP') {
			print qq!<a href="$const{'admin_url'}Action=UA&amp;sa=EP&amp;UN=$u_username">$str[171] $FORM{'UN'}</a> &gt; $str[66]</b></p>!;
			require 'my_account.pm';
			&ShowSettings( $FORM{'UN'}, 0, 0);
			last Err;
			}

		# save user info
		if ($sa eq 'SP') {
			print qq!<a href="$const{'admin_url'}Action=UA&amp;sa=EP&amp;UN=$u_username">$str[171] $FORM{'UN'}</a> &gt; $str[72]</b></p>!;

			if ($FORM{'UN'} eq '_default') {
				# enter some bogus values to the validation won't explode:
				$FORM{'full_name'} = '';
				$FORM{'email_address'} = 'nobody@nowhere.00';
				}

			my %updates = ();

			$err = &user_data_from_form( $FORM{'UN'}, \%updates );
			next Err if ($err);

			$err = &user_data_from_form_admin( $FORM{'UN'}, \%updates );
			next Err if ($err);

			$err = &user_data_validate( $FORM{'UN'}, \%updates, 1 );
			next Err if ($err);

			my $warnings;
			($err, $warnings) = &user_data_save( $FORM{'UN'}, \%updates );
			next Err if ($err);
			print $warnings;

			if (($FORM{'NewPass'}) or ($FORM{'NewPass2'})) {
				$err = &password_force( $FORM{'UN'}, $FORM{'NewPass'}, $FORM{'NewPass2'} );
				next Err if ($err);
				}

			last Err;
			}

		# create new account - prompt for data
		if ($sa eq 'NA') {
			print qq! <a href="$const{'admin_url'}Action=UA&amp;sa=NA">$str[170]</a></b></p>\n!;
			require 'my_account.pm';
			&ShowSettings( '', 0, 1);
			last Err;
			}

		# create new account - save data
		if ($sa eq 'CU') {
			print qq! <a href="$const{'admin_url'}Action=UA&amp;sa=NA">$str[170]</a> &gt; $str[72]</b></p>\n!;
			$err = &CreateUser();
			next Err if ($err);
			last Err;
			}

		# reset password - save data
		if ($sa eq 'RP') {
			print " $str[172]</b></p>";
			&Give_Password();
			last Err;
			}

		# approve pending accounts
		if ($sa eq 'ApproveAccounts') {
			print " $str[173]</b></p>\n";

			my ($name, $value) = ();
			while (($name, $value) = each %FORM) {

				next unless ($name =~ m!^approve_(.*?)$!);
				my $username = $1;

				if ($value == 1) {
					&pppstr(161,&pstr(174,&he($username)));
					my $UserFile = "$const{'preferences folder'}accounts/$username.txt";
					if ((-e $UserFile) and (not (unlink($UserFile)))) {
						$err = &pstr(13, &he($UserFile, $! ));
						&Report( &pstr(5, $err ) );
						$err = '';
						}
					else {
						&ppstr(4, &pstr(19, &he($UserFile) ));
						}
					$auth->DeleteUser($username,1); # just in case
					next;
					}
				elsif ($value == 2) {
					&pppstr(161, &pstr(175,&he($username)));
					next;
					}
				elsif ($value == 0) {

					my $UserFile = "$const{'preferences folder'}accounts/$username.txt";
					unless (-e $UserFile) {
						&ppstr(6, &pstr(176, $UserFile));
						next;
						}

					&pppstr(161, &pstr(177, &he($username)));

					my %UserData = ();

					my $warnings;
					($err, $warnings) = &LoadUserPrefs( $username, \%UserData );
					next Err if ($err);

					$UserData{'WaitAdminApprove'} = 0;

					my $warn_msg;
					($err, $warn_msg) = &user_data_save( $username, \%UserData );
					next Err if ($err);
					print $warn_msg;


					my $password = $auth->InventPassword();

					$err = &password_force( $username, $password, $password );
					next Err if ($err);

					# Parse the welcome message up here - some fields will be deleted inside &SaveUserPrefs

					my %replace = %const;
					foreach (keys %UserData) {
						$replace{$_} = $UserData{$_};
						}
					my %webmaster_info = ();

					($err, $warnings) = &LoadUserPrefs( $private{'super user'}, \%webmaster_info );
					next Err if ($err);

					foreach (keys %webmaster_info) {
						my $name = "webmaster_" . $_;
						$replace{$name} = $webmaster_info{$_};
						}

					$replace{'password'} = $password;
					$replace{'date_smtp'} = &FormatDateTime( time(), 'smtp' );


					my $welcome_message = &ParseTemplate('welcome_email_2.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );


					$err = &init_user_folder( $UserData{'Author:UserFolder:parsed'}, $UserData{'Username'} );
					next Err if ($err);


					if ($UserData{'email_address'}) {
						require 'network.pm';
						my $trace = '';
						my $from_addr = $webmaster_info{'email_address'} || $UserData{'email_address'};
						($err, $trace) = &SendMailEx(
							'host'       => $system_eff{'Mail Server'},
							'pipeto'     => $system_eff{'Sendmail Program'},
							'to'         => $UserData{'email_address'},
							'from'       => $from_addr,
							'raw'    => $welcome_message,
							);
						next Err if ($err);
						&Report( &pstr(4, &pstr(11, &he($UserData{'email_address'}) ) ));
						}
					else {
						&ppstr(4, &pstr(178, &he($password)));
						}
					&Report( &pstr(4, &pstr(15, &he($UserData{'Username'}) )) );
					next;
					}
				}

			last Err;
			}

		if ($sa eq 'SA') {
			print " $str[172] &gt; $str[72]</b></p>";
			if ($private{'super user'} eq $FORM{'UN'}) {

				$err = &password_set();
				next Err if ($err);

				}
			else {

				$err = &password_force( $FORM{'UN'}, $FORM{'NewPass'}, $FORM{'NewPass2'} );
				next Err if ($err);

				}
			last Err;
			}

		if ($sa eq 'SS') {
			print " $str[72]</b></p>";
			require 'system_settings.pm';
			my %changes = (
				'/Users/Add/sign-up-url' => $FORM{'/Users/Add/sign-up-url'} || '',
				'/Users/Add/automatic' => $FORM{'/Users/Add/automatic'} ? 1 : 0,
				'/Users/Add/admin-approve' => $FORM{'/Users/Add/admin-approve'} ? 1 : 0,
				);
			$err = &save_system_settings( 1, %changes );
			next Err if ($err);
			last Err;
			}

		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}

		print " $str[66]</b></p>";

		my @usernames = ( $private{'super user'}, '_default' );

		my $accounts_dir = "$const{'preferences folder'}accounts";
		unless (opendir(DIR, $accounts_dir)) {
			$err = &pstr(22, $accounts_dir, $! );
			next Err;
			}
		local $_;
		foreach (sort readdir(DIR)) {
			next unless (m!^(.+)\.txt$!i);
			my $User = $1;
			next if ($User eq $private{'super user'});
			next if ($User eq '_default');
			push(@usernames, $User);
			}
		closedir(DIR);

		if ($FORM{'set:cp'}) {
			$FORM{'p:cp'} = $FORM{'set:cp'};
			delete $FORM{'set:cp'};
			}


		my $current_pos = $FORM{'p:cp'} || 1;

		unless ($current_pos =~ m!^\d+$!) {
			$current_pos = 1;
			} # don't let zero or negative creep in...

		my $units_per_page = 50;
		my $maximum = scalar @usernames;

		my $url = "$const{'admin_url'}Action=UA&amp;set:cp=";

		my $b_is_exact_count = 1;

		my ($jump_sum, $jump_links) = &str_jumptext_ex( $current_pos, $units_per_page, $maximum, $url, $b_is_exact_count );

		print '<p>' . $jump_sum . '<br />' . $jump_links . '</p>' if ($jump_links);

		my @users_wait_approval = ();

print <<"EOM";

<table border="0" cellpadding="4" cellspacing="1" bgcolor="#000000">
<tr bgcolor="#9eb3c7">
	<th align="center">$str[36]</th>
	<th align="center">$str[118]</th>
	<th align="center">$str[119]</th>
	<th align="center" colspan="3">$str[125]</th>
</tr>

EOM



		my $start_index = $current_pos - 1;
		my $end_index = $current_pos + $units_per_page - 2;

		if ($#usernames < $end_index) {
			$end_index = $#usernames;
			}


		my %userdata = ();
		my $User;
		foreach $User (@usernames[$start_index..$end_index]) {

			my $warnings;
			($err, $warnings) = &LoadUserPrefs( $User, \%userdata );
			next Err if ($err);
			print $warnings;

			my $date_created_str = &FormatDateTime( $userdata{'AccountCreated'}, 12, 0 );

			my $time_str = $str[195];
			if ($userdata{'LastLogin'}) {
				$time_str = &get_age_str( time() - $userdata{'LastLogin'} );
				}

			my $image = 'user_normal.gif';

			my ($h_User, $u_User) = (&he($User), &ue($User));

			my $reset_pass_link = qq!<a href="$const{'admin_url'}Action=UA&amp;UN=$u_User&amp;sa=RP">$str[172]</a>!;
			my $delete_link = qq!<a href="$const{'admin_url'}Action=UA&amp;UN=$u_User&amp;sa=DU">$str[147]</a>!;

			my $b_reserved = (($User eq $private{'super user'}) or ($User eq '_default')) ? 1 : 0;

			if ($b_reserved) {
				$image = 'user_admin.gif';
				$reset_pass_link = '<br />';
				$delete_link = '<br />';

				if ($User eq '_default') {
					$date_created_str = '-';
					$time_str = '-';
					}

				}
			elsif ($userdata{'is_disabled'}) {
				$image = 'user_disabled.gif';
				}

			if ($userdata{'WaitAdminApprove'}) {
				push( @users_wait_approval, $User );
				next;
				}

print <<"EOM";

<tr bgcolor="#d5d2bb">
	<td><img src="$system_eff{'Images URL'}$image" height="15" width="15" alt="" /> $h_User</td>
	<td align="center"><tt>$date_created_str</tt></td>
	<td align="center"><tt>$time_str</tt></td>
	<td><a href="$const{'admin_url'}Action=UA&amp;UN=$u_User&amp;sa=EP">$str[130]</a></td>
	<td>$reset_pass_link</td>
	<td>$delete_link</td>
</tr>

EOM
			}

print <<"EOM";

</table>

<p><b>[
	<a href="$const{'admin_url'}Action=UA&amp;sa=NA">$str[170]</a> |
	<a href="$const{'admin_url'}Action=UA&amp;sa=EP&amp;UN=_default">Default Settings for New Accounts</a>
]</b></p>

<p><br /></p>

<p><b>$str[76]</b></p>

EOM

		if (($STATE{'email_address'}) and (($system_eff{'Mail Server'}) or ($system_eff{'Sendmail Program'}))) {

print &SetDefaults(<<"EOM", \%system_raw);

$const{'AdminForm'}
<input type="hidden" name="Action" value="UA" />
<input type="hidden" name="sa" value="SS" />

$str[180]

<table border="0">
<tr>
	<td><input type="hidden" name="/Users/Add/automatic_udav" value="0" /><input type="checkbox" name="/Users/Add/automatic" value="1" /></td>
	<td>$str[181]</td>
</tr>
<tr>
	<td><input type="hidden" name="/Users/Add/admin-approve_udav" value="0" /><input type="checkbox" name="/Users/Add/admin-approve" value="1" /></td>
	<td>$str[182]</td>
</tr>
</table>

<br />

<table border="0" cellpadding="4" cellspacing="0">
<tr>
	<td valign="middle"><b>Sign-Up URL:</b></td>
	<td valign="middle"><input name="/Users/Add/sign-up-url" size="$const{'TEXT_INPUT_SIZE'}" /></td>
	<td valign="middle">[<a href="$const{'help file'}1100.html" target="_blank">$str[55]</a>]</td>
</tr>
</table>

<p>The <b>Sign-Up URL</b> is the web page where visitors will be sent to sign up for new accounts.</p>

<p>The variable <tt>%admin_url%</tt> can be used within the Sign-Up URL to represent the main script URL and its query string. The default - <tt>%admin_url%Action=AnonCreate</tt> - will direct prospective new users to the default sign-up form.</p>

<p><input type="submit" class="submit" value="$str[72]"></p>

</form>

EOM
			&pppstr(183, &he($STATE{'email_address'}, $system_eff{'Mail Server'}, $system_eff{'Sendmail Program'}));
			}
		else {
			&ppstr(184, "$const{'admin_url'}Action=PR", "$const{'admin_url'}Action=SY" );
			}


		if ($jump_links) {
			@users_wait_approval = @usernames; # long list
			}

		my $acc_text = '';
		foreach $User (@users_wait_approval) {

			next if ($User eq $private{'super user'});
			next if ($User eq '_default');

			my $warnings;
			($err, $warnings) = &LoadUserPrefs( $User, \%userdata );
			next Err if ($err);
			print $warnings;

			next unless ($userdata{'WaitAdminApprove'});

			my $date_created_str = &FormatDateTime( $userdata{'AccountCreated'}, 12, 0 );

			my ($h_User, $h_name, $h_email) = &he($User,$userdata{'full_name'},$userdata{'email_address'});

$acc_text .= <<"EOM";

<tr bgcolor="#d5d2bb">
	<td nowrap="nowrap"><img src="$system_eff{'Images URL'}user_normal.gif" height="15" width="15" alt="" /> $h_User</td>
	<td nowrap="nowrap"><tt>$date_created_str</tt></td>
	<td nowrap="nowrap">$h_name</td>
	<td>$h_email</td>
	<td align="center"><input type="radio" name="approve_$h_User" value="0" /></td>
	<td align="center"><input type="radio" name="approve_$h_User" value="1" /></td>
	<td align="center"><input type="radio" name="approve_$h_User" value="2" checked="checked" /></td>
</tr>

EOM
			}

if ($acc_text) {


print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="UA" />
<input type="hidden" name="sa" value="ApproveAccounts" />

<p>$str[185]</p>

<table border="0" cellpadding="4" cellspacing="1" bgcolor="#000000">
<tr bgcolor="#9eb3c7">
	<th align="center">$str[36]</th>
	<th align="center">$str[186]</th>
	<th align="center">$str[97]</th>
	<th align="center">$str[98]</th>
	<th align="center">$str[187]</th>
	<th align="center">$str[188]</th>
	<th align="center">$str[189]</th>
</tr>
$acc_text
</table>
<p><input type="submit" class="submit" value="$str[190]" /></p>
</form>

EOM
			}
		else {
			print "<p>$str[191]</p>\n";
			}
		last Err;
		}
	return $err;
	}


sub str_jumptext_ex {
	my ( $start_pos, $units_per_page, $maximum, $url, $b_is_exact_count ) = @_;

	my $jump_sum = '';
	my $jump_links = '';

	$start_pos = 1 if ($start_pos < 1);

	my $end_pos = $start_pos + $units_per_page - 1;


	unless ($b_is_exact_count) {
		$b_is_exact_count = 1 if ($maximum < $end_pos);
		}

	$end_pos = $maximum if ($maximum < $end_pos);

	if ($b_is_exact_count) {
		$jump_sum = sprintf( 'Records %s-%s of %s displayed.', $start_pos, $end_pos, $maximum );
		}
	else {
		$jump_sum = sprintf( 'Records %s-%s of %s displayed.', $start_pos, $end_pos, "$end_pos+" );

		# Okay, we've printed what we know.  Now, for purposes of generating advance links, pretend that there's at least one page beyond this one (we know that if max < curr+units then we would have toggled to b_is_exact_count earlier.  and if max already exceeds this page's worth fo data, then there's no need to tweak it:

		if ($maximum == $end_pos) {
			$maximum++;
			}
		}

	if ($maximum > $units_per_page) {

		# Time for a scrolling thing - "<- Previous 1 2 3 4 5 Next ->"

		$jump_links .= 'Results Pages:';
		$jump_links .= ' ';

		if ($start_pos > 1) {
			my $prev_pos = $start_pos - $units_per_page;
			if ($prev_pos < 0) {
				$prev_pos = 0;
				}
			$jump_links .= "[ <a href=\"$url$prev_pos\">&lt;&lt; Previous</a> ] ";
			}

		my $nlinks = 1 + int(($maximum - 1) / $units_per_page);
		my $thislink = 1 + int($start_pos / $units_per_page);

		my $start = 1;
		if ($thislink > 15) {
			$start = $thislink - 15;
			}

		my $x = 0;
		for ($x = $start; $x <= $nlinks; $x++) {
			if ($x == $thislink) {
				$jump_links .= " <b>$x</b>";
				}
			else {
				$jump_links .= " <a href=\"$url" . (1 + (($x - 1) * $units_per_page)) . "\">$x</a>\n";
				}
			last if ($x > ($start + 18));
			}

		if ($maximum > $end_pos) {
			$jump_links .= " [ <a href=\"$url" . ($start_pos + $units_per_page) . "\">Next &gt;&gt;</a> ]";
			}

		}
	return ($jump_sum, $jump_links);
	}



1;
