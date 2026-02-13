use strict;

=item desc

Contains the admin interfaces for Event Log, Manage System Settings, Update License

Includes utility functions only needed by those interfaces.

=cut


sub save_system_settings($%);
sub save_system_settings($%) {
	my ($b_verbose, %changes) = @_;
	my $err = '';
	Err: {

		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);

		if ($const{'mode'} == 0) {
			$err = $str[45];
			next Err;
			}

		# perform validation here instead of within &validate_system_settings because
		# this is expensive file-system-based validation; don't want to perform it at
		# every startup
		if ($changes{'Sendmail Program'}) {
			require 'network.pm';
			$err = &sendmail_valid($changes{'Sendmail Program'});
			next Err if ($err);
			}

		# another expensive file-based query:
		if ($changes{'Default Language'}) {
			my @null = ();
			$err = &loadlang( $changes{'Default Language'}, \@null, 1 );
			next Err if ($err);
			}


		my %copy = %system_eff;

		my $html_status = '';

		local $_;
		foreach (keys %changes) {
			next unless (defined($system_eff{$_})); # ignore non-sense values in %changes

			next if (m!^(Base Folder|Base URL)$!); # reverse compatibility read-only values
			next unless ($system_eff{$_} ne $changes{$_});
			$copy{$_} = $changes{$_};
			$html_status .= '<p>' . &pstr( 161, &pstr( 290, &he( $_, $system_eff{$_}, $changes{$_} ) ) ) . '</p>';
			}

		$err = &validate_system_settings( \%copy );
		next Err if ($err);

		# if we get here, then first-pass validation was successful

		print $html_status if ($b_verbose);
		%system_eff = %copy;

		my $text = '';
		foreach (sort keys %system_eff) {
			my $value = $system_eff{$_};
			$value =~ s!(\r|\n)+!\\CRLF!sg;
			$text .= "$_==$value\n";
			}
		$err = &WriteFile( "$const{'preferences folder'}security.txt", $text );
		next Err if ($err);

		&ppstr( 4, $str[291] ) if ($b_verbose);

		last Err;
		}
	return $err;
	};












