use strict;

=item desc

Interface for "My Account", "Create User", "Edit User Profile"

=cut

sub ui_MyFolderConfig {
	my $err = '';
	Err: {
		local $_;


		$err = &priv_check( 0, 'use_my_account_page' );
		next Err if ($err);


		my $sa = $FORM{'sa'} || '';
		if ($sa eq 'save') {

			$err = &priv_check( 0, 'allow_folder_change' );
			next Err if ($err);

			print qq!<p><b><a href="$const{'admin_url'}Action=PR">$str[222]</a> &gt; <a href="$const{'admin_url'}Action=MFC">$str[70]</a> &gt; $str[72]</b></p>\n!;

			my ($orig_folder, $orig_url) = ($STATE{'Author:UserFolder'}, $STATE{'Author:UserURL'});
			my ($new_folder, $new_url) = ($FORM{'Author:UserFolder'}, $FORM{'Author:UserURL'});

			my $var;
			foreach $var ('Author:UserFolder','Author:UserURL','ShowMFCTip') {
				$STATE{$var} = $FORM{$var};
				}


			my $warn_msg;
			($err, $warn_msg) = &user_data_save( $STATE{'Username'}, \%STATE, 1 );
			next Err if ($err);
			print $warn_msg if ($warn_msg);

			&Report( &pstr(4, $str[71] ) );


			$err = &prompt_shadow_change(
				$orig_folder,
				$orig_url,
				$new_folder,
				$new_url,
				);
			next Err if ($err);

			last Err;
			}

		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}


		my %TMP = ();


		my $warnings;
		($err, $warnings) = &LoadUserPrefs( $STATE{'Username'}, \%TMP );
		next Err if ($err);

print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="MFC" />
<input type="hidden" name="sa" value="save" />

<p><b><a href="$const{'admin_url'}Action=PR">$str[222]</a> &gt; <a href="$const{'admin_url'}Action=MFC">$str[70]</a> &gt; $str[66]</b></p>

<blockquote>

EOM

		&ui_configure_authoring(\%TMP);

print <<"EOM";

</blockquote>
</form>

EOM

		last Err;
		}
	return $err;
	}



sub save_shadow_change();
sub save_shadow_change() {
	my $err = '';
	Err: {

		my %overrides = (
			'Author:UserFolder' => $FORM{'Author:UserFolder'},
			'Author:UserURL' => $FORM{'Author:UserURL'},
			);

		my $warn_msg;
		($err, $warn_msg) = &user_data_save( '_default', \%overrides, 0 );
		next Err if ($err);

		print $warn_msg if ($warn_msg);

		&ppstr( 4, $str[234] );

		};
	return $err;
	};


sub prompt_shadow_change($$$$);
sub prompt_shadow_change($$$$) {
	my @params = @_;
	my $err = '';
	Err: {

		# force trailing slash:

		local $_;
		foreach (@params) {
			next if (m!/$!);
			$_ .= '/';
			}

		my ($orig_folder, $orig_url, $new_folder, $new_url) = @params;

		my %default_user = ();

		my $warnings;
		($err, $warnings) = &LoadUserPrefs( '_default', \%default_user );
		next Err if ($err);

		last Err if ($const{'mode'} == 3); # not applicable to Freeware mode

		last Err if (($orig_folder eq $new_folder) and ($orig_url eq $new_url));

		last Err if (($default_user{'Author:UserFolder'} ne "$orig_folder%username%/") or ($default_user{'Author:UserURL'} ne "$orig_url%username%/"));

		# the webmaster is changing his home folder/url settings and the originals exactly match those of the _default user
		# ask whether he should change the default user settings too

		my ($hnf, $hnu) = &he( "$new_folder%username%/", "$new_url%username%/" );

		my $str1 = &pstr( 361, '_default' );
		my $str2 = &pstr( 362, $str[226], $str[228], $private{'super user'}, '_default' );

print <<"EOM";

<hr size="1" />

$const{'AdminForm'}
<input type="hidden" name="Action" value="SSC" />
<input type="hidden" name="Author:UserFolder" value="$hnf" />
<input type="hidden" name="Author:UserURL" value="$hnu" />

<p>$str1</p>

<table border="0" cellpadding="4" cellspacing="1" class="w">
<tr>
	<th colspan="2" align="left">$str[364]</th>
</tr>
<tr>
	<td class="s" align="right"><b>$str[226]:</b></td>
	<td class="s">$default_user{'Author:UserFolder'}<br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[228]:</b></td>
	<td class="s">$default_user{'Author:UserURL'}<br /></td>
</tr>
</table>

$str2

<table border="0" cellpadding="4" cellspacing="1" class="w">
<tr>
	<th colspan="2" align="left">$str[365]</th>
</tr>
<tr>
	<td class="s" align="right"><b>$str[226]:</b></td>
	<td class="s">$hnf<br /></td>
</tr>
<tr>
	<td class="s" align="right"><b>$str[228]:</b></td>
	<td class="s">$hnu<br /></td>
</tr>
</table>

<p><input type="submit" class="submit" value="$str[72]" /></p>

</form>


EOM

		&pppstr( 363, '_default', $str[56], $str[57] );


		last Err;
		}
	return $err;
	};


