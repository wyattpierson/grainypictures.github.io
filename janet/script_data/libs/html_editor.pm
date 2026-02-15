use strict;


sub ui_ListFiles {
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_html_editor');
		next Err if ($err);


		unless (opendir(DIR, '.')) {
			$err = &pstr(22, $STATE{'file_path'}, $! );
			next Err;
			}

		my $def_file = 'file.html';
		if (-e $def_file) {
			my $s1 = 0;
			while ($s1++) {
				last unless (-e "file$s1.html");
				}
			$def_file = "file$s1.html";
			}

		my ($s2) = 1;
		while ($s2++) {
			last unless (-e "folder$s2");
			}

		my %SIZE = ();
		my %DATE = ();

		my %sort_hash = ();

		my @subfolders = ();

		my ($file_size, $file_date) = (0, 0);

		foreach (readdir(DIR)) {
			next if (m!^\.\.?$!);
			next if ((m!^\.!) and (0 == $STATE{'p_hidden'}));

			($file_size, $file_date) = (0, 0);

			if (-d $_) {
				push(@subfolders, $_);
				if ($STATE{'ShowDirSize'}) {
					my $abs_path = $STATE{'file_path'} . $_;
					($err, $file_size) = &FolderSize( $abs_path, 1 );
					next Err if ($err);
					}
				}
			else {
				$file_size = -s $_;
				}

			$file_date = (stat($_))[9];

			my $key = ();
			if ($STATE{'Sort'} =~ m!s!i) { # sort by size
				$key = (10E9 + $file_size) . $_;
				}
			elsif ($STATE{'Sort'} =~ m!n!i) { # sort by name
				$key = $_;
				}
			elsif ($STATE{'Sort'} =~ m!d!i) { # sort by date
				$key = (10E9 + $file_date) . $_;
				}
			elsif (-d $_) { # sort by type (== file extension)
				$key = "-\.$_"; # folders have type "-"
				}
			elsif (m!(.*)\.(.*?)$!) {
				my $extension = lc($2);
				$key = "$extension.$_"; # files with an extension use it:
				}
			else {
				$key = "_\.$_"; # files with no extension use "_"
				}
			$sort_hash{$key} = $_;
			$SIZE{$_} = $file_size;
			$DATE{$_} = $file_date;

			}
		closedir(DIR);



print <<"EOM";

$const{'AdminForm'}

		<table border="1" cellpadding="2" cellspacing="0" style="width:100%">
		<tr>
			<th align="center" colspan="2"><a href="$const{'admin_url'}Action=SS&amp;SortType=n">$str[196]</a> . <a href="$const{'admin_url'}Action=SS&amp;SortType=t">$str[122]</a></th>
			<th align="center"><a href="$const{'admin_url'}Action=SS&amp;SortType=s">$str[123]</a></th>
			<th align="center"><a href="$const{'admin_url'}Action=SS&amp;SortType=d">$str[121]</a></th>
			<th align="center" colspan="2">$str[125]</th>
		</tr>

EOM

		if ($FORM{'CWD'}) {
			my $newdir = '';
			if ($FORM{'CWD'} =~ m!^(.*)/!) {
				$newdir = &ue($1);
				}
			print qq!<tr><td><br /></td><td><a href="$STATE{'web_path'}../">$str[126]</a></td><td><br /></td><td><br /></td><td><a href="$const{'admin_url'}Action=ListFiles&amp;set:CWD=$newdir">$str[127]</a></td><td><br /></td></tr>\n!;
			}

		my @Files = ();

		if ($STATE{'ShowFolderTop'}) {
			my (@fol, @fil) = ();
			foreach (sort keys %sort_hash) {
				if (-d $sort_hash{$_}) {
					push(@fol,$_);
					}
				else {
					push(@fil,$_);
					}
				}
			if ($STATE{'Sort'} =~ m!r!) {
				@fol = reverse @fol;
				@fil = reverse @fil;
				}
			@Files = (@fol,@fil);
			}
		else {
			@Files = sort keys %sort_hash;
			if ($STATE{'Sort'} =~ m!r!) {
				@Files = reverse @Files;
				}
			}

		my $i = 0;

		my %icon_by_extension = (
			''      => 'generic',
			'mp3'   => 'music',
			'wav'   => 'sound',
			'html'  => 'html',
			'htm'   => 'html',
			'shtml' => 'html',
			'hqx'   => 'hqx',
			'txt'   => 'text',
			'text'  => 'text',
			'zip'   => 'zip',
			'gz'    => 'zip',
			'tar'   => 'tar',
			'pl'    => 'pl',
			'pdf'   => 'pdf',
			);

		my $edit_file_count = 0;

		foreach (@Files) {

			my $FH = $sort_hash{$_};
			my ($HFH, $UFH) = (&he($FH), &ue($FH));

			my $size = &FormatNumber( $SIZE{$FH}, 0, 0, 0, 1 );
			my $last_modified = &FormatDateTime($DATE{$FH}, 12, 0);

			my $image = 'icon_image.gif';

			my $action = '<br />';
			my $delete = '<br />';

			my $URL = $STATE{ 'web_path'} . $HFH;
			$URL =~ s! !%20!g;

			if (-d $FH) {

				$URL .= '/';

				# folder:

				$image = "icon_dir.gif";

				if (-e "$FH/.is_user_dir") {
					$image = "icon_dir_secure.gif";
					}

				my $newdir = &he($FORM{'CWD'});
				$newdir .= '/' if ($FORM{'CWD'});
				$newdir .= $UFH;

				if ($STATE{'use_chdir'}) {
					$action = qq!<a href="$const{'admin_url'}Action=ListFiles&amp;set:CWD=$newdir">$str[129]</a>!;
					}

				if ($STATE{'use_he_delfolder'}) {
					$delete = qq!<a href="$const{'admin_url'}Action=Delete&amp;FH:$UFH=1">$str[147]</a>!;
					}

				}
			else {

				# file:


				my $extension = '';
				if ($FH =~ m!\.([^\.]+)$!) {
					$extension = lc($1);
					}
				if ($icon_by_extension{$extension}) {
					$image = "icon_$icon_by_extension{$extension}.gif";
					}


				if ($STATE{'use_he_delfile'}) {
					$delete = qq!<a href="$const{'admin_url'}Action=Delete&amp;FH:$UFH=1">$str[147]</a>!;
					}

				if ((-T $FH) and ($STATE{'use_he_edit'})) {

					# text-edit option:

					$action = qq!<a href="$const{'admin_url'}Action=Edit&amp;FH=$UFH">$str[128]</a>!;

					}
				}


			my $bgclass = 'line1';
			$i++;
			if ($i % 2) {
				$bgclass = 'line2';
				}

			$image = qq!<img src="$system_eff{'Images URL'}$image" hspace="5" border="0" height="22" width="20" alt="" />!;


			my $checkbox = qq!<input type="checkbox" name="FH:$HFH" value="1" />!;

			# is this file accessible according to the naming rules?

			my $file_access_err;
			my $is_cgi;
			($file_access_err, $is_cgi) = &CheckName( $FH, 1 );
			if ($file_access_err) {
				$action = '<br />';
				$delete = '<br />';
				my ($h_err) = &he($file_access_err);
				$checkbox = qq!<span title="$h_err">n/a</span>!;
				}
			else {
				$edit_file_count++;
				}

			next if (($file_access_err) and (not $STATE{'use_he_show'}));

print <<"EOM";

<tr class="$bgclass" valign="middle">
	<td align="center">$checkbox</td>
	<td width="50%" valign="middle"><a href="$URL">$image$FH</a></td>
	<td align="right"><tt>$size</tt></td>
	<td align="center" nowrap="nowrap"><tt>$last_modified</tt></td>
	<td>$action</td>
	<td>$delete</td>
</tr>

EOM

			}


		print '</table>';

		my @special = ();

		if ($STATE{'use_he_rename'}) {

			push( @special, qq!<input type="submit" class="submit" name="Action" value="Rename" />! );

			}
		if ($STATE{'use_he_copy'}) {

			push( @special, qq!<input type="submit" class="submit" name="Action" value="Copy" />! );

			}
		if (($STATE{'use_he_delfile'}) or ($STATE{'use_he_delfolder'})) {

			push( @special, qq!<input type="submit" class="submit" name="Action" value="Delete" />! );

			}

		if ((@special) and ($edit_file_count)) {

			my $buttons = join( ' - ', @special );

print <<"EOM";

		<br />

		<table border="0" cellpadding="0" cellspacing="0">
		<tr valign="top">
			<td><table border="1" cellpadding="2" cellspacing="0"><tr valign="top"><td><input type="checkbox" checked="checked" disabled="disabled" /></td></tr></table></td>
			<td>&nbsp; $str[131] =&gt; $buttons</td>
		</tr>
		</table>

EOM
			}


print <<"EOM";

</form>

<p><br /></p>

<table border="0">


EOM
print <<"EOM" if ($STATE{'use_he_mkfile'});

<tr>
	<td><img src="$system_eff{'Images URL'}icon_html.gif" hspace="8" height="22" width="20" alt="" /></td>
	<td align="right"><b>$str[132]:</b></td>
	<td>

$const{'AdminForm'}
<input type="hidden" name="Action" value="Edit" />

		<input name="FH" value="$def_file" /> <input type="submit" class="submit" value="$str[133]" />

</form>

	</td>
</tr>

EOM
print <<"EOM" if ($STATE{'use_he_mkdir'});

<tr>


	<td><img src="$system_eff{'Images URL'}icon_dir.gif" hspace="8" height="22" width="20" alt="" /></td>
	<td align="right"><b>$str[134]:</b></td>
	<td>


$const{'AdminForm'}
<input type="hidden" name="Action" value="makedir" />

		<input name="directory" value="folder$s2" /> <input type="submit" class="submit" value="$str[133]" />

</form>

	</td>
</tr>

EOM

print <<"EOM" if ($STATE{'p_upload'});

<tr>
	<td><img src="$system_eff{'Images URL'}icon_image.gif" hspace="8" height="22" width="20" alt="" /></td>
	<td align="right"><b>$str[135]:</b></td>
	<td>

	$const{'AdminFormFile'}
	<input type="hidden" name="Action" value="upload" />

		<input type="file" name="FH" /> <input type="submit" class="submit" value="$str[136]" />

	</form>

	</td>
</tr>

EOM

		print '</table>';


		if ($const{'mode'} != 3) {

			my @optional_links = ();

			if ($STATE{'p_upload'}) {
				push( @optional_links, qq!<a href="$const{'admin_url'}Action=multi-upload">$str[138]</a>! ); # multi-upload
				push( @optional_links, qq!<a href="$const{'admin_url'}Action=HI">Add Web Files</a>! ); # add web files
				}

			if ($STATE{'use_he_ri'}) {
				push( @optional_links, qq!<a href="$const{'admin_url'}Action=image-review">$str[139]</a>! ); # review images
				}

			if ($STATE{'use_he_val'}) {
				push( @optional_links, qq!<a href="$const{'admin_url'}Action=html-review">$str[140]</a>! ); # html validator
				}

			if (@optional_links) {
				print "<p><b>$str[137]</b> ";
				print join( ' - ', @optional_links );
				print "</p>\n";
				}


			}

		print '<p><br /></p>';

		last Err;
		}
	return $err;
	}