sub ui_SystemSettings {
	my $err = '';
	Err: {

print <<"EOM";
<p><b>
	<a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=SY">$str[240]</a> &gt;
EOM

		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);

		require 'network.pm';

		my $sa = $FORM{'sa'} || '';

		if ($sa eq 'sys_info') {


			print qq! <a href="$const{'admin_url'}Action=SY&amp;sa=$sa">$str[281]</a></b></p>\n!;

			&pppstr(44, &he( $], $^X, $^O, &query_env('SERVER_SOFTWARE')) );
			print "<p><b>$str[42]</b></p>\n";
			print qq!<table border="1" cellpadding="4" cellspacing="0">\n!;
			my ($var, $value);
			foreach $var (sort keys %ENV) {
				($var, $value) = &he( $var, $ENV{$var} );
				print qq!<tr><td align="right">$var</td><td>$value<br /></td></tr>\n!;
				}
			print "</table>";


			last Err;
			}


		if ($sa eq 'testmail_save') {
			print " <a href=\"$const{'admin_url'}Action=SY&amp;sa=testmail\">$str[280]</a> &gt; $str[72]</b></p>";

			my %changes = (
				'Mail Server' => $FORM{'host'} || '',
				'Sendmail Program' => $FORM{'program'} || '',
				);

			$err = &save_system_settings( 1, %changes );
			next Err if ($err);


			last Err;
			}


		if ($sa eq 'testmail_send') {

			print " <a href=\"$const{'admin_url'}Action=SY&amp;sa=testmail\">$str[280]</a> &gt; $str[292]</b></p>";

			my %test = ();

			my $var;
			foreach $var ('to','from','host','program') {
				$test{$var} = $FORM{$var} || '';
				}

			$err = &fd_validate( $test{'to'}, 'email', 1, 1 );
			next Err if ($err);

			$err = &fd_validate( $test{'from'}, 'email', 1, 1 );
			next Err if ($err);


			# security check on program

			my $date_smtp = &FormatDateTime( time(), 'smtp' );

my $raw = <<"EOM";
From: <$test{'from'}>
To: <$test{'to'}>
Subject: Test email message from Genesis script
Date: $date_smtp

This is a test email message from Genesis.

The message is being sent from $test{'from'} to $test{'to'}.

The message routing parameters are:

       SMTP Host: $test{'host'}
Sendmail Program: $test{'program'}

Note that if both the sendmail program and SMTP host are defined, then the sendmail program will be used.

EOM

			my $b_prompt_save = 0;

			my $trace;
			($err, $trace) = &SendMailEx(
				%test,
				'pipeto' => $test{'program'},
				'raw' => $raw,
				);
			if ($err) {
				&ppstr(6, $err );
				}
			else {
				&ppstr( 4, $str[279] );
				$b_prompt_save = 1;
				}

			$err = '';

			$trace = &text_to_html( $trace, 1 );


			my $prompt = &pstr( 278, "$const{'admin_url'}Action=SY&amp;sa=testmail" );

print <<"EOM";

<p>$str[293]</p>

<hr size="1" />

<blockquote>$trace</blockquote>

<hr size="1" />

<p>$prompt</p>

EOM

			if ($b_prompt_save) {

				if (($system_eff{'Mail Server'} ne $test{'host'}) or ($system_eff{'Sendmail Program'} ne $test{'program'})) {

					my ($hh, $hp) = &he( $test{'host'}, $test{'program'} );

print &SetDefaults(<<"EOM", \%test);

<hr size="1" />

$const{'AdminForm'}
<input type="hidden" name="Action" value="SY" />
<input type="hidden" name="sa" value="testmail_save" />

		$str[277]

		<table border="0" cellpadding="2" cellspacing="1" class="w">
		<tr>
			<th>$str[294]</th>
			<th>$str[295]</th>
		</tr>
		<tr>
			<td class="s" align="right"><b>$str[284]:</b></td>
			<td class="s"><input type="hidden" name="host" />$hh</td>
		</tr>
		<tr>
			<td class="s" align="right"><b>$str[285]:</b></td>
			<td class="s"><input type="hidden" name="program" />$hp<br /></td>
		</tr>
		<tr>
			<td class="w"><br /></td>
			<td class="w"><input type="submit" class="submit" value="$str[72]" /></td>
		</tr>
		</table>

</form>


EOM
					}
				}
			last Err;
			}

		if ($sa eq 'testmail') {

			print " <a href=\"$const{'admin_url'}Action=SY&amp;sa=$sa\">$str[280]</a></b></p>";


			my %test = ();

			my $var;
			foreach $var ('to','from','host','program') {
				$test{$var} = $FORM{$var} || '';
				}
			$test{'to'} = $test{'to'} || $STATE{'email_address'};
			$test{'from'} = $test{'from'} || $STATE{'email_address'};
			unless (defined($FORM{'host'})) {
				$test{'host'} = $system_eff{'Mail Server'};
				}
			unless (defined($FORM{'program'})) {
				$test{'program'} = $system_eff{'Sendmail Program'};
				}

			my $options = '';
			foreach (@sendmail) {
				next if (&sendmail_valid($_));
				my $path = &he($_);
				$options .= qq!<option value="$path">$path</option>\n!;
				}

print &SetDefaults(<<"EOM", \%test);

$const{'AdminForm'}
<input type="hidden" name="Action" value="SY" />
<input type="hidden" name="sa" value="testmail_send" />

$str[296]

<table border="0" cellpadding="2" cellspacing="1" class="w">
<tr>
	<th colspan="2" align="left">$str[297]</th>
</tr>
<tr>
	<td class="s" align="right"><b>$str[298]:</b></td>
	<td class="s"><input name="to" /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[299]:</b></td>
	<td class="s"><input name="from" /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[284]:</b></td>
	<td class="s"><input name="host" /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[285]:</b></td>
	<td class="s"><select name="program"><option value="">[ None ]</option>$options</select></td>
</tr>
<tr>
	<td class="w"><br /></td>
	<td class="w"><input type="submit" class="submit" value="$str[300]" /></td>
</tr>
</table>

$str[301]

</form>

EOM

			last Err;
			}


		if ($sa eq 'SaveData') {
			print " $str[72]</b></p>";
			$err = &save_system_settings( 1, %FORM );
			next Err if ($err);


			if ($FORM{'email_address'}) {
				if ($STATE{'email_address'} ne $FORM{'email_address'}) {
					$err = &fd_validate( $FORM{'email_address'}, 'email', 1, 1 );
					next Err if ($err);

					my %GNU = (
						'email_address' => $FORM{'email_address'},
						);

					my $warnings;
					($err, $warnings) = &user_data_save( $private{'super user'}, \%GNU );
					next Err if ($err);
					print $warnings;

					&ppstr( 4, &pstr( 302, &he($FORM{'email_address'}) ) );

					}
				}

			last Err;
			}

		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}



		print " $str[66]</b></p>";