sub ShowSettings {
	my ($username, $is_self, $is_new_user) = @_;

	my $err = '';
	Err: {

		$err = &priv_check(0,'use_my_account_page');
		next Err if ($err);


		local $_;

		my %TMP = ();
		if ($is_new_user) {
			my $warnings;
			($err, $warnings) = &LoadUserPrefs( '_default', \%TMP );
			next Err if ($err);
			$TMP{'full_name'} = '';
			$TMP{'email_address'} = '';
			$TMP{'Username'} = '';
			}
		else {
			my $warnings;
			($err, $warnings) = &LoadUserPrefs( $username, \%TMP );
			next Err if ($err);
			}

		my $misc_options = '';
		my %BooleanPrefs = (
			'ShowDirSize' => $str[86],
			'ShowTips' => $str[85],
			'DiskUse' => $str[84],
			'show_chdir' => $str[43],
			);
		foreach (keys %BooleanPrefs) {
			my $alt = $_ . '_udav';
			my $id = $_ . '_1';
			$misc_options .= qq!<tr><td><input type="hidden" name="$alt" value="0" /><input type="checkbox" name="$_" value="1" id="$id" /></td><td><label for="$id">$BooleanPrefs{$_}</label></td></tr>\n!;
			}

		my $sort_options = '';
		my %SortTypes = (
			'n' => $str[196],
			'nr' => "$str[196] - $str[124]",
			's' => $str[123],
			'sr' => "$str[123] - $str[124]",
			'd' => $str[121],
			'dr' => "$str[121] - $str[124]",
			't' => $str[122],
			'tr' => "$str[122] - $str[124]",
			);
		foreach (sort keys %SortTypes) {
			$sort_options .= qq!<option value="$_">$SortTypes{$_}</option>\n!;
			}

		my $d1 = &FormatDateTime( $TMP{'AccountCreated'}, 12, 0 );

		if ($TMP{'AccountCreated'}) {
			$d1 .= " (" . &get_age_str( time() - $TMP{'AccountCreated'} ) . ")";
			}

		my $d2 = $str[195]; # never
		$d2 = &FormatDateTime( $TMP{'LastLogin'}, 12, 0 ) if ($TMP{'LastLogin'});

		if ($TMP{'LastLogin'}) {
			$d2 .= " (" . &get_age_str( time() - $TMP{'LastLogin'} ) . ")";
			}



print <<"EOM";

$const{'AdminForm'}

EOM

		# Modify Other People's Settings:
		if (not $is_self) {

			if ($username) {


				if ($username eq '_default') {


					my $startf = $const{'preferences folder'} . "sample_sites/start_site";

					my $list = '';
					unless (opendir(DIR, $startf)) {
						$err = &pstr( 22, &he( $startf, $! ) );
						next Err;
						}
					foreach (sort &he(readdir(DIR))) {
						next if (m!^\.\.?$!);
						$list .= qq!\t\t<li><p>$_</p></li>\n!;
						}
					closedir(DIR);

					&ppstr( 366, '_default' );

					my $str1 = &pstr(368, 'start_site', $startf );

print &SetDefaults(<<"EOM", \%TMP);

<p><b>$str[367]</b></p>

<blockquote>

	$str1

	<ul>
$list
	</ul>

	<p><br /></p>

</blockquote>

EOM

					}


print &SetDefaults(<<"EOM", \%TMP );

<input type="hidden" name="Action" value="UA" />
<input type="hidden" name="sa" value="SP" />
<input type="hidden" name="UN" value="$TMP{'Username'}" />
<input type="hidden" name="Username" value="$TMP{'Username'}" />

EOM

				}
			elsif ($is_new_user) {

print &SetDefaults(<<"EOM", \%TMP);

<input type="hidden" name="Action" value="UA" />
<input type="hidden" name="sa" value="CU" />

EOM

				}
			}

		else {
			# Modify your own settings:

print <<"EOM";

<input type="hidden" name="Action" value="save_prefs" />
<input type="hidden" name="Username" value="$TMP{'Username'}" />
<input type="hidden" name="UN" value="$TMP{'Username'}" />

EOM

			}



		if ($username ne '_default') {

			my $username_text = $is_new_user ? qq!<input name="Username" />! : $TMP{'Username'};

print &SetDefaults(<<"EOM", \%TMP);

			<p><b>$str[96]</b></p>

			<blockquote>

				<table border="0">
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[36]:</b></td>
					<td>$username_text</td>
				</tr>
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[98]:</b></td>
					<td><input name="email_address" size="$const{'TEXT_INPUT_SIZE'}" /></td>
				</tr>
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[97]:</b></td>
					<td><input name="full_name" size="$const{'TEXT_INPUT_SIZE'}" /></td>
				</tr>
				</table>

				<p><input type="submit" class="submit" value="$str[72]" /></p>

				<p><br /></p>

			</blockquote>


			<p><b>$str[99]</b></p>

			<blockquote>

				<table border="0">
EOM

# Everyone needs to know their old password when resetting, even webmaster:

print <<"EOM" if ((not $STATE{'is_admin'}) or ($TMP{'is_admin'}));
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[100]:</b></td>
					<td><input type="password" name="OldPass" size="8" /></td>
				</tr>
EOM


print <<"EOM";
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[101]:</b></td>
					<td><input type="password" name="NewPass" size="8" maxlength="8" /></td>
				</tr>
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[102]:</b></td>
					<td><input type="password" name="NewPass2" size="8" maxlength="8" /></td>
				</tr>
				</table>

				<p><input type="submit" class="submit" value="$str[72]" /></p>

EOM
				print qq!<p>$str[223]</p>! if ($is_new_user);
print <<"EOM";


				<p><br /></p>

			</blockquote>

EOM


			} # end if not _default

		# customize authoring privileges

		print "<p><b>$str[70]</b></p>\n";
		print '<blockquote>';
		&ui_configure_authoring(\%TMP);
		print '</blockquote>';

		if (not $STATE{'is_admin'}) {

			# read-only privileges:

			my ($priv, $expiration);
			($err, $priv, $expiration) = &create_privileges_ui( 0, \%TMP );
			next Err if ($err);


print <<"EOM";

	<p><b>$str[383]</b></p>

	<blockquote>

		$expiration

		<p><br /></p>

	</blockquote>

	<p><b>$str[89]</b></p>

	<p>$str[360]</p>

	<blockquote>

		$priv

EOM


			}

		else {

			# read-write privileges

			my ($expiration, $priv);
			($err, $priv, $expiration) = &create_privileges_ui( 1, \%TMP );
			next Err if ($err);

			my $privileges = '';

			if ($TMP{'is_admin'}) {

				$privileges .= qq!<input type="hidden" name="account_status" value="0" />\n!;
				$privileges .= qq!<input type="hidden" name="account_expires_days" />\n!;

				}
			else {

$privileges .= qq^

		<p><b>$str[383]</b></p>

		<blockquote>

			$expiration

			<p><input type="submit" class="submit" value="$str[72]" /></p>

			<p><br /></p>

		</blockquote>

^;
				}

$privileges .= qq^

		<p><b>$str[89]</b></p>

		$str[369]

		<input type="hidden" name="update_privilege_list" value="1" />

		<blockquote>

			<table border="0" cellpadding="4" cellspacing="1" width="100%">
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			<tr>
				<td><input type="radio" name="priv_scheme" value="4" id="priv_scheme_4" /></td>
				<td><p><b><label for="priv_scheme_4">4. $str[377]</label></b></p></td>
			</tr>
			<tr>
				<td><br /></td>
				<td>
					<p>
						$str[376]<br />
						$str[379]
					</p>
					<p>^ . &pstr(73,'4_Quota') . qq^</p>
				</td>
			</tr>
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			<tr>
				<td><input type="radio" name="priv_scheme" value="3" id="priv_scheme_3" /></td>
				<td><p><b><label for="priv_scheme_3">3. $str[378]</label></b></p></td>
			</tr>
			<tr>
				<td><br /></td>
				<td>
					<p>
						$str[375]<br />
						$str[379]
					</p>
					<p>^ . &pstr(73,'3_Quota') . qq^</p>
				</td>
			</tr>
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			<tr>
				<td><input type="radio" name="priv_scheme" value="2" id="priv_scheme_2" /></td>
				<td><p><b><label for="priv_scheme_2">2. $str[289]</label></b></p></td>
			</tr>
			<tr>
				<td><br /></td>
				<td>
					<p>
						$str[375]<br />
						$str[380]
					</p>
					<p>^ . &pstr(73,'2_Quota') . qq^</p>
				</td>
			</tr>
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			<tr>
				<td><input type="radio" name="priv_scheme" value="1" id="priv_scheme_1" /></td>
				<td><p><b><label for="priv_scheme_1">1. $str[287]</label></b></p></td>
			</tr>
			<tr>
				<td><br /></td>
				<td>
					<p>
						$str[375]<br />
						$str[276]<br />
						$str[374]
					</p>
					<p>^ . &pstr(73,'1_Quota') . qq^</p>
				</td>
			</tr>
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			<tr>
				<td><input type="radio" name="priv_scheme" value="0" id="priv_scheme_0" /></td>
				<td><p><b><label for="priv_scheme_0">$str[373]</label></b></p></td>
			</tr>
			<tr>
				<td><br /></td>
				<td>

					$priv

				</td>
			</tr>
			<tr>
				<td colspan="2"><hr size="1" /></td>
			</tr>
			</table>

^;

				for (0..4) {
					$TMP{ $_ . '_Quota' } = $TMP{'Quota'};
					}

				if ($TMP{'use_templates'}) {
					foreach (split(m!\,!, $TMP{'use_templates'})) {
						$TMP{ 'use_templates_' . $_ } = 1;
						}
					}
				print &SetDefaults( $privileges, \%TMP);
				print qq!<p><input type="submit" class="submit" value="$str[72]" /></p>\n!;
				}



			my $shell_opt = '';
			$shell_opt .= qq!<br /><input type="radio" name="shell" value="1" id="shell_1" /> <label for="shell_1">$str[52]</label>\n! if ($TMP{'use_template_editor'});
			$shell_opt .= qq!<br /><input type="radio" name="shell" value="2" id="shell_2" /> <label for="shell_2">$str[53]</label>\n! if ($TMP{'use_html_editor'});

			my $locallang = $str[2];

			my $multi_opt = &pstr(108, '<select name="multi_upload_count">
					<option value="10">10</option>
					<option value="15">15</option>
					<option value="25">25</option>
					<option value="50">50</option>
					<option value="100">100</option>
				</select>');


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
				$lang_options .= qq!<option value="$short">$long ($short)</option>\n!;
				}
			closedir(DIR);




print &SetDefaults(<<"EOM", \%TMP);

			<p><br /></p>

		</blockquote>

		<p><b>$str[105]</b></p>

		<blockquote>

			<p>$str[106]</p>
			<blockquote>
				<p><input type="radio" name="shell" value="0" id="shell_0" /> <label for="shell_0">$str[56]</label>
				$shell_opt
				</p>
			</blockquote>

			<p>$str[107] <select name="language">$lang_options</select></p>

			<p>$multi_opt</p>

			<p>$str[109] <select name="Sort">$sort_options</select><br />

			<input type="hidden" name="ShowFolderTop_udav" value="0" />
			<input type="checkbox" name="ShowFolderTop" value="1" id="ShowFolderTop_1" /> <label for="ShowFolderTop_1">$str[110]</label></p>

			<table border="0">
				$misc_options
			</table>

			<p><input type="submit" class="submit" value="$str[72]" /></p>

			<p><br /></p>

		</blockquote>

		<a name="text-edit"></a>

		<p><b>$str[111]</b></p>

		<blockquote>

			<p>$str[112]</p>

			<table border="0">
			<tr>
				<td colspan="2" align="right">$str[113]:</td>
				<td><input name="FontSize" size="3" class="numeric" /> pt</td>
			</tr>
			<tr>
				<td colspan="2" align="right">$str[114]:</td>
				<td><input name="Rows" size="3" class="numeric" /></td>
			</tr>
			<tr>
				<td colspan="2" align="right">$str[115]:</td>
				<td><input name="Cols" size="3" class="numeric" /></td>
			</tr>
			</table>

			<p><br /></p>

			<table border="0">
			<tr>
				<td><input type="hidden" name="TextUpload_udav" value="0" /><input type="checkbox" name="TextUpload" value="1" id="TextUpload_1" /></td>
				<td colspan="2"><label for="TextUpload_1">$str[116]</label></td>
			</tr>
			<tr>
				<td><input type="hidden" name="TextWrap_udav" value="0" /><input type="checkbox" name="TextWrap" value="1" id="TextWrap_1" /></td>
				<td colspan="2"><label for="TextWrap_1">$str[117]</label></td>
			</tr>
			</table>

			<p><input type="submit" class="submit" value="$str[72]" /></p>

			<p><br /></p>

		</blockquote>

</form>

EOM

print <<"EOM" if (($username ne '_default') and (not $is_new_user));

		<hr size="1" />


		<table border="0">
		<tr>
			<td align="right"><b>$str[118]:</b></td>
			<td>$d1</td>
		</tr>
		<tr>
			<td align="right"><b>$str[119]:</b></td>
			<td>$d2</td>
		</tr>
		<tr>
			<td align="right"><b>$str[120]:</b></td>
			<td>$TMP{'LastLoginFrom'}</td>
		</tr>
		</table>


EOM

		last Err;
		}
	return $err;
	}