sub form_ImageReview {
	my $err = '';
	Err: {


print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	<a href="$const{'admin_url'}Action=image-review">$str[139]</a> &gt;
	$str[66]</b></p>

EOM


		$err = &priv_check(1,'use_he_ri');
		next Err if ($err);


		my $count = 0;

		my @ImageFiles = &GetFiles( $STATE{'file_path'}, "\.(jpg|jpeg|bmp|gif)\$" );
		foreach (sort @ImageFiles) {
			my ($err, $x, $y, $filesize) = &image_size( $_ );

			my $rel_path = $_;
			$rel_path =~ s!^$STATE{'file_path'}!!o;

			print '<hr size="1" />';
			if ($err) {
				&ppstr(5, $err);
				}
			else {
				my $html = &he( qq!<img src="$STATE{'web_path'}$rel_path" border="1" width="$x" height="$y" alt="" />! );
				$filesize = &FormatNumber( $filesize, 0, 0, 0, 1 );

				$count++;

print <<"EOM";

<table border="0">
<tr>
	<td align="right"><b>$str[141]:</b></td>
	<td colspan="2"><a href="$STATE{'web_path'}$rel_path/">$rel_path</a></td>
</tr>
<tr>
	<td align="right"><b>$str[123]:</b></td>
	<td align="right">$filesize</td>
	<td>bytes</td>
</tr>
<tr>
	<td align="right"><b>$str[142]:</b></td>
	<td align="right">$x<br /></td>
	<td>$str[148]</td>
</tr>
<tr>
	<td align="right"><b>$str[143]:</b></td>
	<td align="right">$y<br /></td>
	<td>$str[148]</td>
</tr>
<tr>
	<td align="right"><b>$str[144]:</b></td>
	<td colspan="2">
		<a href="$const{'admin_url'}Action=Rename&amp;FH:$rel_path=1">$str[145]</a> -
		<a href="$const{'admin_url'}Action=Copy&amp;FH:$rel_path=1">$str[146]</a> -
		<a href="$const{'admin_url'}Action=Delete&amp;FH:$rel_path=1">$str[147]</a>
	</td>
</tr>
<tr>
	<td align="right"><b>HTML:</b></td>
	<td colspan="2"><br /></td>
</tr>
</table>

<p><textarea rows="3" cols="80">$html</textarea></p>

<p><img src="$STATE{'web_path'}$rel_path" border="1" width="$x" height="$y" alt="$rel_path" /></p>

EOM
				}
			}

		unless ($count) {
			print "<p>No image files were found (searched for extensions JPG, JPEG, BMP, GIF).</p>\n";
			}

		last Err;
		}
	return $err;
	}