print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="SY" />
<input type="hidden" name="sa" value="SaveData" />

EOM


		my $auto_opt = &detect_sec_mode();

		print "<p><b>$str[281]</b></p>";

		print '<p>';
		&ppstr(44, &he( $], $^X, $^O, &query_env('SERVER_SOFTWARE')) );
		print qq!<br />[ <a href="$const{'admin_url'}Action=SY&amp;sa=sys_info">$str[42]</a> ]</p>\n!;


		my %defaults = %system_raw;
		$defaults{'email_address'} = $STATE{'email_address'};

		foreach (keys %defaults) {
			next unless (m! Types$!);
			$defaults{$_} = &Trim($defaults{$_});
			}

		my $str_1 = &pstr( 303, "$const{'admin_url'}Action=SY&amp;sa=testmail", "$const{'help file'}1017.html" );
		my $str_2 = &pstr( 304, $str[98], $private{'super user'} );
		my $str_3 = &pstr( 305, $str[284] );
		my $str_4 = &pstr( 315, "$const{'help file'}1097.html" );
		my $str_5 = &pstr(270, $str[316], $str[317], $auto_opt );

		my $options = '';
		foreach (@sendmail) {
			next if (&sendmail_valid($_));
			my $path = &he($_);
			$options .= qq!<option value="$path">$path</option>\n!;
			}

		my $lang_options = '';
		my $lang_path = $const{'preferences folder'} . 'templates';
		unless (opendir(DIR, $lang_path)) {
			my $h = &he($lang_path);
			$err = "unable to open languages folder '$h'";
			next Err;
			}
		foreach (sort readdir(DIR)) {
			next if (m!^\.\.?$!);
			next unless (-d "$lang_path/$_");
			my @null = ();
			$err = &loadlang( $_, \@null, 1, );
			if ($err) {
				$err = '';
				next;
				}
			my ($long, $short) = &he( $null[2], $_ );
			$lang_options .= qq!<option value="$short">$long</option>\n!;
			}
		closedir(DIR);



print &SetDefaults(<<"EOM", \%defaults );

<p><b>$str[282]</b></p>

<table border="0" cellpadding="4" cellspacing="1">
<tr>
	<th colspan="2">$str[283]</th>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[98]:</b></td>
	<td class="s"><input name="email_address" /></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[284]:</b></td>
	<td class="s"><input name="Mail Server" /></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[285]:</b></td>
	<td class="s"><select name="Sendmail Program"><option value="">[ None ]</option>$options</select></td>
	<td><br /></td>
</tr>
<tr>
	<td><br /></td>
	<td><input type="submit" class="submit" value="$str[72]" /></td>
	<td><br /></td>
</tr>
<tr>
	<td colspan="3">

		<p><br /></p>

		<p>$str_1</p>

		<p>$str_2</p>

		<p>$str_3</p>

		<p><br /></p>

	</td>
</tr>
<tr>
	<th colspan="2">$str[306]</th>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[307]:</b></td>
	<td class="s"><select name="Default Language">$lang_options</select></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[308]:</b></td>
	<td class="s"><input name="Images URL" size="55" /></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right" nowrap="nowrap"><b>$str[309]:</b></td>
	<td class="s"><input name="Min Password Length" size="4" maxlength="4" class="numeric" /> $str[310]</td>
	<td><br /></td>
</tr>
<tr>
	<td><br /></td>
	<td><input type="submit" class="submit" value="$str[72]" /></td>
	<td><br /></td>
</tr>
<tr>
	<td colspan="3">

		<p><br /></p>

		<p>$str[82]</p>

		<p><br /></p>

	</td>
</tr>
<tr>
	<th colspan="2">$str[311]</th>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right" nowrap="nowrap"><b>$str[312]:</b></td>
	<td class="s"><textarea name="CGI Types" rows="3" cols="55"></textarea></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right" nowrap="nowrap"><b>$str[313]:</b></td>
	<td class="s"><textarea name="Known Types" rows="3" cols="55"></textarea></td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" align="right" nowrap="nowrap"><b>$str[314]:</b></td>
	<td class="s"><textarea name="Media Types" rows="3" cols="55"></textarea></td>
	<td><br /></td>
</tr>
<tr>
	<td colspan="3">

		<p><br /></p>

		$str_4

		<p><br /></p>

	</td>