sub ui_configure_authoring {
	my ($p_TMP) = @_;

print <<"EOM";

				<table border="0">

EOM


	if (($STATE{'is_admin'}) and ($STATE{'allow_folder_change'}) and ($$p_TMP{'allow_folder_change'})) {

		my $URL = &he($$p_TMP{'Author:UserURL:parsed'});


print <<"EOM" if ($$p_TMP{'Author:UserURL:parsed'} !~ m!(_default|%username%)/?$!);

				<tr>
					<td><br /></td>
					<td>&lt;<a href="$URL" target="_blank">$URL</a>&gt;</td>
				</tr>

EOM

		print &SetDefaults(<<"EOM", $p_TMP);

				<tr>
					<td align="right" nowrap="nowrap"><b>$str[226]:</b></td>
					<td><input name="Author:UserFolder" size="$const{'TEXT_INPUT_SIZE'}" /></td>
				</tr>
				<tr>
					<td align="right" nowrap="nowrap"><b>$str[228]:</b></td>
					<td><input name="Author:UserURL" size="$const{'TEXT_INPUT_SIZE'}" /></td>
				</tr>
				</table>

				<input type="hidden" name="configure_authoring" value="1" />



EOM
print &SetDefaults(<<"EOM", $p_TMP) if ($$p_TMP{'is_admin'});

				<table border="0">
				<tr>
					<td><input type="hidden" name="ShowMFCTip_udav" value="0" /><input type="checkbox" name="ShowMFCTip" value="1" id="ShowMFCTip_1" /></td>
					<td><label for="ShowMFCTip_1">$str[93]</label></td>
				</tr>
				</table>
EOM

				my $str1 = &pstr( 372, '%username%', $str[226] );

print <<"EOM";

				<p><input type="submit" class="submit" value="$str[72]" /></p>

				$str1

				<blockquote>
					<p><tt>$private{'path_to_script'}</tt></p>
				</blockquote>

				<p><br /></p>

EOM
			}
		else {
			# display account for when we don't have the "folder change" ability

			if ($$p_TMP{'Author:UserURL:parsed'} =~ m!(_default|%username%)$!) {

print <<"EOM";

	<tr>
		<td align="right"><b>$str[228]:</b></td>
		<td>$$p_TMP{'Author:UserURL:parsed'}</a></td>
	</tr>

EOM


				}
			else {

print <<"EOM";

	<tr>
		<td align="right"><b>$str[228]:</b></td>
		<td><a href="$$p_TMP{'Author:UserURL:parsed'}">$$p_TMP{'Author:UserURL:parsed'}</a></td>
	</tr>

EOM

				}

print <<"EOM";

				</table>

				<p>$str[104]</p>

				<p><br /></p>

EOM
		}
	}