sub form_HTML_Review {
	my $err = '';
	Err: {


print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	<a href="$const{'admin_url'}Action=html-review">$str[140]</a> &gt;
	$str[66]</b></p>

EOM




		$err = &priv_check(1,'use_he_val');
		next Err if ($err);

		my @files = &GetFiles( $STATE{'file_path'}, "\.(html|htm|shtml|stm)\$" );

		my $count = scalar @files;

		if (0 == $count) {
			print "<p>There are no HTML files in this folder.</p>\n";
			last Err;
			}

print <<"EOM";

<table border="0" cellpadding="4" cellspacing="1" bgcolor="#000000">
<tr bgcolor="#9eb3c7">
	<th align="center">$str[141]</th>
	<th align="center">$str[123]</th>
	<th align="center">$str[125]</th>
</tr>

EOM

		foreach (sort @files) {

			my $rel_path = $_;

			my $size = &FormatNumber(-s $rel_path, 0, 0, 0, 1);
			$rel_path =~ s!^$STATE{'file_path'}!!o;

			my $url = $STATE{'web_path'} . $rel_path;
			my $urlurl = &ue($url);

print <<"EOM";

	<tr bgcolor="#d5d2bb">
		<td>$rel_path</td>
		<td align="right">$size</td>
		<td align="center"><a href="http://validator.w3.org/check?uri=$urlurl" TARGET=_blank>$str[83]</a></td>
	</tr>

EOM

			}
		print '</table>';
		last Err;
		}
	return $err;
	}