</tr>
<tr>
	<th colspan="2">$str[316]</th>
	<td><br /></td>
</tr>
<tr>
	<td class="s" valign="top" align="left" nowrap="nowrap"><input type="radio" name="sec_mode" value="0" /> <b>0. $str[317]</b><br /><br /></td>
	<td class="s" valign="top">$str[320]</td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" valign="top" align="left" nowrap="nowrap"><input type="radio" name="sec_mode" value="1" /> <b>1. $str[318]</b><br /><br /></td>
	<td class="s" valign="top">$str[321]</td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" valign="top" align="left" nowrap="nowrap"><input type="radio" name="sec_mode" value="2" /> <b>2. $str[319]</b></td>
	<td class="s" valign="top">

		$str[322]


		<table border="1" cellpadding="2" cellspacing="0">
		<tr>
			<td class="s" align="right">$str[323]:</td>
			<td class="s">0755</td>
		</tr>
		<tr>
			<td class="s" align="right">$str[324]:</td>
			<td class="s">0644</td>
		</tr>
		<tr>
			<td class="s" align="right">$str[325]:</td>
			<td class="s">0755</td>
		</tr>
		</table>

	</td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" valign="top" align="left" nowrap="nowrap"><input type="radio" name="sec_mode" value="3" /> <b>3. $str[328]</b></td>
	<td class="s" valign="top">

		$str[329]

		<table border="1" cellpadding="2" cellspacing="0">
		<tr>
			<td class="s" align="right">$str[323]:</td>
			<td class="s">0777</td>
		</tr>
		<tr>
			<td class="s" align="right">$str[324]:</td>
			<td class="s">0666</td>
		</tr>
		<tr>
			<td class="s" align="right">$str[325]:</td>
			<td class="s">0777</td>
		</tr>
		</table>

	</td>
	<td><br /></td>
</tr>
<tr>
	<td class="s" valign="top" align="left" nowrap="nowrap"><input type="radio" name="sec_mode" value="4" /> <b>4. $str[327]</b></td>
	<td class="s" valign="top" nowrap="nowrap">

		<p>$str[326]</p>

		<table border="1" cellpadding="2" cellspacing="0">
		<tr>
			<td class="s" align="right">$str[323]:</td>
			<td class="s"><input name="Permission - CGI Scripts" size="4" maxlength="4" /></td>
		</tr>
		<tr>
			<td class="s" align="right">$str[324]:</td>
			<td class="s"><input name="Permission - Normal Files" size="4" maxlength="4" /></td>
		</tr>
		<tr>
			<td class="s" align="right">$str[325]:</td>
			<td class="s"><input name="Permission - Folder" size="4" maxlength="4" /></td>
		</tr>
		</table>

		</td>
	<td><br /></td>
</tr>
<tr>
	<td><br /></td>
	<td><input type="submit" class="submit" value="$str[72]" /></td>
	<td><br /></td>
</tr>
<tr>
	<td colspan="3">

		<p><br /></p>

		$str_5

		<p><br /></p>

	</td>
</tr>
</table>


</form>

EOM
		last Err;
		}
	return $err;
	}





sub ui_UpdateLicense {
	my $err = '';
	Err: {

		print "<p><b><a href=\"$const{'admin_url'}Action=Main\">$str[56]</a> &gt; <a href=\"$const{'admin_url'}Action=UC\">$str[243]</a> &gt; ";

		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);

		my $sa = $FORM{'sa'} || '';

		if ($sa eq 'SaveData') {
			print "$str[72]</b></p>";

			if ($const{'mode'} == 0) {
				$err = $str[45];
				next Err;
				}

			my %changes = (
				'RegKey' => $FORM{'RegKey'},
				'mode' => $FORM{'mode'},
				);

			if (($FORM{'RegKey'}) and ('' eq $system_eff{'RegKey'})) {
				$changes{'mode'} = 2;
				}

			$err = &save_system_settings( 1, %changes );
			next Err if ($err);

			last Err;
			}
		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}



		my %defaults = (
			'mode' => $const{'mode'},
			'RegKey' => $system_eff{'RegKey'},
			);

print &SetDefaults(<<"EOM", \%defaults);

$str[66]</b></p>

$const{'AdminForm'}
<input type="hidden" name="Action" value="UC" />
<input type="hidden" name="sa" value="SaveData" />

<table border="0" cellpadding="4" cellspacing="1" bgcolor="#000000">
<tr bgcolor="#9eb3c7">
	<th align="center" colspan="2">$str[225]</th>
	<th align="center">$str[224]</th>