sub create_privileges_ui {
	my ( $b_read_write, $p_user ) = @_;
	my $expiration = '';
	my $text = '';
	my $err = '';
	Err: {
		my $badx = '<b><small><font color="#cc0000">x</font></small></b>';
		my $good = '<b><small><font color="#008800">!!</font></small></b>';


		if ($b_read_write) {

			my $str1 = &pstr( 386, '</label><input name="account_expires_days" size="4" class="numeric" />' );

$expiration .= <<"EOM";

		<table border="2" cellpadding="4" cellspacing="1" width="80%">
		<tr>
			<td align="center" width="5%">$good</td>
			<td align="center" width="5%"><input type="radio" name="account_status" value="0" id="account_status_0" /></td>
			<td><label for="account_status_0">$str[384]</label></td>
		</tr>
		<tr>
			<td valign="middle" align="center">$badx</td>
			<td valign="middle" align="center"><input type="radio" name="account_status" value="1" id="account_status_1" /></td>
			<td valign="middle"><label for="account_status_1">$str1</td>
		</tr>
		<tr>
			<td align="center">$badx</td>
			<td align="center"><input type="radio" name="account_status" value="2" id="account_status_2" /></td>
			<td><label for="account_status_2">$str[385]</label></td>
		</tr>
		</table>

EOM
			}
		else {

			my @vals = ('-', '-', '-');
			$vals[$$p_user{'account_status'}] = '<b>x</b>';

			my $str1 = &pstr( 386, $$p_user{'account_expires_days'} );


$expiration .= <<"EOM";

		<table border="2" cellpadding="4" cellspacing="1" width="80%">
		<tr>
			<td align="center" width="5%">$vals[0]</td>
			<td>$str[384]</td>
		</tr>
		<tr>
			<td align="center">$vals[1]</td>
			<td>$str1</td>
		</tr>
		</table>

EOM
			}

		if (($$p_user{'Username'} ne '_default') and (not $$p_user{'is_admin'})) {
			my $days_ago = int( (time() - $$p_user{'AccountCreated'}) / 86400 );
			my $var = substr( &FormatDateTime( $$p_user{'AccountCreated'}, 12, 0 ), 0, 10 );
			$expiration .= '<p>' . &pstr(387, $var, $days_ago ) . '</p>';
			}



		# the following code will create a table of all template subfolders if
		# this is going to be a read-write interface:

		my $template_subfolders = '';
		if ($b_read_write) {

			$const{'template_subfolders'} = '';
			$const{'template_i'} = 1;

			my $p_start = sub {
				return '';
				};

			my $p_stop = sub {
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
					last Err unless ($true);

					# if this is a folder entry, print the name:

					last unless (-d $path);

					my $name = $true;
					$name =~ tr!_! !;
					$name =~ s!(^|/)T\d*\.!$1!g;
					$name =~ s!/! / !g;
					$name = &he($name);


					my $value = &ue($true);

$const{'template_subfolders'} .= <<"EOM";

						<tr>
							<td colspan="2"><br /></td>
							<td width="5%"><input type="checkbox" name="use_templates_$value" value="1" id="use_templates_$const{'template_i'}" /></td>
							<td><label for="use_templates_$const{'template_i'}">$name</label></td>
						</tr>

EOM

					$const{'template_i'}++;
					last Err;

					}
				return $err;
				};

			$err = &recurse( $const{'preferences folder'}, 'sample_sites', 0, $p_start, $p_entry, $p_stop );
			next Err if ($err);

			$template_subfolders = $const{'template_subfolders'};
			delete $const{'template_subfolders'};

			unless ($template_subfolders) {

				my $str = &pstr(371, "$const{'preferences folder'}sample_sites");

$template_subfolders .= <<"EOM";

						<tr>
							<td colspan="2"><br /></td>
							<td colspan="2">$str</td>
						</tr>

EOM

				}
			}


		my $title = &pstr( 345, $str[222] );
		$title = &pstr( 344, $title ) if ($b_read_write);

$text .= <<"EOM";

						<p><b>$title</b></p>

						<table border="2" cellpadding="4" cellspacing="1" width="80%">
						<tr>
							<td align="center" width="5%">$good</td>
							<td align="center" width="5%"><input type="radio" name="use_my_account_page" value="1" id="use_my_account_page_1" /></td>
							<td><label for="use_my_account_page_1">$str[340]</label></td>
						</tr>
						<tr>
							<td align="center">$badx</td>
							<td align="center"><input type="radio" name="use_my_account_page" value="0" id="use_my_account_page_0" /></td>
							<td><label for="use_my_account_page_0">$str[339]</label></td>
						</tr>
						</table>

EOM

		my $partial_label = $str[47];
		$partial_label = $str[341] if ($b_read_write);

		$title = &pstr( 345, $str[52] );
		$title = &pstr( 344, $title ) if ($b_read_write);

$text .= <<"EOM";

						<p><br /></p>

						<p><b>$title</b></p>

						<table border="2" cellpadding="4" cellspacing="1" width="80%">
						<tr>
							<td width="5%" align="center">$good</td>
							<td width="5%" align="center"><input type="radio" name="use_template_editor" value="1" id="use_template_editor_1" /></td>
							<td colspan="2"><label for="use_template_editor_1">$str[343]</label></td>
						</tr>
						<tr>
							<td align="center">$badx</td>
							<td align="center" width="5%"><input type="radio" name="use_template_editor" value="0" id="use_template_editor_0" /></td>
							<td colspan="2"><label for="use_template_editor_0">$str[342]</label></td>
						</tr>
						<tr>
							<td width="5%" align="center">$good</td>
							<td align="center" width="5%"><input type="radio" name="use_template_editor" value="2" id="use_template_editor_2" /></td>
							<td colspan="2"><label for="use_template_editor_2">$partial_label</label></td>
						</tr>
						$template_subfolders
						</table>

EOM

	$title = &pstr( 345, $str[53] );
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>


					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td width="5%" align="center">$good</td>
						<td align="center" width="5%"><input type="radio" name="use_html_editor" value="1" id="use_html_editor_1" /></td>
						<td colspan="2"><label for="use_html_editor_1">$str[340]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center" width="5%"><input type="radio" name="use_html_editor" value="0" id="use_html_editor_0" /></td>
						<td colspan="2"><label for="use_html_editor_0">$str[339]</label></td>
					</tr>
					<tr>
						<td width="5%" align="center">$good</td>
						<td align="center" width="5%"><input type="radio" name="use_html_editor" value="2" id="use_html_editor_2" /></td>
						<td colspan="2"><label for="use_html_editor_2">$str[338]</label></td>
					</tr>

					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_mkdir" value="1" id="use_he_mkdir_1" /><input type="hidden" name="use_he_mkdir_udav" value="0" /></td>
						<td><label for="use_he_mkdir_1">$str[134]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_mkfile" value="1" id="use_he_mkfile_1" /><input type="hidden" name="use_he_mkfile_udav" value="0" /></td>
						<td><label for="use_he_mkfile_1">$str[132]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_edit" value="1" id="use_he_edit_1" /><input type="hidden" name="use_he_edit_udav" value="0" /></td>
						<td><label for="use_he_edit_1">$str[337]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_delfile" value="1" id="use_he_delfile_1" /><input type="hidden" name="use_he_delfile_udav" value="0" /></td>
						<td><label for="use_he_delfile_1">$str[331]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_delfolder" value="1" id="use_he_delfolder_1" /><input type="hidden" name="use_he_delfolder_udav" value="0" /></td>
						<td><label for="use_he_delfolder_1">$str[332]</label></td>
					</tr>


					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_rename" value="1" id="use_he_rename_1" /><input type="hidden" name="use_he_rename_udav" value="0" /></td>
						<td><label for="use_he_rename_1">$str[333]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_copy" value="1" id="use_he_copy_1" /><input type="hidden" name="use_he_copy_udav" value="0" /></td>
						<td><label for="use_he_copy_1">$str[334]</label></td>
					</tr>

					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_ri" value="1" id="use_he_ri_1" /><input type="hidden" name="use_he_ri_udav" value="0" /></td>
						<td><label for="use_he_ri_1">$str[139]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="checkbox" name="use_he_val" value="1" id="use_he_val_1" /><input type="hidden" name="use_he_val_udav" value="0" /></td>
						<td><label for="use_he_val_1">$str[140]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="radio" name="use_he_show" value="1" id="use_he_show_1" /></td>
						<td><label for="use_he_show_1">$str[335]</label></td>
					</tr>
					<tr>
						<td colspan="2"><br /></td>
						<td align="center" width="5%"><input type="radio" name="use_he_show" value="0" id="use_he_show_0" /></td>
						<td><label for="use_he_show_0">$str[336]</label></td>
					</tr>
					</table>

EOM

	$title = $str[346];
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>

					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td width="5%" align="center">$good</td>
						<td width="5%" align="center"><input type="radio" name="use_chdir" value="1" id="use_chdir_1" /></td>
						<td><label for="use_chdir_1">$str[347]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center"><input type="radio" name="use_chdir" value="0" id="use_chdir_0" /></td>
						<td><label for="use_chdir_0">$str[348]</label></td>
					</tr>
					</table>

EOM

	$text .= $str[349] if ($b_read_write);

	my $quota;
	if ($b_read_write) {
		$quota = &pstr( 73, 'Quota' );
		}
	else {
		$quota = &pstr(46, $$p_user{'Quota'} );
		}

	$title = $str[350];
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>

					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td width="5%" align="center">$good</td>
						<td width="5%" align="center"><input type="radio" name="allow_no_quota" value="1" id="allow_no_quota_1" /></td>
						<td><label for="allow_no_quota_1">$str[351]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center"><input type="radio" name="allow_no_quota" value="0" id="allow_no_quota_0" /></td>
						<td>$quota</td>
					</tr>
					</table>

EOM

	$title = $str[352];
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>

					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td width="5%" align="center">$good</td>
						<td width="5%" align="center"><input type="radio" name="allow_cgi" value="1" id="allow_cgi_1" /></td>
						<td><label for="allow_cgi_1">$str[353]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center"><input type="radio" name="allow_cgi" value="0" id="allow_cgi_0" /></td>
						<td><label for="allow_cgi_0">$str[354]</label></td>
					</tr>
					</table>
EOM


	if ($b_read_write) {
		$text .= &pstr( 370, $str[312], $system_eff{'CGI Types'}, "$const{'admin_url'}Action=SY", $str[240] );
		}

	$title = $str[355];
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>

					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td width="5%" align="center">$good</td>
						<td width="5%" align="center"><input type="radio" name="p_upload" value="2" id="p_upload_2" /></td>
						<td><label for="p_upload_2">$str[356]</label></td>
					</tr>
					<tr>
						<td align="center">$good</td>
						<td align="center"><input type="radio" name="p_upload" value="1" id="p_upload_1" /></td>
						<td><label for="p_upload_1">$str[357]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center"><input type="radio" name="p_upload" value="0" id="p_upload_0" /></td>
						<td><label for="p_upload_0">$str[358]</label></td>
					</tr>
					</table>

EOM

	if ($b_read_write) {
		$text .= &pstr( 370, $str[314], $system_eff{'Media Types'}, "$const{'admin_url'}Action=SY", $str[240] );
		}

	$title = $str[275];
	$title = &pstr( 344, $title ) if ($b_read_write);

	$text .= <<"EOM";

					<p><br /></p>

					<p><b>$title</b></p>

					<table border="2" cellpadding="4" cellspacing="1" width="80%">
					<tr>
						<td align="center" width="5%">$good</td>
						<td align="center" width="5%"><input type="radio" name="p_hidden" value="2" id="p_hidden_2" /></td>
						<td><label for="p_hidden_2">$str[273]</label></td>
					</tr>
					<tr>
						<td align="center">$good</td>
						<td align="center"><input type="radio" name="p_hidden" value="1" id="p_hidden_1" /></td>
						<td><label for="p_hidden_1">$str[272]</label></td>
					</tr>
					<tr>
						<td align="center">$badx</td>
						<td align="center"><input type="radio" name="p_hidden" value="0" id="p_hidden_0" /></td>
						<td><label for="p_hidden_0">$str[271]</label></td>
					</tr>
					</table>

EOM

		$text .= '<p>' . $str[274] . '</p>' if ($b_read_write);


		if (not $b_read_write) {

			my $pattern;

			$pattern = '<td([^\>\<]+)>' . quotemeta($badx) . '</td>';
			$text =~ s!$pattern!!sg;

			$pattern = '<td([^\>\<]+)>' . quotemeta($good) . '</td>';
			$text =~ s!$pattern!!sg;

			$text =~ s!<td colspan="2"><br /></td>!<td colspan="1"><br /></td>!sg;

			$text =~ s!<label([^\>\<]+)>!!sg;
			$text =~ s!</label>!!sg;

			my $var;
			foreach $var (keys %$p_user) {
				next unless ((defined($$p_user{$var})) and ($$p_user{$var} =~ m!^\d$!));
				my @replace = qw!- - - - - - - -!;
				$replace[$$p_user{$var}] = '<b>x</b>';
				$text =~ s!<input ([^\>\<]+) id=\"$var\_(\d)\"([^\>\<]+)>!$replace[$2]!sg;
				}

			}
		last Err;
		}
	return ($err, $text, $expiration);
	};



1;