sub form_BulkUpload {
	my ($p_upload_files) = @_;
	my $err = '';
	Err: {

		my $sa = $FORM{'sa'} || '';

		my $status = ($sa eq 'save') ? $str[72] : $str[66]; # "save data" vs "overview"

print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	<a href="$const{'admin_url'}Action=multi-upload">$str[138]</a> &gt;
	$status</b></p>

EOM


		$err = &priv_check(1,'use_html_editor','p_upload');
		next Err if ($err);

		if ($sa eq 'save') {
			$err = &ui_Upload($p_upload_files);
			next Err if ($err);
			last Err;
			}
		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}

		if ($FORM{'multi_upload_count'}) {
			my %overrides = (
				'multi_upload_count' => $FORM{'multi_upload_count'},
				);
			my $warnings;
			($err, $warnings) = &user_data_save( $STATE{'Username'}, \%overrides, 1, 1 );
			next Err if ($err);
			print $warnings;
			$STATE{'multi_upload_count'} = $FORM{'multi_upload_count'};
			}
		my $field_count = $STATE{'multi_upload_count'};

		if ($STATE{'p_upload'} == 1) {
			# only Media Types allowed... warn the user...
			print "<p>You are only allowed to upload or import Media Types with the following file extensions:</p><blockquote><p>$system_eff{'Media Types'}</p></blockquote>\n";
			}


print <<"EOM";

$const{'AdminFormFile'}
<input type="hidden" name="Action" value="multi-upload" />
<input type="hidden" name="sa" value="save" />

<p><input type="submit" class="submit" value="$str[136]" /></p>

<ol>

EOM

		for (1..$field_count) {
			print qq!<li><p><input type="file" name="file$_" size="$const{'TEXT_INPUT_SIZE'}" /></p></li>\n!;
			}

		my $multi_opt = &pstr(108, '<select name="multi_upload_count">
				<option value="10">10</option>
				<option value="15">15</option>
				<option value="25">25</option>
				<option value="50">50</option>
				<option value="100">100</option>
			</select>');

print &SetDefaults(<<"EOM", \%STATE);
</ol>

<p><input type="submit" class="submit" value="$str[136]" /></p>

</form>

<hr size="1" />

$const{'AdminForm'}
<input type="hidden" name="Action" value="multi-upload" />
<p>$multi_opt <input type="submit" class="submit" value="$str[72]" /></p>
</form>


EOM
		last Err;
		}
	return $err;
	}











sub ui_Edit {
	my ($file) = @_;
	my $b_done = 1;
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_he_edit');
		next Err if ($err);

		my $is_cgi = 0;
		($err, $is_cgi) = &CheckName( $file,1 );
		next Err if ($err);

		my $sa = $FORM{'sa'} || '';



		if (not -e $file) {
			$err = &priv_check(1,'use_he_mkfile');
			next Err if ($err);
			}



		if ($sa eq 'save') {

			&Mask( $file, $is_cgi ) if (-e $file);

			my $text = $FORM{'file'};

			my $SIZE = length($text);
			$SIZE -= (-s $file) if (-e $file);
			unless (($SIZE < 0) or (&CheckFreeSpace(length($SIZE)))) {
				$err = &pstr(9, $file, $str[29] );
				next Err;
				}

			$text =~ s!\cM\n!\n!g;

			if (($STATE{'allow_cgi'}) and ($FORM{'parse_ssi'})) {
				my $shadow_file = '.ssi.' . $file;
				$err = &WriteFile( $shadow_file, $text );
				next Err if ($err);

				$text = &ParseTemplate($shadow_file, '.' );
				}

			$err = &WriteFile( $file, $text );
			next Err if ($err);

			&Mask( $file, $is_cgi );
			&Report( &pstr(4, &pstr(16, $file ) ) );

			$b_done = 0; # allow script to continue with ListFiles

			last Err;
			}
		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}





		my $readthis = $file;
		if (-e ".ssi.$file") {
			$readthis = ".ssi.$file";
			}

		my $text = '';
		if (-e $readthis) {
			($err, $text) = &ReadFile( $readthis );
			next Err if ($err);
			&pppstr(157, "$STATE{'web_path'}$file", $file );
			}
		else {
			($err, $text) = &ReadFile( "$const{'preferences folder'}sample_sites/default_html_page.txt" );
			next Err if ($err);
			print "<p>$str[156]<p>\n";
			}

		my $wrap_tag = $STATE{'TextWrap'} ? 'virtual' : 'off';

		my %defaults = (
			'FH' => $file,
			'file' => $text,
			'parse_ssi' => ($file eq $readthis) ? 0 : 1,
			);

		my $ssi_option = '';
		if ($STATE{'allow_cgi'}) {
			$ssi_option = qq!<p><input type="checkbox" name="parse_ssi" value="1" /> $str[158]</p>!;
			}