</tr>
<tr bgcolor="#d5d2bb" valign="top">
	<td><input type="radio" name="mode" value="3" /></td>
	<td>$str[74]</td>
	<td>$str[219]</td>
</tr>
<tr bgcolor="#d5d2bb" valign="top">
	<td><input type="radio" name="mode" value="1" /></td>
	<td>$str[206]</td>
	<td>$str[198]</td>
</tr>
<tr bgcolor="#d5d2bb" valign="top">
	<td><input type="radio" name="mode" value="2" /></td>
	<td>$str[197]</td>
	<td>$str[103]</td>
</tr>
</table>

<p>$str[90]: <textarea name="RegKey" rows="10" cols="$const{'TEXT_INPUT_SIZE'}"></textarea></p>

<p><input type="submit" class="submit" value="$str[72]" /></p>

</form>

EOM
		&pppstr(88,'http://xav.com/scripts/genesis/purchase.html','xav.com/scripts/genesis');
		print "<p>$str[87]</p>\n";
		last Err;
		}
	return $err;
	}




sub ui_ManageLog {
	my $err = '';
	Err: {

		print "<p><b><a href=\"$const{'admin_url'}Action=Main\">$str[56]</a> &gt; <a href=\"$const{'admin_url'}Action=EventLog\">$str[59]</a> &gt; ";

		$err = &priv_check( 0, 'is_admin' );
		next Err if ($err);

		if ($FORM{'Stop'}) {
			print " Stop</b></p>";
			unless (unlink($const{'event log'})) {
				$err = &pstr(13, $const{'event log'}, $! );
				next Err;
				}
			&ppstr(4, &pstr(19, $const{'event log'} ) );
			last Err;
			}
		elsif (($FORM{'CMD'}) and ($FORM{'CMD'} eq 'Start')) {
			print " Start</b></p>";
			unless (-e $const{'event log'}) {
				$err = &WriteFile( $const{'event log'}, '' );
				next Err if ($err);
				}
			&Report( &pstr(4, $str[69] ) );
			last Err;
			}
		elsif ($FORM{'CMD'}) {
			print " $str[68]</b></p>";
			$err = &WriteFile( $const{'event log'}, '' );
			next Err if ($err);
			&Report( &pstr(4, $str[67] ) );
			last Err;
			}
		else {
			print " $str[66]</b></p>";
			}

		unless (-e $const{'event log'}) {

print <<"EOM";

$const{'AdminForm'}

				<input type="hidden" name="Action" value="EventLog" />
				<input type="hidden" name="CMD" value="Start" />

				<p><input type="submit" class="submit" value="$str[65]" /></p>
				<p>$str[64]</p>

			</form>

EOM
			}
		else {

			unless (open(FILE, "<$const{'event log'}")) {
				$err = &pstr(8, $const{'event log'}, $! );
				next Err;
				}
			unless (binmode(FILE)) {
				$err = &pstr(12, $const{'event log'}, $! );
				next Err;
				}

print <<"EOM";

			<p>$str[63]</p>
			<table border="1" cellpadding="4" cellspacing="0">
			<tr>
				<th align="center" nowrap="nowrap">$str[193]</th>
				<th align="center">$str[36]</th>
				<th align="center">$str[194]</th>
				<th align="center">$str[91]</th>
			</tr>

EOM

			local $_;

			my $i = 0;
			while (defined($_ = <FILE>)) {
				my ($ip, $user, $time, $event) = split(m!\,!);
				$i++;
				my $class = ($i % 2) ? 'line1' : 'line2';
				$time = &FormatDateTime($time, 12, 0);
				$event = &he($event);
				print qq!<tr valign="top" class="$class"><td>$ip</td><td>$user</td><td nowrap="nowrap">$time</td><td>$event</td></tr>\n!;
				}
			close(FILE);

print <<"EOM";

			</table>

$const{'AdminForm'}

				<input type="hidden" name="Action" value="EventLog" />
				<input type="hidden" name="CMD" value="Clear" />

				<table border="0">
				<tr>
					<td><input type="submit" class="submit" value="$str[62]" /></td>
				</tr>
				<tr>
					<td>&nbsp; <input type="checkbox" name="Stop" /> $str[60]</td>
				</tr>
				</table>

				<p>$str[61]</p>

			</form>

EOM
			}
		last Err;
		}
	return $err;
	}

1;