print &SetDefaults(<<"EOM", \%defaults);

$const{'AdminForm'}
<input type="hidden" name="Action" value="Edit" />
<input type="hidden" name="sa" value="save" />

<p><textarea name="file" wrap="$wrap_tag" rows="$STATE{'Rows'}" cols="$STATE{'Cols'}" style="font-size:$STATE{'FontSize'}pt"></textarea></p>

<table border="0">
<tr>
	<td valign="middle"><input name="FH" /></td>
	<td valign="middle"><input type="submit" class="submit" value="$str[72]" /></td>
</tr>
</table>

$ssi_option

</form>

<p>$str[159]</p>

EOM

		if ($STATE{'use_my_account_page'}) {
			&pppstr(160, "$const{'admin_url'}Action=PR#text-edit" );
			}
		last Err;
		}
	return ($err, $b_done);
	}









sub create_folder {
	my ($file) = @_;
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_he_mkdir');
		next Err if ($err);

		my $is_cgi = 0;
		($err, $is_cgi) = &CheckName( $file,1 );
		next Err if ($err);

		unless (mkdir($file,0777)) {
			$err = &pstr(21, $file, $! );
			next Err;
			}
		&Mask( $file, 0 );

		&Report( &pstr(4, &pstr(24, $file ) ) );
		last Err;
		}
	return $err;
	}



sub ui_Rename {
	my $err = '';
	Err: {

print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	$str[252]</b></p>

EOM

		$err = &priv_check(1,'use_he_rename');
		next Err if ($err);

		my @Files = ();
		my $is_cgi;

		my ($name, $value) = ();
		while (($name, $value) = each %FORM) {
			next unless ($name =~ m!^FH\:(.*)$!);
			push(@Files, $1);
			}

		unless (@Files) {
			$err = $str[264];
			next Err;
			}

		my $rel_file;
		foreach $rel_file (@Files) {
			($err, $is_cgi) = &CheckName( $rel_file, 1 );
			next Err if ($err);
			unless (-e $rel_file) {
				my $h_file = &he($rel_file);
				$err = "file '$h_file' does not exist";
				next Err;
				}
			}



		if ($FORM{'Confirmed'}) {

			foreach (reverse sort @Files) {

				my $old_file = $_;
				my $new_file = $FORM{"FH:$_"};

				($err, $is_cgi) = &CheckName( $new_file, 1 );
				if ($err) {
					&ppstr(6,$err);
					$err = '';
					next;
					}

				my $old_abs_file = "$STATE{'file_path'}$old_file";
				my $new_abs_file = "$STATE{'file_path'}$new_file";

				unless (rename($old_abs_file, $new_abs_file)) {
					$err = &pstr(14,$old_file,$new_file,$!);
					&ppstr(6,$err);
					$err = '';
					next;
					}
				&ppstr(4, &pstr(20,$old_file,$new_file) );
				}
			}
		else {


print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="Rename" />
<input type="hidden" name="Confirmed" value="1" />

<table border="1" cellpadding="4" cellspacing="0">
<tr>
	<th align="center">$str[253]</th>
	<th align="center">$str[254]</th>
</tr>

EOM

		foreach $rel_file (sort @Files) {

			my $h_file = &he($rel_file);

print <<"EOM";

<tr>
	<td>$h_file</td>
	<td><input name="FH:$h_file" /></td>
</tr>

EOM
		}



print <<"EOM";

</table>

	<p><input type="submit" class="submit" value="$str[252]" /></p>

</form>


EOM
			}
		last Err;
		}
	return $err;
	}





sub ui_Copy {
	my $err = '';
	Err: {


print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;	$str[255]</b></p>

EOM


		$err = &priv_check(1,'use_he_copy');
		next Err if ($err);

		my @Files = ();
		my $is_cgi;

		my ($name, $value) = ();
		while (($name, $value) = each %FORM) {
			next unless ($name =~ m!^FH\:(.*)$!);
			push(@Files, $1);
			}

		unless (@Files) {
			$err = $str[264];
			next Err;
			}


		my $rel_file;
		foreach $rel_file (@Files) {
			($err, $is_cgi) = &CheckName( $rel_file, 1 );
			next Err if ($err);
			unless (-e $rel_file) {
				my $h_file = &he($rel_file);
				$err = "file '$h_file' does not exist";
				next Err;
				}
			}


		if ($FORM{'Confirmed'}) {

			foreach (reverse sort @Files) {

				Err: {

					my $old_file = $_;
					my $new_file = $FORM{"FH:$_"};

					($err, $is_cgi) = &CheckName( $new_file, 1 );
					next Err if ($err);

					my $old_abs_file = "$STATE{'file_path'}$old_file";
					my $new_abs_file = "$STATE{'file_path'}$new_file";

					my $contents;
					($err, $contents) = &ReadFile( $old_abs_file );
					next Err if ($err);

					($err) = &WriteFile( $new_abs_file, $contents );
					next Err if ($err);

					&Mask( $new_abs_file, $is_cgi );

					&ppstr(4, &pstr(16, $new_file ) );

					last Err;
					}
				continue {
					&ppstr(6,$err);
					$err = '';
					}
				}

			}
		else {




print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="Copy" />
<input type="hidden" name="Confirmed" value="1" />

<table border="1">
<tr>
	<th align="center">$str[253]</th>
	<th align="center">$str[254]</th>
</tr>

EOM

		foreach $rel_file (sort @Files) {


			my $h_file = &he($rel_file);

			my $abs_file = "$STATE{'file_path'}$rel_file";
			if (-d $abs_file) {

print <<"EOM";

<tr>
	<td>$h_file</td>
	<td>$str[256]</td>
</tr>

EOM

			}
		else {

print <<"EOM";

<tr>
	<td>$h_file</td>
	<td><input name="FH:$h_file" /></td>
</tr>

EOM

			}
		}



print <<"EOM";

</table>

	<p><input type="submit" class="submit" value="$str[255]" /></p>
	</form>


EOM

			}
		last Err;
		}
	return $err;
	}





sub ui_Delete {
	my $err = '';
	Err: {



print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	$str[259]</b></p>

EOM



		$err = &priv_check(1,'use_html_editor');
		next Err if ($err);




		my ($base_dir) = @_;
		my $qm_base_dir = quotemeta("$base_dir/");

		my @Files = ();

		my ($name, $value) = ();
		while (($name, $value) = each %FORM) {
			next unless ($name =~ m!^FH\:(.*)$!);
			next unless ($value);
			my $relfile = $1;
			next if ($relfile =~ m!\.\.!);
			push(@Files, $relfile);
			}

		unless (@Files) {
			$err = $str[264];
			next Err;
			}


		if ($FORM{'Confirmed'}) {
			foreach (reverse sort @Files) {
				my $relfile = $_;
				my $abs_file = &clean_path("$base_dir/$_");
				unless ($abs_file =~ m!^$qm_base_dir!i) {
					&ppstr(6, &pstr(257,$abs_file,$base_dir));
					next;
					}
				unless ($abs_file =~ m!/([^/]+)$!) {
					&ppstr(6,&pstr(258,$abs_file));
					next;
					}
				my $basename = $1;
				my $file_err = (&CheckName($basename,1))[0];
				if ($file_err) {
					&ppstr(6, $file_err);
					next;
					}

				if (-d $abs_file) {
					$err = &priv_check(1,'use_he_delfolder');
					next Err if ($err);
					&Mask( $abs_file, 0 );
					if (rmdir($abs_file)) {
						&ppstr(4, &pstr(25, $relfile ) );
						}
					else {
						&ppstr(6, &pstr(23, $relfile, $! ) );
						}
					}
				else {
					$err = &priv_check(1,'use_he_delfile');
					next Err if ($err);
					&Mask( $abs_file, 0 );
					if (unlink($abs_file)) {
						&ppstr(4, &pstr(19, $relfile ) );
						}
					else {
						&ppstr(6, &pstr(13, $relfile, $! ) );
						}
					}
				}
			}
		else {

print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="Delete" />
<input type="hidden" name="Confirmed" value="1" />

EOM

	my $relfile;
	foreach $relfile (sort @Files) {
		my $file = "$base_dir/$relfile";

		my $file_err_msg = '';
		FileErr: {
			my $abs_file = &clean_path($file);
			unless ($abs_file =~ m!^$qm_base_dir!i) {
				$file_err_msg = &pstr(257,$abs_file,$base_dir);
				next FileErr;
				}
			unless ($abs_file =~ m!/([^/]+)$!) {
				$file_err_msg = &pstr(258,$abs_file);
				next FileErr;
				}
			my $basename = $1;
			my $file_err = (&CheckName($basename,1))[0];
			if ($file_err) {
				$file_err_msg = $file_err;
				next FileErr;
				}
			if (($basename eq '.is_user_dir') and ($STATE{'p_hidden'} < 2)) {
				$file_err_msg = $str[261];
				next FileErr;
				}
			$file_err_msg = &priv_check(1,'use_he_delfile');
			next FileErr if ($file_err_msg);
			print qq!<p><input type="checkbox" name="FH:$relfile" checked="checked" value="1" /> $relfile</p>\n!;
			last FileErr;
			}
		continue {
			print qq!<p><input type="checkbox" name="foo" value="1" disabled="disabled" /> $relfile - $str[260] - $file_err_msg.</p>\n!;
			}
		if (-d $file) {
			$err = &priv_check(1,'use_he_delfolder');
			next Err if ($err);
			&ui_Delete_FolderContents( $file, $relfile );
			}
		}

print <<"EOM";

	<p><input type="submit" class="submit" value="$str[147]" /></p>
	</form>

EOM
			}
		last Err;
		}
	return $err;
	}





sub ui_Delete_FolderContents {
	my $err = '';
	Err: {

		$err = &priv_check(1,'use_html_editor');
		next Err if ($err);


		my ($abs_path, $rel_path) = @_;
		my $qm_base_dir = quotemeta("$abs_path/");
		my $base_dir = $abs_path;
		if (opendir(DIR, $abs_path)) {
			my @items = readdir(DIR);
			closedir(DIR);

			print '<ul>';

			foreach (@items) {
				next if (m!^\.\.?$!);
				my $relfile = "$rel_path/$_";
				my $sub_abs_path = "$abs_path/$_";


				my $file_err_msg = '';
				FileErr: {
					my $abs_file = &clean_path($sub_abs_path);
					unless ($abs_file =~ m!^$qm_base_dir!i) {
						$file_err_msg = &pstr(257,$abs_file,$base_dir);
						next FileErr;
						}
					unless ($abs_file =~ m!/([^/]+)$!) {
						$file_err_msg = &pstr(258,$abs_file);
						next FileErr;
						}
					my $basename = $1;
					my $file_err = (&CheckName($basename,1))[0];
					if ($file_err) {
						$file_err_msg = $file_err;
						next FileErr;
						}
					if (($basename eq '.is_user_dir') and ($STATE{'p_hidden'} < 2)) {
						$file_err_msg = $str[261];
						next FileErr;
						}
					print qq!<p><input type="checkbox" name="FH:$relfile" checked="checked" value="1" /> $relfile</p>\n!;
					last FileErr;
					}
				continue {
					print qq!<p><input type="checkbox" name="foo" value="1" disabled="disabled" /> $relfile - $str[260] - $file_err_msg.</p>\n!;
					}
				if (-d $sub_abs_path) {
					&ui_Delete_FolderContents( $sub_abs_path, $relfile );
					}

				}

			print '</ul>';
			}
		last Err;
		}
	return $err;
	}



sub SwitchSort {
	my $err = '';
	Err: {
		my %SortTypes = (
			'n'  => $str[196],
			'nr' => "$str[196] - $str[124]",
			's'  => $str[123],
			'sr' => "$str[123] - $str[124]",
			'd'  => $str[121],
			'dr' => "$str[121] - $str[124]",
			't'  => $str[122],
			'tr' => "$str[122] - $str[124]",
			);

		if ($STATE{'Sort'} eq $FORM{'SortType'}) {
			# okay, reverse the sorting
			if ($FORM{'SortType'} =~ m!r!) {
				$STATE{'Sort'} =~ s!r!!o;
				}
			else {
				$STATE{'Sort'} .= 'r';
				}
			}
		else {
			$STATE{'Sort'} = $FORM{'SortType'};
			}

		my %overrides = (
			'Sort' => $STATE{'Sort'},
			);

		my $warn_msg = '';
		($err, $warn_msg) = &user_data_save( $STATE{'Username'}, \%overrides, 1, 1 );
		next Err if ($err);

		&Report(&pstr(4,&pstr(221,$SortTypes{$STATE{'Sort'}})));
		last Err;
		}
	return $err;
	}




sub image_size {
	my ($file) = @_;
	if ($file =~ m!\.(jpeg|jpg)$!i) {
		return &jpegsize( $file );
		}
	elsif ($file =~ m!\.gif$!i) {
		return &gifsize( $file );
		}
	elsif ($file =~ m!\.bmp$!i) {
		return &bmpsize( $file );
		}
	else {
		return ($str[201], -1, -1, -1);
		}
	}





sub bmpsize {
	my ($file) = @_;

	my ($x, $y, $filesize) = (-1, -1, -1);

	my $buffer = '';

	my $err = '';
	Err: {

		unless (-e $file) {
			$err = "file '$file' does not exist";
			next Err;
			}

		$filesize = -s $file;

		unless (open(FILE, "<$file")) {
			$err = "unable to read from file '$file' - $!";
			next Err;
			}
		unless (binmode(FILE)) {
			$err = "unable to set binmode on file '$file' - $!";
			next Err;
			}

		my $buffer = '';
		read(FILE, $buffer, 26);
		($x, $y) = unpack("x18VV", $buffer);

		last Err;
		}
	return ($err, $x, $y, $filesize);
	}





sub gifsize {
	my ($file) = @_;

	my ($x, $y, $filesize) = (-1, -1, -1);

	my $buffer = '';

	my $err = '';
	Err: {

		unless (-e $file) {
			$err = "file '$file' does not exist";
			next Err;
			}

		$filesize = -s $file;

		unless (open(FILE, "<$file")) {
			$err = "unable to read from file '$file' - $!";
			next Err;
			}
		unless (binmode(FILE)) {
			$err = "unable to set binmode on file '$file' - $!";
			next Err;
			}

		my ($cmapsize, $buf, $h, $w, $type);

		my $gif_blockskip = sub {
			my ($skip, $type) = @_;
			my ($lbuf);

			my $buffer = '';
			read(FILE, $buffer, $skip);
			while (1) {
				if (eof(FILE)) {
					$err = "Invalid/Corrupted GIF (at EOF in GIF $type)";
					next Err;
					}
				read(FILE, $lbuf, 1);
				last if ord($lbuf) == 0;     # Block terminator
				read(FILE, $buffer, ord($lbuf));
				}
			};

		read(FILE, $type, 6);



		if (read(FILE, $buf, 7) != 7 ) {
			$err = "Invalid/Corrupted GIF (bad header)";
			next Err;
			}
		($x) = unpack("x4 C", $buf);
		if ($x & 0x80) {
			$cmapsize = 3 * (2**(($x & 0x07) + 1));
			unless ($cmapsize == read(FILE, $buffer, $cmapsize)) {
				$err = "Invalid/Corrupted GIF (global color map too small?)";
				next Err;
				}
			}


		FINDIMAGE: while (1) {

			if (eof(FILE)) {
				$err = "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)";
				next Err;
				}

			read(FILE, $buf, 1);
			($x) = unpack("C", $buf);

			if ($x == 0x2c) {
				# Image Descriptor (GIF87a, GIF89a 20.c.i)
				if (read(FILE, $buf, 8) != 8) {
					$err = "Invalid/Corrupted GIF (missing image header?)";
					next Err;
					}
				($x, $w, $y, $h) = unpack("x4 C4", $buf);
				$x += $w * 256;
				$y += $h * 256;
				last Err;
				}

			if ($x == 0x21) {
				# Extension Introducer (GIF89a 23.c.i, could also be in GIF87a)
				read(FILE, $buf, 1);
				($x) = unpack("C", $buf);
				if ($x == 0xF9) {
					# Graphic Control Extension (GIF89a 23.c.ii)
					read(FILE, $buffer, 6);
					next FINDIMAGE;
					}
				elsif ($x == 0xFE) {
					# Comment Extension (GIF89a 24.c.ii)
					&$gif_blockskip(0, "Comment");
					next FINDIMAGE;
					}
				elsif ($x == 0x01) {
					# Plain Text Label (GIF89a 25.c.ii)
					&$gif_blockskip(13, "text data");
					next FINDIMAGE;
					}
				elsif ($x == 0xFF) {
					# Application Extension Label (GIF89a 26.c.ii)
					&$gif_blockskip(12, "application data");
					next FINDIMAGE;
					}
				else {
					$err = "Invalid/Corrupted GIF (Unknown extension $x)";
					next Err;
					}
				}
			else {
				$err = sprintf("Invalid/Corrupted GIF (Unknown code %#x)", $x);
				}
			}
		last Err;
		}
	return ($err, $x, $y, $filesize);
	}




sub jpegsize {
	my ($file) = @_;

	my ($x, $y, $filesize) = (-1, -1, -1);

	my $err = '';
	Err: {

		unless (-e $file) {
			$err = "file '$file' does not exist";
			next Err;
			}

		$filesize = -s $file;

		unless (open(FILE, "<$file")) {
			$err = "unable to read from file '$file' - $!";
			next Err;
			}
		unless (binmode(FILE)) {
			$err = "unable to set binmode on file '$file' - $!";
			next Err;
			}


		my $MARKER = "\xFF";       # Section marker.

		my $SIZE_FIRST  = 0xC0;         # Range of segment identifier codes
		my $SIZE_LAST   = 0xC3;         #  that hold size info.

		my ($marker, $code, $length);
		my $segheader;

		# Dummy read to skip header ID

		my $buffer = '';
		read(FILE, $buffer, 2);

		while (1) {
			$length = 4;
			read(FILE, $buffer, $length);

			# Extract the segment header.
			($marker, $code, $length) = unpack("a a n", $buffer);

			# Verify that it's a valid segment.
			if ($marker ne $MARKER) {
				# Was it there?
				$err = "JPEG marker not found";
				next Err;
				}
			elsif ((ord($code) >= $SIZE_FIRST) && (ord($code) <= $SIZE_LAST)) {
				# Segments that contain size info
				$length = 5;

				read(FILE, $buffer, $length);

				($y, $x) = unpack("xnn", $buffer);
				last;
				}
			else {
				# Dummy read to skip over data
				read(FILE, $buffer, $length - 2);
				}
			}
		last Err;
		}
	return ($err, $x, $y, $filesize);
	}



1;