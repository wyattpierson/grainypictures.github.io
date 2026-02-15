#!/usr/bin/perl --
require 5;
use strict;

=head1 copyright

Genesis Web Authoring System

Copyright 1997-2002 by Zoltan Milosevic.  Please adhere to the copyright
notice and conditions of use, described in the attached help file and hosted
at the URL below.  For the latest version and help files, visit:

	http://xav.com/scripts/genesis/

This search engine is managed from the web; the default username/password
is webmaster/658uwantit:

	http://my.host.com/genesis/index.pl

<h1>If you can see this text from a web browser, then there is a problem. <a
href="http://xav.com/scripts/genesis/help/1089.html">Get help here.</a></h1><xmp>

=cut

use vars qw! %FORM $VERSION %user_schema @sendmail %system_eff %system_raw $auth %const %private @str %STATE @file_sec $fd_lang %dir_size $warnings !;

BEGIN {

	$VERSION = '2.1.0.0022';

	# html-encode function; used everywhere
	sub he {
		my @out = @_;
		local $_;
		foreach (@out) {
			$_ = '' if (not defined($_));
			s!\&!\&amp;!g;
			s!\>!\&gt;!g;
			s!\<!\&lt;!g;
			s!\"!\&quot;!g;
			}
		if ((wantarray) or ($#out > 0)) {
			return @out;
			}
		else {
			return $out[0];
			}
		}

	$SIG{'__WARN__'} = sub {
		my ($warn) = @_;
		$warnings .= $warn;
		};

	# error trap
	$SIG{'__DIE__'} = sub {
		my ($err) = &he(@_);
		$| = 1;
		print "Content-Type: text/html\015\012\015\012";
		open(STDERR, ">&STDOUT");
		my %Error = (
			'Perl Error' => $_[0],
			'product' => 'genesis',
			'mailto' => 'zoltanm@xav.com',
			'version' => $VERSION,
			'perlver' => $],
			'perlops' => $^O,
			'Script Path' => $0,
			);

		my %data = (
			'Error' => \%Error,
			'env' => \%ENV,
			'form' => \%FORM,
			);
		my $hidden = '';
		foreach (sort keys %data) {
			my %hash = &he(%{$data{$_}});
			my ($name, $value);
			while (($name, $value) = each %hash) {
				$hidden .= qq!<input type="hidden" name="$_: $name" value="$value" />\n!;
				}
			}


print <<"EOM";

<hr size="1" />

<p><b>Perl Execution Error</b> in $0:</p>
<blockquote><pre> $err </pre></blockquote>

<form method="post" action="http://xav.com/bug.pl">
<p>Please report this error to the script author:</p>
<blockquote>
	<input type="submit" value="Report Error" />
</blockquote>
$hidden
</form><hr size="1" />

EOM

		print '<pre>' . &he($warnings) . '</pre>';
		$warnings = '';
		};
	}

END {
	if ($warnings) {
		print '<tt style="color:#cccccc;font-size:xx-small">' . &he($warnings) . '</tt>';
		$warnings = '';
		}
	}


# Enter the full web-path and file-path to the folder holding this script.
# If you leave these blank, the script will auto-detect them, which should
# work in most cases.  In cases where it does not work, you will have to
# enter accurate values here:

my $web_path_to_script = '';
my $file_path_to_script = '';

# examples:
#
# my $web_path_to_script = 'http://www.xav.com/scripts/genesis/genesis/index.cgi';
# my $file_path_to_script = '/usr/www/users/xav/scripts/genesis/genesis/index.cgi';

@sendmail = (
	'/bin/sendmail -t',
	'/usr/bin/sendmail -t',
	'/usr/lib/sendmail -t',
	'/usr/sbin/sendmail -t',
	'/usr/sendmail -t',
	);



# format is:
#	key => [ type, min, max, human-name, system-default-value, security_type ],
#
#	security_type:
#		0 => controlled by the system (lastlogin, etc);
#		1 => edited by admin (author:userfolder);
#		2 => edited by user (full_name, email)
#		3 => admin/hybrid.  Either set by the admin, or if undef(), then set to system default



my $DEFAULT_LANGUAGE = 'english';
%user_schema = (

	# user-defined settings

	'shell' => [ 'int', 0, 2, 'user default shell', 0, 2 ],
	'full_name' => [ 'string', 0, undef(), 'full name', '', 2 ],
	'email_address' => [ 'email', 1, undef(), '', 'nobody@localhost', 2 ],
	'FontSize' => [ 'int', 8, 24, 'font size', 10, 2 ],
	'Rows' => [ 'int', 4, 60, 'textarea rows', 10, 2 ],
	'Cols' => [ 'int', 40, 100, 'textarea columns', 60, 2 ],
	'multi_upload_count' => [ 'int', 5, 1000, 'multi-file upload count', 20, 2 ],

	'DiskUse' => [ 'bool', 1, undef(), 'show disk usage', 0, 2 ],
	'ShowTips' => [ 'bool', 1, undef(), 'show tips', 1, 2 ],
	'show_chdir' => [ 'bool', undef(), 0, 'Show "Current Folder" in header', 1, 2 ],
	'ShowDirSize' => [ 'bool', 1, undef(), 'show folder sizes', 0, 2 ],
	'Sort' => [ 'string', 1, 2, 'sort order', 'n', 2 ],

	'language' => [ 'string', 1, undef(), 'language', $DEFAULT_LANGUAGE, 2 ],
	'TextWrap' => [ 'bool', 1, undef(), 'wrap text', 1, 2 ],
	'TextUpload' => [ 'bool', 1, undef(), 'upload text files in ASCII mode', 1, 2 ],
	'ShowFolderTop' => [ 'bool', 1, undef(), 'ShowFolderTop', 1, 2 ],

	# administrator-controlled values:

	'Quota' => [ 'int', 0, undef(), 'disk quota', 10000, 1 ],
	'Author:UserFolder' => [ 'folder', 1, 0, 'user home folder', '', 1 ],
	'Author:UserFolder:parsed' => [ 'folder', 1, 0, 'user home folder', '', 1 ],
	'Author:UserURL' => [ 'http_url', 1, 0, 'user URL', '', 1 ],
	'Author:UserURL:parsed' => [ 'http_url', 1, 0, 'user URL', '', 1 ],

	'priv_scheme' => [ 'int', 0, 4, 'privilege scheme', 0, 1 ], # privilege scheme, plat/gold/silver/bronze/custom 4/3/2/1/0
	'p_upload' => [ 'int', 0, 2, 'upload privilege', 2, 1 ],
	'p_hidden' => [ 'int', 0, 2, 'hidden file privlege', 0, 1 ],

	'allow_cgi' => [ 'bool', undef(), 0, 'Allow CGI', 0, 1 ],
	'allow_no_quota' => [ 'bool', undef(), 0, 'Allow No Quota', 0, 1 ],
	'use_my_account_page' => [ 'bool', undef(), 0, 'Access My Account page', 1, 1 ],

	'use_template_editor' => [ 'int', 0, 2, 'Use Template Editor', 1, 1 ],
		'use_templates' => [ 'string', 0, undef(), 'Template Groups', '', 1 ],

	'use_html_editor' => [ 'int', 0, 2, 'Use HTML Editor', 1, 1 ],
		'use_he_delfile' => [ 'bool', undef(), 0, 'Delete File', 1, 1 ],
		'use_he_delfolder' => [ 'bool', undef(), 0, 'Delete Folder', 1, 1 ],
		'use_he_edit' => [ 'bool', undef(), 0, 'Edit File', 1, 1 ],
		'use_he_mkdir' => [ 'bool', undef(), 0, 'Create Folder', 1, 1 ],
		'use_he_mkfile' => [ 'bool', undef(), 0, 'Create File', 1, 1 ],
		'use_he_ri' => [ 'bool', undef(), 0, 'Use Image Review', 1, 1 ],
		'use_he_val' => [ 'bool', undef(), 0, 'Use HTML Validator', 1, 1 ],
		'use_he_show' => [ 'bool', undef(), 0, 'Display All Files', 1, 1 ],
		'use_he_copy' => [ 'bool', undef(), 0, 'Copy Files and Folders', 1, 1 ],
		'use_he_rename' => [ 'bool', undef(), 0, 'Rename Files and Folders', 1, 1 ],

	'use_chdir' => [ 'bool', undef(), 0, 'Use chdir', 1, 1 ],

	'account_status' => [ 'int', 0, 2, 'Account Status', 0, 1 ],
		# 0 => active, never expires
		# 1 => active, expires {account_expires_days} days after AccountCreated
		# 2 => temporarily disabled

	# the %days% variable will be available within template.html if we are using an account that will expire

	'account_expires_days' => [ 'int', 0, undef(), 'Account Expires', 30, 1 ],
		# number of days after AccountCreated that the account will expire
		# active only if account_status==1


	# system keys for managing auto-creation of user accounts
	#	we allow undef() for reverse compatibility

	'ShowMFCTip' => [ 'bool', 1, undef(), 'show Manage Folder link', 1, 3 ],
	'WaitAdminApprove'      => [ 'bool',   1, 1, 'WaitAdminApprove', 0, 3 ],

	# miscellaneous system-managed values:
	'is_admin' => [ 'bool', undef(), 0, 'is_admin', 0, 0 ],
	'allow_folder_change' => [ 'bool', undef(), 0, 'Allow Folder Change', 1, 0 ],
	'_BUILD' => [ 'int', 0, 9999, 'software build number', 0, 0 ],
	'_VERSION' => [ 'string', 10, 11, 'software version number', $VERSION, 0 ],
	'Username' => [ 'string', 1, undef(), 'username', '', 0 ],
	'LastLogin' => [ 'int', 0, undef(), 'last login time', 0, 0 ],
	'LastLoginFrom' => [ 'hostname', 0, 0, 'last login hostname', '', 0 ],
	'AccountCreated' => [ 'int', 1, undef(), 'account created time', 0, 0 ],


	);

%const = ( 'footer_text' => '' );
$str[6] = '<p><b>Error:</b> $s1.</p>';


my $err = '';
Err: {

	%dir_size = ();

	local $_;

	# fix up environment variables for running under -T
	$ENV{'PATH'} = &query_env('PATH');
	foreach ('IFS','CDPATH','ENV','BASH_ENV') {
		delete $ENV{$_} if (defined($ENV{$_}));
		}

	$fd_lang = bless({});

	my $script_name = &query_env('SCRIPT_NAME');

	my @paths;
	($err, @paths) = &where_tf();
	next Err if ($err);

	unless (chdir($paths[1])) {
		$err = "unable to chdir to '$paths[1]' - $!";
		next Err;
		}

	%const = (
		'version' => $VERSION,
		'help file' => 'http://xav.com/scripts/genesis/help/',
		'full_script_url' => $paths[3],
		'script_url' => $script_name,
		'admin_url' => "$script_name?",
		'http' => "$paths[4]/web_pages/",
		'TEXT_INPUT_SIZE' => 63,
		'product' => 'Genesis Web Authoring System',
		'AdminForm' => qq!<form method="post" action="$script_name" style="margin-bottom:0">!,
		'AdminFormFile' => qq!<form method="post" action="$script_name" style="margin-bottom:0" enctype="multipart/form-data">!,
		'path' => "$paths[1]/web_pages/",
		'preferences folder' => "$paths[1]/script_data/",
		'footer_text' => '',
		);
	$const{'event log'} = $const{'preferences folder'} . 'event.log';

	%private = (
		'REMOTE_ADDR' => &query_env('REMOTE_ADDR'),
		'super user' => 'webmaster',
		'path_to_script' => $paths[0],
		);

	@INC = ( $const{'preferences folder'} . 'libs', @INC );

	my %lib_options = (
		'user_defined.pm' => 1,
		'html_editor' => 0,
		'manage_users' => 0,
		'my_account' => 0,
		'network.pm' => 0,
		'system_settings' => 0,
		'template_editor' => 0,
		);

	foreach (keys %lib_options) {
		delete $INC{$_};
		require $_ if ($lib_options{$_});
		}

	$err = &loadlang($DEFAULT_LANGUAGE,\@str);
	next Err if ($err);
	$const{'language'} = $DEFAULT_LANGUAGE;

	%system_eff = %system_raw = (

		'/Users/Add/sign-up-url' => '%admin_url%Action=AnonCreate',

		'/Users/Add/automatic' => 0,
		'/Users/Add/admin-approve' => 1,

		# for reverse compatibility
		'Base Folder'               => $const{'path'},
		'Base URL'                  => $const{'http'},

		'Images URL'                => 'http://xav.com/i/',
		'Mail Server'               => '',
		'Sendmail Program'          => '',

		'sec_mode' => 0,
		'Permission - Folder'       => '0777',
		'Permission - Normal Files' => '0666',
		'Permission - CGI Scripts'  => '0777',

		'Min Password Length'       => 4,

		'CGI Types'                 => 'pl cgi exe asp sh bat cmd idq stm shtml shtm php php3',
		'Known Types'               => 'jpg gif wav mid midi au ra mp3 css js txt html htm zip tar hqx null tmp template is_user_dir',
		'Media Types'               => 'jpg gif wav mid midi au ra mp3',

		'RegKey'                    => '',
		'mode'                      => 1,
		'Default Language'          => $DEFAULT_LANGUAGE,
		);


	$const{'code_validate'} = sub {
		my $p_decode = sub {
			local $_;
			my $code = defined($_[0]) ? $_[0] : '';
			my %map = ();
			my $i = 0;
			foreach (48..57,65..90,97..122) {
				$map{chr($_)} = $i % 16;
				$i++;
				}
			$code =~ s!\s|\r|\n|\015|\012!!sg;
			my $text = '';
			my $frag = '';
			$i = 0;
			while ($frag = substr($code, $i, 2)) {
				$i += 2;
				my $chn = 16 * $map{substr($frag,0,1)};
				$chn += $map{substr($frag,1,1)};
				my $ch = chr($chn);
				$text .= $ch;
				}
			$text = unpack('u',$text);
			return $text;
			};
		local $_;
		my $code = defined($_[0]) ? $_[0] : '';
		return 0 unless ($code);
		my $is_valid = 0;
		$code =~ s!BEGIN LICENSE!!sg;
		$code =~ s!END LICENSE!!sg;
		if ($code =~ m!^\s*(.*)\s*\-\s*(.*?)\s*$!s) {
			my ($pub, $pri) = ($1,$2);
			$pri = &$p_decode($pri);
			$pub =~ s!(\s|\r|\n)!!sg;
			$pri =~ s!(\s|\r|\n)!!sg;
			if ($pub eq $pri) {

				$is_valid = 1;
				}
			}
		return $is_valid;
		};



	my $usr_load_warnings = '';
	my $sys_load_warnings = '';

	($err, $sys_load_warnings) = &system_settings_load( "$const{'preferences folder'}security.txt", \%system_eff, \%system_raw );
	next Err if ($err);

	if ($DEFAULT_LANGUAGE ne $system_eff{'Default Language'}) {
		my $test = [];
		$err = &loadlang( $system_eff{'Default Language'}, $test );
		if ($err) {
			$sys_load_warnings .= ".</p><p><b>Error:</b> " if ($sys_load_warnings);
			$sys_load_warnings .= $err;
			$err = '';
			}
		else {
			$const{'language'} = $system_eff{'Default Language'};
			@str = @$test;
			}
		}

	$err = &file_security_init( $system_eff{'sec_mode'} );
	next Err if ($err);


	$const{'mode'} = $system_eff{'mode'};

	if (-e "$const{'preferences folder'}is_demo") {
		$const{'mode'} = 0;
		}
	elsif (($const{'mode'} == 2) and (not ($system_eff{'RegKey'}))) {
		$const{'mode'} = 1;
		}



	unless (-e "$const{'preferences folder'}temp") {
		$err = &pstr(269,"$const{'preferences folder'}temp");
		next Err;
		}


	$err = &standard_binmode();
	next Err if ($err);

	%FORM = ();
	my %upload_files = ();
	$err = &WebForm( \%FORM, \%upload_files, "$const{'preferences folder'}temp", 0 );
	next Err if ($err);

	# Initialize certain form fields:
	$FORM{'CWD'} = '' if not defined($FORM{'CWD'});


	$auth = &web_auth_new(
		'make_starter_accounts' => 1,
		'data_folder' => "$const{'preferences folder'}accounts/",
		);
	my ($is_auth, $private_token, $auth_username, $is_cookies_aware, $html_out) = $auth->Challenge( \%FORM );
	unless ($is_cookies_aware) {
		$const{'admin_url'} .= "web_auth_cp=$private_token&";
		$const{'AdminForm'} .= qq!\n<input type="hidden" name="web_auth_cp" value="$private_token" />!;
		$const{'AdminFormFile'} .= qq!\n<input type="hidden" name="web_auth_cp" value="$private_token" />!;
		}


	# Okay, user is authenticated, input is parsed, it's time to do some editing...

	my $action = $FORM{'Action'} || '';

	if ($action eq 'LogOut') {
		$html_out = $auth->logout();
		$is_auth = 0;
		}

	%STATE = (
		'Username' => '',
		);
	if ($is_auth) {
		($err, $usr_load_warnings) = &GetUserPrefs( $auth_username, \%STATE );
		next Err if ($err);
		$action = $action || &user_shell();
		}

	$const{'days_remaining'} = $STATE{'days_remaining'};

	if ($STATE{'is_disabled'}) {
		# disabled

		if ($STATE{'days_alive'}) { # expire/timeout
			$html_out = &pstr(382, $STATE{'days_alive'}, $STATE{'account_expires_days'} );
			}
		else {
			$html_out = '<p>' . $str[381] . '</p>';
			}
		$is_auth = 0;
		%STATE = ( 'Username' => '' );
		$auth->logout();
		}



	$| = 1;
	print "Content-Type: text/html\015\012\015\012";
	$const{'has_ct_header'} = 1;
	$| = 0;

	if (($STATE{'language'}) and ($STATE{'language'} ne $const{'language'})) {
		# hmm... let's try something different...
		my $test = [];
		$err = &loadlang( $STATE{'language'}, $test );
		if ($err) {
			$usr_load_warnings .= ".</p><p><b>Error:</b> " if ($usr_load_warnings);
			$usr_load_warnings .= $err;
			$err = '';
			}
		else {
			@str = @$test;
			$const{'language'} = $STATE{'language'};
			}
		}


	my %title_by_action = (
		'AnonCreate' => $str[49],
		'Main' => $str[56],
		'Rename' => $str[252],
		'Copy' => $str[255],
		'PR' => $str[222],
		'ListTemplates' => $str[52],
		'EventLog' => $str[59],
		'SY' => $str[240],
		'UC' => $str[243],
		'UA' => $str[57],
		'image-review' => $str[139],
		);

	$const{'content_type'} = $str[3];

	my %replace = %const;
	$replace{'cpfooter'} = qq!

		<p align="center"><font size="-2">
			The <a href="http://xav.com/scripts/genesis/">$const{'product'}</a> v$VERSION
			is copyright 2002 by Zoltan Milosevic.<br />$str[239]
		</font></p>

		!;
	$replace{'title'} = $title_by_action{$action} || '';
	$replace{'username'} = $STATE{'Username'};

	my $template_text = &ParseTemplate( 'template.html', "$const{'preferences folder'}templates/$const{'language'}", \%replace );

	unless ($template_text =~ m!^(.*)\%script_output\%(.*)$!is) {
		$err = "unable to find '\%script_output\%' marker in 'template.html' file";
		next Err;
		}

	print $1;
	$const{'footer_text'} = $2;

	my $ac = &he($system_eff{'/Users/Add/sign-up-url'});
	$ac =~ s!%admin_url%!$const{'admin_url'}!isg;

	if ($action eq 'AnonCreate') {
		print "<p><b>$const{'product'}</b> [ <a href=\"$const{'admin_url'}\">$str[48]</a> | <a href=\"$ac\">$str[34]</a> ]</p>\n";
		require 'manage_users.pm';
		$err = &anon_create_account();
		next Err if ($err);
		last Err;
		}

	unless ($is_auth) {
		if ($system_eff{'/Users/Add/automatic'}) {
			print "<p><b>$const{'product'}</b> [ <a href=\"$const{'admin_url'}\">$str[48]</a> | <a href=\"$ac\">$str[34]</a> ]</p>\n";
			}
		print $html_out;
		if ($system_eff{'/Users/Add/automatic'}) {
			&pppstr(268, $ac );
			}
		last Err;
		}

	$err = &StartHTML( $usr_load_warnings, $sys_load_warnings, $action );
	next Err if ($err);


	if ($action eq 'Main') {
		$err = &ui_Admin();
		next Err if ($err);
		}
	elsif ($action eq 'SS') {
		require 'html_editor.pm';
		&SwitchSort();
		$err = &ui_ListFiles();
		next Err if ($err);
		}
	elsif ($action eq 'Delete') {
		require 'html_editor.pm';
		$err = &ui_Delete( $STATE{'file_path'} );
		next Err if ($err);
		}
	elsif ($action eq 'Rename') {
		require 'html_editor.pm';
		$err = &ui_Rename();
		next Err if ($err);
		}
	elsif ($action eq 'Copy') {
		require 'html_editor.pm';
		$err = &ui_Copy();
		next Err if ($err);
		}
	elsif ($action eq 'Edit') {
		require 'html_editor.pm';
		my $b_done = 1;
		($err, $b_done) = &ui_Edit( $FORM{'FH'} );
		next Err if ($err);
		last Err if ($b_done);
		$err = &ui_ListFiles();
		next Err if ($err);
		}
	elsif ($action eq 'upload') {
		require 'html_editor.pm';
		$err = &ui_Upload( \%upload_files );
		next Err if ($err);
		}
	elsif ($action eq 'makedir') {
		require 'html_editor.pm';
		$err = &create_folder( $FORM{'directory'} );
		next Err if ($err);
		$err = &ui_ListFiles();
		next Err if ($err);
		}
	elsif ($action eq 'ListFiles') {
		require 'html_editor.pm';
		$err = &ui_ListFiles();
		next Err if ($err);
		}


	elsif ($action eq 'MFC') {
		require 'my_account.pm';
		$err = &ui_MyFolderConfig();
		next Err if ($err);
		}
	elsif ($action eq 'PR') {
		require 'my_account.pm';
		$err = &ShowSettings( $STATE{'Username'}, 1, 0 );
		next Err if ($err);
		}
	elsif ($action eq 'save_prefs') {

		my %updates = ();
		$err = &user_data_from_form( $STATE{'Username'}, \%updates );
		next Err if ($err);

		if ($STATE{'is_admin'}) {
			$err = &user_data_from_form_admin( $STATE{'Username'}, \%updates );
			next Err if ($err);
			}

		$err = &user_data_validate( $STATE{'Username'}, \%updates, 1 );
		next Err if ($err);

		my $warnings;
		($err, $warnings) = &user_data_save( $STATE{'Username'}, \%updates );
		next Err if ($err);
		print $warnings;

		$err = &password_set();
		next Err if ($err);

		}


	# template editor features:

	elsif ($action eq 'BT') {
		require 'template_editor.pm';
		$err = &BuildTemplate();
		next Err if ($err);
		}
	elsif ($action eq 'VT') {
		require 'template_editor.pm';
		$err = &SaveTemplate( \%upload_files );
		next Err if ($err);
		}
	elsif ($action eq 'ListTemplates') {
		require 'template_editor.pm';
		$err = &ui_ListTemplates();
		next Err if ($err);
		}



	# These features are not available in the freeware version:

		elsif (($const{'mode'} != 3) and ($action eq 'HI')) {
			require 'network.pm';
			$err = &http_import();
			next Err if ($err);
			}

		elsif (($const{'mode'} != 3) and ($action eq 'multi-upload')) {
			require 'html_editor.pm';
			$err = &form_BulkUpload( \%upload_files );
			next Err if ($err);
			}
		elsif (($const{'mode'} != 3) and ($action eq 'image-review')) {
			require 'html_editor.pm';
			$err = &form_ImageReview();
			next Err if ($err);
			}
		elsif (($const{'mode'} != 3) and ($action eq 'html-review')) {
			require 'html_editor.pm';
			$err = &form_HTML_Review();
			next Err if ($err);
			}

	#end


	# If a user doesn't enter a $FORM{'Action'}, then he goes through the default
	# &ListFiles routine defined above.  Otherwise, he enters this IF/ELSE block
	# and proceeds until he finds a match for his $Action.  Every possible user
	# action (except LogOut) has been offered above.  Thus, if he makes it this
	# far, he is either trying to log out, he has an invalid $Action, or he is a
	# super-user.  To keep things safe and secure, at this point we are just going
	# to log the user out unless he is the super-user:



	elsif (not $STATE{'is_admin'}) {
		my $h_action = &he($action);
		$err = "action '$h_action' is not defined for your account level";
		next Err;
		}

	# Okay, he's made it through - time to start offering super-user actions:

	# Basic admin actions:

		elsif ($action eq 'EventLog') {
			require 'system_settings.pm';
			$err = &ui_ManageLog();
			next Err if ($err);
			}
		elsif ($action eq 'SY') {
			require 'system_settings.pm';
			$err = &ui_SystemSettings();
			next Err if ($err);
			}
		elsif ($action eq 'UC') {
			require 'system_settings.pm';
			$err = &ui_UpdateLicense();
			next Err if ($err);
			}
		elsif ($action eq 'SSC') {
			require 'my_account.pm';
			$err = &save_shadow_change();
			next Err if ($err);
			}


	# Admin actions regarding management of user accounts; not available in freeware mode==3

		elsif (($const{'mode'} != 3) and ($action eq 'UA')) {
			require 'manage_users.pm';
			$err = &ui_ManageUsers();
			next Err if ($err);
			}

	# Default action:

	else {
		my $h_action = &he($action);
		$err = "action '$h_action' is not defined for your account level";
		next Err;
		}

	if ($STATE{'DiskUse'}) {
		$err = &ReportFreeSpace();
		next Err if ($err);
		}

	last Err;
	}
continue {
	print "Content-Type: text/html\015\012\015\12" unless ($const{'has_ct_header'});
	&ppstr(6,$err);
	}
print $const{'footer_text'};




sub ui_Admin {
	my $err = '';
	Err: {

		if ($STATE{'is_admin'}) {

			# links to admin interfaces:

			print qq!

<p><b>$str[247]</b></p>

<ul>

			!;
			if ($const{'mode'} != 3) {
				print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=UA">$str[57]</a></b><br />
		$str[58]</p>
	</li>

	<li>
		<p><b><a href="$const{'admin_url'}Action=EventLog">$str[59]</a></b><br />
		$str[81]</p>
	</li>

				!;
				}
			print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=SY">$str[240]</a></b><br />
		$str[241]</p>
	</li>

	<li>
		<p><b><a href="$const{'admin_url'}Action=UC">$str[243]</a></b><br />
		$str[242]</p>
	</li>

</ul>

			!;
			}

		# links to authoring interfaces (all users)

		print qq!

<p><b>$str[246]</b></p>

<ul>

		!;
		if ($STATE{'use_template_editor'}) {
			print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=ListTemplates">$str[52]</a></b><br />
		$str[244]</p>
	</li>

			!;
			}
		if ($STATE{'use_html_editor'}) {
			print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=ListFiles">$str[53]</a></b><br />
		$str[245]</p>
	</li>

			!;
			}
		if ($STATE{'use_my_account_page'}) {
			print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=PR">$str[222]</a></b><br />
		$str[248]</p>
	</li>

			!;
			}
		print qq!

	<li>
		<p><b><a href="$const{'admin_url'}Action=LogOut">$str[250]</a></b><br />
		$str[249]</p>
	</li>

	<li>
		<p><b><a href="$const{'help file'}">$str[55]</a></b><br />
		$str[251]</p>
	</li>

</ul>

		!;
		last Err;
		}
	return $err;
	}





sub StartHTML($$$);
sub StartHTML($$$) {
	my ( $usr_load_warnings, $sys_load_warnings, $action ) = @_;
	my $err = '';
	Err: {


		my $b_lock_folder = 0;
		if ($action =~ m!^(BT|Edit)$!) {
			$b_lock_folder = 1;
			}
		elsif (0 == $STATE{'use_chdir'}) {
			$b_lock_folder = 1;
			}



		my $callback = &he($FORM{'callback'} || $action);

		my $xaction = $callback;

		if ($xaction =~ m!^(Edit|Upload|Delete|Rename|Copy)$!) {
			$xaction = 'ListFiles';
			}

print <<"EOM";

<table border="0" width="100%">
<tr>
	<td><b>

		<a href="$const{'admin_url'}Action=Main">$str[56]</a>

EOM

print <<"EOM" if ($STATE{'use_template_editor'});

		-
		<a href="$const{'admin_url'}Action=ListTemplates">$str[52]</a>

EOM

print <<"EOM" if ($STATE{'use_html_editor'});

		-
		<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a>

EOM

print <<"EOM" if ($STATE{'use_my_account_page'});

		-
		<a href="$const{'admin_url'}Action=PR">$str[222]</a>

EOM

print <<"EOM";

	</b></td>
	<td align="right"><b>

		<a href="$const{'admin_url'}Action=LogOut">$str[250]</a>
		-
		<a href="$const{'help file'}">$str[55]</a>

	</b></td>
</tr>
</table>

EOM

		if ($STATE{'ShowTips'}) {
			my %replace = %const;
			my $tips = &ParseTemplate( 'tips.txt', "$const{'preferences folder'}templates/$const{'language'}", \%replace );
			#revcompat: strip stars.com tip
			$tips =~ s!\n.*?stars.com.*?\n!!s;

			my @tips = split(m!\r?\n!, $tips);
			my $N = scalar @tips;
			$N = int(rand($N));
			print qq!<hr size="1" />\n	<b>$str[262]:</b> $tips[$N]\n!;
			}


		print '<hr size="1" />';

		if ($const{'home_dir_err_msg'}) {
			&ppstr(6, $const{'home_dir_err_msg'} );
			if ($STATE{'is_admin'}) {
				&pppstr(95, "$const{'admin_url'}&amp;Action=MFC&amp;callback=$callback" );
				}
			else {
				&pppstr( 238 );
				}
			print qq!<hr size="1" />\n!;
			}
		elsif (not $STATE{'show_chdir'}) {
			#..
			}
		elsif ($b_lock_folder) {
			my $full = &he($STATE{'web_path'});

print <<"EOM";

		<table border="0">
		<tr>
			<td><b>$str[92]:</b></td>
			<td>$full<br /></td>
		</tr>
		</table>

		<hr size="1" />

EOM

			}
		else {

			my @subfolders = ();
			unless (opendir(DIR, '.')) {
				$err = &pstr(22, &he($STATE{'file_path'}, $!) );
				next Err;
				}
			foreach (sort readdir(DIR)) {
				next unless (-d $_);
				next if (m!^\.\.?$!);
				next if ((m!^\.!) and (0 == $STATE{'p_hidden'}));
				my ($temp_err, $is_cgi) = &CheckName( $_, 1 );
				next if ($temp_err);
				push(@subfolders, $_);
				}
			closedir(DIR);

print <<"EOM";

		<table border="0">
		<tr>
			<td nowrap="nowrap"><b>$str[92]:</b></td>
			<td>

$const{'AdminForm'}
<input type="hidden" name="Action" value="$xaction" />
<select name="set:CWD">

EOM

			my ($local, $full);
			my $LD = '';

			# if we are in a subfolder, then print all parent paths
			if ($FORM{'CWD'}) {
				print qq!<option value="">$STATE{'Author:UserURL:parsed'}</option>\n!;
				foreach (split(m!/!, $FORM{'CWD'})) {
					$LD .= $_;
					last if ($LD eq $FORM{'CWD'});

					($local, $full) = &he( $LD, "$STATE{'Author:UserURL:parsed'}$LD/" );

					print qq!<option value="$local">$full</option>\n!;
					$LD .= '/';
					}
				}

			# print our current option:
			($local, $full) = &he($FORM{'CWD'},$STATE{'web_path'});
			print qq!<option value="$local" selected="selected">$full</option>\n!;

			# print all child options
			my $base_cwd = $FORM{'CWD'} ? "$FORM{'CWD'}/" : '';
			foreach (@subfolders) {
				($local, $full) = &he("$base_cwd$_", "$STATE{'web_path'}$_/");
				print qq!<option value="$local">$full</option>\n!;
				}

			print qq!</select><input type="submit" class="submit" value="$str[94]" /></form></td></tr>!;

			if (($STATE{'ShowMFCTip'}) and ($STATE{'is_admin'})) {
				print qq!<tr><td><br /></td><td><font size="-2">[ !;
				&ppstr(95, "$const{'admin_url'}Action=MFC&amp;callback=$callback" );
				print " ]</font></td></tr>";
				}
			print qq!</table>\n<hr size="1" />\n!;
			}

		# warn the webmaster about any data validations errors while loading script_data/security.txt

		if (($sys_load_warnings) and ($STATE{'is_admin'})) {
			print "<p>$str[237]</p>\n";
			&pppstr(235, "$const{'admin_url'}Action=SY", $str[240] );
			&ppstr(6, $sys_load_warnings );
			print qq!<hr size="1" />\n!;
			}


		# warn about any data validation errors while loading user-level settings from file:

		if ($usr_load_warnings) {
			print qq!<p>$str[236]</p>\n!;

			if ($STATE{'use_my_account_page'}) {
				&pppstr(235, "$const{'admin_url'}Action=PR", $str[222] );
				}
			else {
				print qq!<p>$str[238]</p>\n!;
				}

			&ppstr(6, $usr_load_warnings );

			print qq!<hr size="1" />\n!;
			}


		last Err;
		}
	return $err;
	}


sub ui_Upload {
	my $err = '';
	Err: {

		my ($p_upload_files) = @_;
		my $upload_success = 0;

		my ($name, $p_data) = ();
		while (($name, $p_data) = each %$p_upload_files) {

			if ($$p_data{'err_msg'}) { #changed
				&ppstr(5, $$p_data{'err_msg'});
				next;
				}

			my $altfile = '';
			my $TempFile = $$p_data{'temp file'};
			if ($TempFile =~ m!^(.*)(\\|/)(.+?)$!) {
				$altfile = $3;
				}
			# skip null uploads
			next if ((not (-s $$p_data{'temp file'})) and (not $$p_data{'client file name'}));


			# we call &priv_check() late because &ui_Upload() is always called for
			# template-builds, even when there aren't uploads involved.  This makes it so that we
			# don't bother users with error messages unless it is applicable.

			$err = &priv_check( 1, 'p_upload' );
			next Err if ($err);




			my $file = $$p_data{'client file name'} || $altfile;
			$file = $3 if ($file =~ m!^(.*)(\\|/)(.+?)$!);
			$file =~ s! !_!g;

			my $extension = '';
			if ($file =~ m!.*\.([^\.\/\\]+)$!) {
				$extension = $1;
				}

			my $hname = &he($file);

			if (1 == $STATE{'p_upload'}) {
				# only media files...

				my $qm_ext = quotemeta($extension);

				my $media = " $system_eff{'Media Types'} ";
				unless ($media =~ m! $qm_ext !) {
					my $h_ext = &he($extension);

					&ppstr(5, &pstr(50, $hname, $h_ext, $media ) );

					$$p_upload_files{$name} = ();
					next;
					}
				}

			my $is_cgi = 0;
			($err, $is_cgi) = &CheckName( $file,1 );
			if ($err) {

				# can we use the alternate name? and will it not collide with an existing file?
				my $alt_err_msg = '';
				($alt_err_msg, $is_cgi) = &CheckName( $altfile,1 );
				if ((not (-e $altfile)) and ($alt_err_msg eq '')) {
					&ppstr(5, $err);
					&pppstr(161, &pstr(162, $altfile));
					$file = $altfile;
					}
				else {
					&ppstr(6,$err);
					next;
					}
				$err = '';
				}

			&Mask( $file, $is_cgi ) if (-e $file);

			my $SIZE = $$p_data{'size'};
			if (($SIZE > 0) and (not &CheckFreeSpace($SIZE))) {
				$err = &pstr(9, $file, $str[29] );
				next Err;
				}

			my $FullText = '';

			my $MODE = 0;
				# 0 => no conversion; zero-byte file
				# 1 => no conversion; normal file; "binary" mode
				# 2 => convert to ascii format; "ascii/text" mode

			if (-s $TempFile) {
				if ((-T $TempFile) and ($STATE{'TextUpload'})) {
					$MODE = 2;
					}
				else {
					$MODE = 1;
					}
				}

			unless (open(FILE, ">$file")) {
				$err = &extended_f_err($file);
				next Err;
				}

			unless (binmode(FILE)) {
				$err = &pstr(12, $file, $! );
				next Err;
				}

			unless (open(TEMP, "<$TempFile")) {
				$err = &pstr(8, $TempFile, $! );
				next Err;
				}

			unless (binmode(TEMP)) {
				$err = &pstr(12, $TempFile, $! );
				next Err;
				}
			while (defined($_ = <TEMP>)) {
				if ($MODE == 2) {
					s!\cM\n!\n!sg;
					s!\015\012!\012!sg;
					}
				unless (print FILE $_) {
					$err = &pstr(231, &he( $file, $!, $^E ) );
					close(FILE);
					close(TEMP);
					next Err;
					}
				}
			unless (close(FILE)) {
				$err = &pstr(220, &he( $file, $!, $^E ) );
				close(TEMP);
				next Err;
				}
			unless (close(TEMP)) {
				$err = &pstr(220, &he( $TempFile, $!, $^E ) );
				next Err;
				}

			&Mask( $file, $is_cgi );

			my $size = -s $file;
			if ($size < 2048) {
				$size = "$size bytes";
				}
			elsif ($size < 1024 * 1024 * 2) {
				$size = int( ($size + 1023) / 1024 ) . " kb";
				}
			else {
				$size = int( ($size + 1048575) / (1024 * 1024) ) . ' MB';
				}

			my $status;
			if ($MODE == 2) {
				$status = &pstr( 163, &he($file), 'ascii/text', $size );
				}
			elsif ($MODE == 1) {
				$status = &pstr( 163, &he($file), 'binary', $size );
				}
			else {
				$status = &pstr(179, &he($file) );
				}

			&Report( &pstr(4, $status ) );

			$upload_success++;
			$$p_data{'server file name'} = $file;
			}
		last Err;
		}
	return $err;
	}











=item password_set

Usage:
	$err = &password_set();
	next Err if ($err);

This subroutine will *optionally* set the user password if and only if the $FORM{'OldPass'} variable is non-empty.

If that var is non-empty, then it will validate $FORM{'OldPass'} against username $STATE{'Username'} and will then set using $FORM{'NewPass'} and $FORM{'NewPass2'}.

See also, password_force()

=cut

sub password_set {
	my $err = '';
	Err: {
		last Err unless (defined($FORM{'OldPass'}));
		last Err unless (length($FORM{'OldPass'}));

		# they have initialized their old password; now they *must* set a new one:

		my $is_valid;
		($err, $is_valid) = $auth->ValidatePassword( $STATE{'Username'}, $FORM{'OldPass'} );
		next Err if ($err);
		unless ($is_valid) {
			$err = $str[33];
			next Err;
			}

		$err = &password_force( $STATE{'Username'}, $FORM{'NewPass'}, $FORM{'NewPass2'} );
		next Err if ($err);

		last Err;
		}
	return $err;
	};


=item password_force

Usage:
	$err = &password_force( $username, $password1, $password2 );
	next Err if ($err);

This routine validates that $password1 and $password2 agree with one another and meet the validation rules.

It then updates the password file.

=cut

sub password_force {
	my ($username, $password, $confirm) = @_;
	my $err = '';
	Err: {

		if ($password ne $confirm) {
			$err = $str[40];
			next Err;
			}

		if (length($password) < $system_eff{'Min Password Length'}) {
			$err = &pstr(229,$system_eff{'Min Password Length'});
			next Err;
			}
		if (length($password) > 8) {
			$err = "password cannot exceed 8 characters in length";
			next Err;
			}

		$err = $auth->SetPassword( $username, $password );
		next Err if ($err);

		&Report(&pstr(4,$str[230]));

		last Err;
		}
	return $err;
	};


sub detect_sec_mode {
	if ($^O =~ m!mswin!is) {
		return 1; # do not set perms
		}
	elsif ((-e $0) and (-w $0)) {
		return 2; # set-user-id; tight
		}
	else {
		return 3; # permissive
		}
	}

sub force_CRLF {
	my ($p_text) = @_;
	$$p_text =~ s!\015\012!\012!sg;
	$$p_text =~ s!\015!\012!sg;
	$$p_text =~ s!\012!\015\012!sg;
	}



sub query_env {
	my ($name,$default) = @_;
	if (($ENV{$name}) and ($ENV{$name} =~ m!^(.*)$!s)) {
		return $1;
		}
	elsif (defined($default)) {
		return $default;
		}
	else {
		return '';
		}
	}

sub user_shell {
	if ($STATE{'shell'}) {
		if ($STATE{'shell'} == 1) {
			return 'ListTemplates';
			}
		elsif ($STATE{'shell'} == 2) {
			return 'ListFiles';
			}
		}
	return 'Main';
	}

sub recurse {
	my ($path, $basename, $depth, $p_start, $p_entry, $p_stop) = @_;
	my $err = '';
	Err: {

		$depth++;

		$path = $path . '/' . $basename;
		unless (opendir(DIR, $path)) {
			$err = "unable to opendir '$path' - $!";
			next Err;
			}
		my @entries = sort readdir(DIR);
		closedir(DIR);

		$err = &{ $p_start }( $path, $depth );
		next Err if ($err);

		foreach $basename (@entries) {
			next if ($basename =~ m!^\.\.?$!);
			$err = &{ $p_entry }( $path, $basename, $depth );
			next Err if ($err);
			if (-d "$path/$basename") {
				$err = &recurse( $path, $basename, $depth, $p_start, $p_entry, $p_stop );
				next Err if ($err);
				}
			}

		$err = &{ $p_stop }( $path, $depth );
		next Err if ($err);

		}
	return $err;
	}

sub extended_f_err {
	my ($file) = @_;
	my $errstr = $!;
	if ($errstr =~ m!Permission denied!i) {
		return &pstr( 9, $file, qq!$errstr - $^E [<a href="$const{'help file'}1096.html">$str[55]</a>]! );
		}
	else {
		return &pstr( 9, $file, qq!$errstr - $^E! );
		}
	}

sub priv_check {
	my ($b_filesys, @privileges) = @_;
	my $err = '';
	Err: {
		if (($b_filesys) and ($const{'home_dir_err_msg'})) {
			$err = "all Genesis authoring functions disabled.</p><p>Cannot access the file system due to a folder access error on start-up. Error was: $const{'home_dir_err_msg'}";
			next Err;
			}
		local $_;
		foreach (@privileges) {
			next if ($STATE{$_});
			my $name = $_;
			if (($user_schema{$name}) and ($user_schema{$name}->[3])) {
				$name = $user_schema{$name}->[3];
				# converts 'use_html_editor' to 'Use HTML Editor' where possible
				}
			$err = &pstr( 51, $name );
			next Err;
			}
		last Err;
		}
	return $err;
	}


sub FolderSize {
	my ($dir, $b_verbose) = @_;
	my $size = 0;
	my $err = '';
	Err: {
		$err = &priv_check(1);
		next Err if ($err);

		# make all slashes be forward:

		$dir =~ s!\\!/!g;

		# add trailing slash if necessary:
		$dir .= '/' unless ($dir =~ m!/$!);
		if (defined($dir_size{$dir})) {
			$size = $dir_size{$dir};
			last Err;
			}

		# we treat folder-access errors as warnings. in general, it is okay if there are subfolders which the CGI process
		# does not have access to.  but we should warn about it
		unless (opendir(DIR, $dir)) {
			if ($b_verbose) {
				print "<p><b>Warning:</b> unable to calculate disk usage - unable to open folder '$dir' - $! - $^E.</p>\n";
				}
			last Err;
			}
		my @Files = readdir(DIR);
		closedir(DIR);
		my $del_size = 0;
		my $entry;
		foreach $entry (@Files) {
			next if ($entry =~ m!^\.\.?$!);
			my $abs_path = $dir . $entry;
			if ((-d $abs_path) and (not -l $abs_path)) {
				($err, $del_size) = &FolderSize( $abs_path );
				next Err if ($err);
				$size += $del_size;
				}
			else {
				$size += (-s $abs_path);
				}
			}
		$dir_size{$dir} = $size;
		last Err;
		}
	return ($err, $size);
	}

sub Report {
	my ($message, $do_not_print_to_screen) = @_;
	print $message unless ($do_not_print_to_screen);
	if (-e $const{'event log'}) {
		if (open(LOG, ">>$const{'event log'}")) {
			my $time = time();
			$message =~ s!<.*?>!!g;
			$message =~ s!\,!!g;
			print LOG "$private{'REMOTE_ADDR'} , $STATE{'Username'},$time,$message\n";
			close(LOG);
			}
		else {
			&ppstr(6,&pstr(10, $const{'event log'}, $! ) );
			}
		}
	}


sub Mask {
	my ($abs_file, $is_cgi) = @_;
	return unless ($file_sec[0]);
	if (-d $abs_file) {
		chmod( $file_sec[1], $abs_file);
		}
	elsif (($is_cgi) and ($const{'mode'} != 0)) {
		chmod( $file_sec[3], $abs_file );
		}
	else {
		chmod( $file_sec[2], $abs_file);
		}
	}

sub CheckFreeSpace {
	my ($del_size) = @_;
	my $is_allowed = 1;
	my $err = '';
	Err: {
		if ($const{'home_dir_err_msg'}) {
			$is_allowed = 0;
			next Err;
			}
		last Err if ($STATE{'allow_no_quota'});
		my $Quota = $STATE{'Quota'};

		my $DiskBytes;
		($err, $DiskBytes) = &FolderSize($STATE{'Author:UserFolder:parsed'});
		next Err if ($err);

		my $DiskKB = int($DiskBytes/1000);
		my $FreeKB = $Quota - $DiskKB;

		$is_allowed = (($FreeKB * 1000) > $del_size) ? 1 : 0;
		last Err;
		}
	continue {
		$is_allowed = 0;
		}
	return $is_allowed;
	}

sub ReportFreeSpace {
	my $err = '';
	Err: {

		last Err if ($const{'home_dir_err_msg'});

		my $DiskBytes;
		($err, $DiskBytes) = &FolderSize($STATE{'Author:UserFolder:parsed'});
		next Err if ($err);

		my $DiskKB = int( (1023 + $DiskBytes) /1024);

		if (($STATE{'allow_no_quota'}) or (not ($STATE{'Quota'}))) {

			$DiskKB = &FormatNumber( $DiskKB, 0, 0, 0, 1 );

print <<"EOM";

<hr size="1" />

<b>$str[207]</b> $DiskKB kb<br />

EOM

			}
		else {

			my $Quota = $STATE{'Quota'};
			my $FreeKB = $Quota - $DiskKB;
			my $percent = &FormatNumber( ( 100 * ($DiskBytes / 1000) / $Quota ), 1, 0, 0, 1 );
			my $width1 = int( 200 * ($DiskBytes / 1000) / $Quota );
			$width1 = 1 unless ($width1);
			$width1 = 199 if ($width1 > 199);
			my $width2 = 200 - $width1;
			$FreeKB = &FormatNumber( $FreeKB, 0, 0, 0, 1 );
			$Quota = &FormatNumber( $Quota, 0, 0, 0, 1 );
			$DiskKB = &FormatNumber( $DiskKB, 0, 0, 0, 1 );

print <<"EOM";

<hr size="1" />

<b>$str[207]</b> <img src="$system_eff{'Images URL'}bar_red.gif" height="7" width="$width1" border="1" alt="" /><img src="$system_eff{'Images URL'}bar_black.gif" height="7" width="$width2" border="1" alt="" /> $percent%<br />

EOM
			&ppstr(208, $DiskKB, $Quota, $FreeKB);
			print '<br />';
			}
		last Err;
		}
	return $err;
	}





sub CheckName {
	my ($file, $rq_write, $b_is_username) = @_;
	my $is_cgi = 0;

	my $max_file_len = 120;

	my $err = '';
	Err: {

		unless ($file) {
			$err = $b_is_username ? $str[39] : $str[209];
			next Err;
			}

		if (length($file) > $max_file_len) {
			$err = &pstr(210,$max_file_len);
			next Err;
			}

		if ($file =~ m! !) {
			$err = $str[211];
			next Err;
			}

		if ($file =~ m!\.\.!) {
			$err = $str[212];
			next Err;
			}

		if (($file =~ m!^\.!) and ($file !~ m!\.template$!) and (0 == $STATE{'p_hidden'})) {
			$err = $str[213]; #but those .x.template files are ok
			next Err;
			}


		if (($file =~ m!^\.!) and ($file !~ m!\.template$!) and ($STATE{'p_hidden'} < 2) and ($rq_write)) {
			$err = $str[214]; #but those .x.template files are ok
			next Err;
			}


		my $V = '';
		($V = $file) =~ s/\w//g;
		$V =~ s/\.//g;
		$V =~ s/\-//g;

		if ($V) {
			$err = &pstr(215,&he($V));
			next Err;
			}

		my $extension = 'null';
		if ($file =~ m!(.*)\.(.*?)$!) {
			$extension = lc($2);
			}

		my $qm_ext = quotemeta( $extension );
		my $html_ext = &he( $extension );


		if (" $system_eff{'CGI Types'} " =~ m! \* !) {
			$is_cgi = 1;
			}
		else {
			$is_cgi = (" $system_eff{'CGI Types'} " =~ m! $qm_ext !i) ? 1 : 0;
			}

		if ($is_cgi) {
			if ($STATE{'allow_cgi'}) {
				# okay
				}
			else {
				$err = &pstr(216,$html_ext, $const{'help file'});
				next Err;
				}
			}
		elsif (" $system_eff{'Known Types'} $system_eff{'Media Types'} " =~ m! \* !) {
			# ok...

			}
		else {
			if (" $system_eff{'Known Types'} $system_eff{'Media Types'} " =~ m! $qm_ext !i) {
				# okay
				}
			else {
				$err = &pstr(217,$html_ext, $const{'help file'});
				next Err;
				}
			}
		}

	if ($err) {
		if ($b_is_username) {
			$err = &pstr(41, &he($file), $err );
			}
		else {
			$err = &pstr(218,&he($file),$err);
			}
		}
	elsif ($file =~ m!^(.*)$!) {
		$file = $1; # untaint
		}

	return ($err, $is_cgi, $file);
	}





sub LoadUserPrefs {
	my ($username, $p_prefs) = @_;
	my $warnings = '';
	my $err = '';
	Err: {
		local $_;

		# Default state:
		my %testdata = (
			'Username' => $username,
			'is_admin' => ($username eq $private{'super user'}) ? 1 : 0,
			'is_disabled' => 0,
			'days_remaining' => 0,
			);

		my $UserFile = "$const{'preferences folder'}accounts/$username.txt";
		my $text = '';
		if (-e $UserFile) {
			($err, $text) = &ReadFile( $UserFile );
			next Err if ($err);
			}

		foreach (split(m!\012!s, $text)) {
			next unless (m!^(.*?)=(.*?)=!s);
			my ($name, $value) = (&url_decode($1), &url_decode($2));
			$testdata{$name} = $value;
			}

		#reverse compat - added for build 0006
		unless ($testdata{'_BUILD'}) {
			$testdata{'_BUILD'} = 6;
			$testdata{'allow_no_quota'} = 0;
			if ($testdata{'is_admin'}) {
				$testdata{'Author:UserFolder'} = $system_eff{'Base Folder'};
				$testdata{'Author:UserURL'} = $system_eff{'Base URL'};
				}
			else {
				$testdata{'Author:UserFolder'} = "$system_eff{'Base Folder'}%username%/";
				$testdata{'Author:UserURL'} = "$system_eff{'Base URL'}%username%/";
				}
			}

		#revcompat for the _default account
		$testdata{'AccountCreated'} = time() unless ($testdata{'AccountCreated'});


		#revcompat for pre-0019


		if (($testdata{'Sort'}) and ((not $testdata{'_BUILD'}) or ($testdata{'_BUILD'} < 16))) {
			# in pre-0016, we handled sort values differently; just force a valid default by-name value
			$testdata{'Sort'} = 't'; # default;
			}




		if (not defined($testdata{'WaitAdminApprove'})) {
			$testdata{'WaitAdminApprove'} = 0;
			}
		if (not defined($testdata{'p_upload'})) {
			if (defined($testdata{'use_file_upload'})) {
				if ($testdata{'use_file_upload'}) {
					$testdata{'p_upload'} = 2;
					}
				else {
					$testdata{'p_upload'} = 0;
					}
				}
			else {
				# set to system default
				$testdata{'p_upload'} = 2;
				}
			}
		if (not defined($testdata{'p_hidden'})) {
			if ($testdata{'hidden_file_modify'}) {
				$testdata{'p_hidden'} = 2;
				}
			elsif ($testdata{'hidden_file_view'}) {
				$testdata{'p_hidden'} = 1;
				}
			else {
				$testdata{'p_hidden'} = 0;
				}
			}
		#/revcompat



		# load default values for any key which is not defined:
		my $key;
		foreach $key (keys %user_schema) {
			next if (defined($testdata{$key}));
			$testdata{$key} = $user_schema{$key}->[4];
			}

		foreach ('UserFolder', 'UserURL') {
			my $key_p = "Author:$_:parsed";
			my $key = "Author:$_";

			# convert paths to forward slash
			$testdata{$key} =~ s!\\!/!g;

			$testdata{$key_p} = $testdata{$key};
			$testdata{$key_p} =~ s!\%username\%!$username!ig;

			# add a trailing slash if there isn't already one present:
			$testdata{$key_p} .= '/' unless ($testdata{$key_p} =~ m!/$!);
			}

		$testdata{'Quota'} = 1 unless (($testdata{'Quota'} =~ m!^(\d+)$!) and ($1 > 0));


		# by default, everyone has allow_folder_change unless it is disabled at the file level
		$testdata{'allow_folder_change'} = 1;


		# respect file-based restrictions
		my $p_sub = $private{'force_user_limits'};
		($err, %testdata) = &$p_sub( 0, 1, %testdata );
		next Err if ($err);

		($warnings, %$p_prefs) = &load_best_values( \%user_schema, \%testdata );

		if ($$p_prefs{'account_status'} == 2) {
			$$p_prefs{'is_disabled'} = 1;
			}
		elsif ($$p_prefs{'account_status'} == 1) {
			$$p_prefs{'days_alive'} = int( (time() - $$p_prefs{'AccountCreated'}) / 86400 );
			$$p_prefs{'days_remaining'} = $$p_prefs{'account_expires_days'} - $$p_prefs{'days_alive'};

			if ($$p_prefs{'days_remaining'} < 0) {
				$$p_prefs{'is_disabled'} = 1;
				}
			}




		last Err;
		}
	return ($err, $warnings);
	}

sub h1 {
	print '<h1>', @_, '</h1>';
	}








=item GetUserPrefs

Loads user information for $username into the by-reference hash $p_STATE.

Error scenarios:

	* unable to load user information from file; returns fatal $err

	* unable to chdir to user's home folder (webmaster)

		* returns $warnings;

		* sets $const{'home_dir_err_msg'} to disable all filesystem write operations

		* this allows the user (if webmaster) to be able to customize his Base Folder setting

	* unable to chdir to user's home folder (non-webmaster)

		* returns $err


	* able to chdir to user home folder, but unable to access a subfolder defined by FORM{'CWD'}

		* returns fatal $err - unable to access subfolder CWD

		* chooses not to propagate CWD into self-referential URL/FORM

		* user should see the error message, but subsequently will be returned to his home root folder instead of the invalid subfolder, and will be able to navigate normally


=cut

sub GetUserPrefs {
	my ($username, $p_STATE) = @_;
	my $b_cwd_err = 0;
	my $warnings = '';
	my $err = '';
	Err: {

		# initialize:
		%$p_STATE = ( 'Username' => $username );

		# read in information from the userfile:
		($err, $warnings) = &LoadUserPrefs( $username, $p_STATE );
		next Err if ($err);

		# set up the current working folder:
		$$p_STATE{'web_path'} = $$p_STATE{'Author:UserURL:parsed'};
		$$p_STATE{'file_path'} = $$p_STATE{'Author:UserFolder:parsed'};

		# test access to home folder:
		unless (chdir($$p_STATE{'file_path'})) {
			# uh-oh... cannot access home folder...
			$err = &pstr(26, &he($$p_STATE{'file_path'}, $!, $^E) );
			if ($$p_STATE{'is_admin'}) {
				$const{'home_dir_err_msg'} = $err;
				$err = '';
				}
			next Err;
			}

		# test2 access to home folder:
		if (opendir(DIR,'.')) {
			closedir(DIR);
			}
		else {
			# uh-oh... cannot access home folder...
			$err = &pstr(22, &he($$p_STATE{'file_path'}, $! ) );
			if ($$p_STATE{'is_admin'}) {
				$const{'home_dir_err_msg'} = $err;
				$err = '';
				}
			next Err;
			}

		# test access to current-working-directory subfolder:
		if (defined($FORM{'set:CWD'})) {
			$FORM{'CWD'} = $FORM{'set:CWD'};
			}
		if ($FORM{'CWD'}) {
			$b_cwd_err = 1;
			$err = &priv_check( 0, 'use_chdir' );
			next Err if ($err);

			# boundary tests (because split() will strip boundary fields)
			if ($FORM{'CWD'} =~ m!^/!) {
				$err = "CWD value cannot begin with a slash";
				next Err;
				}
			elsif ($FORM{'CWD'} =~ m!/$!) {
				$err = "CWD value cannot end with a slash";
				next Err;
				}

			my $component;
			foreach $component (split(m!/!s, $FORM{'CWD'})) {
				my $is_cgi;
				($err, $is_cgi) = &CheckName($component,1);
				next Err if ($err);
				}

			my $hcwd = &he($FORM{'CWD'});
			unless (chdir($FORM{'CWD'})) {
				$err = "unable to access subfolder '$hcwd' - $! - $^E";
				next Err;
				}
			if (opendir(DIR,'.')) {
				closedir(DIR);
				}
			else {
				$err = &pstr(22, &he($FORM{'CWD'}, $! ) );
				next Err;
				}
			$b_cwd_err = 0;
			$$p_STATE{'file_path'} .= "$FORM{'CWD'}/";
			$$p_STATE{'web_path'} .= "$hcwd/";
			$const{'admin_url'} .= "CWD=" . &ue($FORM{'CWD'}) . "&amp;";
			$const{'AdminForm'} .= qq!\n<input type="hidden" name="CWD" value="$hcwd" />!;
			$const{'AdminFormFile'} .= qq!\n<input type="hidden" name="CWD" value="$hcwd" />!;
			}


		$$p_STATE{'LastLogin'} = 0 unless ($$p_STATE{'LastLogin'});
		my $login_age = time() - $$p_STATE{'LastLogin'};
		last Err unless (3600 < $login_age);

		# skip for demo
		last Err if (($const{'mode'} == 0) and ($$p_STATE{'is_admin'}));

		# update LastLogin time and host:
		my $warn_msg = '';
		($err, $warn_msg) = &user_data_save( $username, $p_STATE, 1, 1 );
		next Err if ($err);
		$warnings .= $warn_msg;

		last Err;
		}
	if ($b_cwd_err) {
		$err .= qq!.</p><p>Click here to <a href="$const{'admin_url'}set:CWD=">return to the main page</a>!;
		}
	return ($err, $warnings);
	}



sub user_data_from_form($$) {
	my ($username, $p_userdata) = @_;
	my $err = '';
	Err: {
		$$p_userdata{'Username'} = $username;
		local $_;
		foreach (keys %user_schema) {
			next unless ($user_schema{$_}->[5] == 2); # deal with user-defined settings
			if (not defined($FORM{$_})) {
				$err = "user settings '$_' is not defined within the form input";
				next Err;
				}
			$$p_userdata{$_} = $FORM{$_};
			}

		# perform expensive file-base audit:
		my @null = ();
		$err = &loadlang( $$p_userdata{'language'}, \@null, 1 );
		next Err if ($err);


		last Err;
		}
	return $err;
	};

sub user_data_from_form_admin($$) {
	my ($username, $p_userdata) = @_;
	my $err = '';
	Err: {

		local $_;
		foreach (keys %user_schema) {

			# skip derived fields:
			next if (($_ eq 'use_templates') and ($FORM{'update_privilege_list'}));
			next if (m!\:parsed$!);
			next if ($_ eq 'is_admin');

			my $value;
			if ($user_schema{$_}->[5] == 3) {
				# admin/hybrid key -- set to $FORM{val} or use system default

				if (defined($FORM{$_})) {
					$value = $FORM{$_};
					}
				else {
					$value = $user_schema{$_}->[4];
					}

				}
			elsif ($user_schema{$_}->[5] == 1) {
				# admin key -- must be defined:

				if (not defined($FORM{$_})) {
					$err = "admin setting '$_' is not defined within the form input";
					next Err;
					}
				$value = $FORM{$_};

				}
			else {
				next; # system or user-defined key..
				}

			$$p_userdata{$_} = $value;
			}


		if ($FORM{'update_privilege_list'}) {

			my $var;
			my @template_paths = ();
			foreach $var (keys %FORM) {
				next unless ($var =~ m!^use_templates_(.+)$!);
				next unless ($FORM{$var});
				push(@template_paths,$1);
				}
			$$p_userdata{'use_templates'} = $FORM{'use_templates'} = join(',',@template_paths);

			foreach $var (
				'allow_cgi',
				'allow_no_quota',
				'p_hidden',
				'p_upload',
				'priv_scheme',
				'account_status',
				'account_expires_days',
				'use_he_copy',
				'use_he_delfile',
				'use_he_delfolder',
				'use_he_edit',
				'use_he_mkdir',
				'use_he_mkdir',
				'use_he_mkfile',
				'use_he_rename',
				'use_he_ri',
				'use_he_show',
				'use_he_val',
				'use_html_editor',
				'use_my_account_page',
				'use_template_editor',
				'use_templates',
				) {
				$err = &fd_validate( $FORM{$var}, @{ $user_schema{$var} } );
				next Err if ($err);
				}

			if ($$p_userdata{'priv_scheme'} == 4) {
				# platinum
				&merge( $p_userdata,
					'Quota' => $FORM{'4_Quota'},
					'allow_cgi' => 1,
					'allow_no_quota' => 0,
					'p_hidden' => 0,
					'p_upload' => 2,
					'use_html_editor' => 1,
					'use_my_account_page' => 1,
					'use_template_editor' => 1,
					'use_chdir' => 1,
					);
				}
			elsif ($$p_userdata{'priv_scheme'} == 3) {
				# gold
				&merge( $p_userdata,
					'Quota' => $FORM{'3_Quota'},
					'allow_cgi' => 0,
					'allow_no_quota' => 0,
					'p_hidden' => 0,
					'p_upload' => 2,
					'use_html_editor' => 1,
					'use_my_account_page' => 1,
					'use_template_editor' => 1,
					'use_chdir' => 1,
					);
				}
			elsif ($$p_userdata{'priv_scheme'} == 2) {
				# silver
				&merge( $p_userdata,
					'Quota' => $FORM{'2_Quota'},
					'allow_cgi' => 0,
					'allow_no_quota' => 0,
					'p_hidden' => 0,
					'p_upload' => 1,
					'use_html_editor' => 0,
					'use_my_account_page' => 1,
					'use_template_editor' => 1,
					'use_chdir' => 1,
					);
				}
			elsif ($$p_userdata{'priv_scheme'} == 1) {
				# bronze
				&merge( $p_userdata,
					'Quota' => $FORM{'1_Quota'},
					'allow_cgi' => 0,
					'allow_no_quota' => 0,
					'p_hidden' => 0,
					'p_upload' => 0,
					'use_html_editor' => 0,
					'use_my_account_page' => 1,
					'use_template_editor' => 1,
					'use_chdir' => 1,
					);
				}



			if ($$p_userdata{'use_html_editor'} != 2) {

				# if HTML Editor is completely on or off (1 or 0),
				# then reset all the sub-privileges to the master value:

				$$p_userdata{'use_he_copy'} =
				$$p_userdata{'use_he_delfile'} =
				$$p_userdata{'use_he_delfolder'} =
				$$p_userdata{'use_he_edit'} =
				$$p_userdata{'use_he_mkdir'} =
				$$p_userdata{'use_he_mkfile'} =
				$$p_userdata{'use_he_rename'} =
				$$p_userdata{'use_he_ri'} =
				$$p_userdata{'use_he_show'} =
				$$p_userdata{'use_he_val'} =

					$$p_userdata{'use_html_editor'};

				}


			# don't let webmaster surrender key abilities:

			if ($username eq $private{'super user'}) {

				if ($$p_userdata{'account_status'} != 0) {
					$err = "main account '$private{'super user'}' cannot be Disabled or Expired";
					next Err;
					}

				$$p_userdata{'use_my_account_page'} = 1;
				}


			}


		last Err;
		}
	return $err;
	};


sub user_data_validate {
	my ( $username, $p_userdata, $b_check_file_system ) = @_;
	my $err = '';
	Err: {

		# perform validation on the fields being updated
		$err = &validate_hash( \%user_schema, $p_userdata );
		next Err if ($err);

		# optional file system check:

		last Err unless ($b_check_file_system);
		last Err if ($username eq '_default');
		last Err unless (defined($$p_userdata{'Author:UserFolder'}));

		my $test_folder = $$p_userdata{'Author:UserFolder'};
		$test_folder =~ s!\%username\%!$username!ig;
		$test_folder =~ s!^(.+)/$!$1!; # strip trailing slash if present and if that is not the only thing in the path
		unless (-e $test_folder) {
			$err = &pstr(27, &he($test_folder) );
			next Err;
			}
		unless (-d $test_folder) {
			$err = &pstr(28, &he($test_folder) );
			next Err;
			}


		last Err;
		}
	return $err;
	}


sub user_data_save {
	my ($username, $p_updates, $is_login, $b_silent) = @_;
	my $warnings = '';
	my $err = '';
	Err: {


		# make sure this is a valid username:
		# important since we'll eventually write to a file as "accounts/$username.txt"
		my $is_cgi;
		($err, $is_cgi) = &CheckName( $username, 1, 1 );
		next Err if ($err);

		# perform first-pass validation on the fields being updated

		$err = &validate_hash( \%user_schema, $p_updates, 0 );
		next Err if ($err);

		local $_;
		foreach ('Author:UserFolder', 'Author:UserURL') {
			next unless (defined($$p_updates{$_}));
			next unless ($$p_updates{$_} =~ m!(/username\%|/\%username(/|$))!i);
			$err = "wildcard syntax must be ' %username% ' - you entered $1";
			next Err;
			}

		my %userdata = ();
		($err, $warnings) = &LoadUserPrefs( $username, \%userdata );
		next Err if ($err);

		# Mix in the overrides:
		foreach (keys %$p_updates) {
			if (defined($$p_updates{$_})) {
				$userdata{$_} = $$p_updates{$_};
				}
			}

		# the system would now like to force a few values:
		$userdata{'Username'} = $username;
		my $build = 1;
		if ($VERSION =~ m!(\d+)$!) {
			$build = 1 * $1;
			}
		$userdata{'_BUILD'} = $build;
		$userdata{'_VERSION'} = $VERSION;
		if ($is_login) {
			$userdata{'LastLogin'} = time();
			$userdata{'LastLoginFrom'} = $private{'REMOTE_ADDR'};
			}
		$userdata{'AccountCreated'} = time() unless ($userdata{'AccountCreated'});


		# respect file-based restrictions
		my $p_sub = $private{'force_user_limits'};
		($err, %userdata) = &$p_sub( 1, 2, %userdata );
		next Err if ($err);

		# now perform a full validation of all fields:

		$err = &validate_hash( \%user_schema, \%userdata, 1 );
		next Err if ($err);

		my @keys = keys %userdata;
		foreach (@keys) {
			next if (defined($user_schema{$_}));
			delete $userdata{$_};
			}

		# Write to disk
		my $text = '';
		foreach (sort keys %userdata) {
			next if (m!(is_admin|:parsed)$!); # don't save derived fields
			$text .= &ue($_) . '=' . &ue($userdata{$_}) . "=\015\012";
			}

		my $UserFile = "$const{'preferences folder'}accounts/$username.txt";
		$err = &WriteFile( $UserFile, $text );
		next Err if ($err);
		&Mask( $UserFile, 0 );

		&Report( &pstr( 4, $str[234] ) ) unless ($b_silent);

		last Err;
		}
	return ($err, $warnings);
	}

sub merge {
	my ($p_hash, %params) = @_;
	my ($name, $value);
	while (($name, $value) = each %params) {
		$$p_hash{ $name } = $value;
		}
	}



sub ReadFile {
	my ($filename) = @_;
	my ($err, $text) = ('', '');
	Err: {
		unless (open(FILE, "<$filename")) {
			$err = &pstr(8, $filename, $! );
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $filename, $! );
			next Err;
			}
		$text = join('', <FILE>);
		unless (close(FILE)) {
			$err = &pstr(220, &he( $filename, $!, $^E ) );
			next Err;
			}
		}
	return ($err, $text);
	}





sub WriteFile {
	my ($filename, $text) = @_;
	my $err = '';
	Err: {
		unless (open(FILE, ">$filename")) {
			$err = &extended_f_err($filename);
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $filename, $! );
			close(FILE);
			next Err;
			}
		unless (print FILE $text) {
			$err = &pstr(231, &he( $filename, $!, $^E ) );
			close(FILE);
			next Err;
			}
		unless (close(FILE)) {
			$err = &pstr(220, &he( $filename, $!, $^E ) );
			next Err;
			}
		}
	return $err;
	}

sub url_decode {
	local $_ = defined($_[0]) ? $_[0] : '';
	tr!+! !;
	s!\%([a-fA-F0-9][a-fA-F0-9])!pack('C', hex($1))!eg;
	return $_;
	}


sub WebForm {
	my ($p_hash, $p_upload_files, $temp_dir, $b_persist_files) = @_;
	my $err = '';
	Err: {
		unless ('HASH' eq ref($p_hash)) {
			$err = "invalid argument - p_hash is not a HASH reference";
			next Err;
			}
		if ($p_upload_files) {
			unless ('HASH' eq ref($p_upload_files)) {
				$err = "invalid argument - p_upload_files is not a HASH reference";
				next Err;
				}
			}
		my $global_unique_id = time() + int( 1000000 * rand() );
		my @Pairs = ();
		if (&query_env('REQUEST_METHOD') eq 'POST') {
			my $buffer = '';
			unless (defined($ENV{'CONTENT_LENGTH'})) {
				$err = "environment variable CONTENT_LENGTH not defined for POST operation";
				next Err;
				}
			unless ($ENV{'CONTENT_LENGTH'} =~ m!^(\d+)$!) {
				$err = "environment variable CONTENT_LENGTH not integer";
				next Err;
				}
			my $len = $1;
			my $ctype = &query_env('CONTENT_TYPE');
			my $boundary = '';
			my $temp_storage = '';
			my $b_is_multipart = 0;
			if ($ctype =~ m!multipart/form-data; boundary=(.*)!s) {
				$boundary = quotemeta($1);
				$b_is_multipart = 1;
				}

			my $bsize = 16384;

			if (($b_is_multipart) and ($len > 20 * $bsize)) {

				# large multi-part upload... special case write to temp file...

				$global_unique_id = 0 unless ($global_unique_id);
				$global_unique_id++;

				# create a temp file:
				my $file_num = $global_unique_id;
				for (;;) {
					last unless (-e "$temp_dir/fd_webformex_$file_num.tmp");
					$file_num++;
					}
				$temp_storage = "$temp_dir/fd_webformex_$file_num.tmp";

				unless (open(FILE, ">$temp_storage")) {
					$err = "unable to write to temp file '$temp_storage' - $! - $^E";
					next Err;
					}
				unless (binmode(FILE)) {
					$err = "unable to set binmode on temp file '$temp_storage' - $! - $^E";
					next Err;
					}

				my $remain = $len;

				my $read = 0;
				my $rv;
				my $buffer = '';


				while (1) {
					last if ($remain < 1);

					my $inc_read = $bsize;
					if ($remain < $inc_read) {
						$inc_read = $remain;
						}

					$rv = read(main::STDIN, $buffer, $inc_read, 0);
					unless (defined($rv)) {
						$err = "error while reading data over the network - $! - $^E";
						next Err;
						}
					last if ($rv == 0);

					if (length($buffer) != $rv) {
						$err = "assertion error - Perl read() function returned incorrect value; $rv";
						next Err;
						}


					$read += $rv;
					$remain -= $rv;

					unless (print FILE $buffer) {
						$err = "error while writing to temp file '$temp_storage' - $! - $^E";
						next Err;
						}
					}
				unless (close(FILE)) {
					$err = "unable to close temp file '$temp_storage' - $! - $^E";
					next Err;
					}
				}
			else {
				my $bytes_read = read(main::STDIN, $buffer, $len, 0);
				if (not (defined($bytes_read))) {
					$err = "error while reading input - $! - $^E";
					next Err;
					}
				elsif ($bytes_read != $len) {
					$err = "unable to read $len bytes from input - only read $bytes_read - $! - $^E";
					next Err;
					}
				}

			# this is to un-taint the incoming data...
			if ($buffer =~ m!^(.*)$!s) {
				$buffer = $1;
				}
			else {
				$err = "unable to untaint incoming data";
				next Err;
				}

			unless ($b_is_multipart) {

				# normal post:
				@Pairs = split(m!\&!, $buffer);



				}
			elsif ($temp_storage) {
				# okay, we have a multipart FILE UPLOAD in-temp-data-storage

				unless (open(FILE, "<$temp_storage")) {
					$err = "unable to open file '$temp_storage' - $! - $^E";
					next Err;
					}
				unless (binmode(FILE)) {
					$err = "unable to set binmode";
					next Err;
					}
				my $state = 0;
					# 1 waiting for c-d line
					# 2 waiting for blank line
					# 3 reading data
					# 4 writing data to temp file

				my $name = '';
				my $value = '';

				my $write_this = '';
				my $b_temp_is_open = 0;

				my $datalen = 0;
				while (defined($_ = <FILE>)) {
					$datalen += length($_);
					if (m!^--$boundary(--)?\015?\012?$!s) {
						$state = 1;
						$value =~ s!\015\012$!!s;
						if ($b_temp_is_open) {
							print TEMP $value;
							close(TEMP);
							my $p_data = $$p_upload_files{$name};
							$$p_data{'size'} = -s $$p_data{'temp file'};
							}
						elsif ($name) {
							if (defined($$p_hash{$name})) {
								$$p_hash{$name} .= ",$value";
								}
							else {
								$$p_hash{$name} = $value;
								}
							}
						$name = '';
						$value = '';
						$b_temp_is_open = 0;
						next;
						}
					if ($state == 1) {
						if (m!^Content-Disposition: form-data; name="(.+?)"; filename="(.*?)"\015?\012$!) {
							$name = $1;

							my %filedata = (
								'client file name' => $2,
								'temp file' => '',
								);

							# create a temp file:
							$global_unique_id = 0 unless ($global_unique_id);
							$global_unique_id++;
							my $file_num = $global_unique_id;
							for (;;) {
								last unless (-e "$temp_dir/fd_webformex_$file_num.tmp");
								$file_num++;
								}
							$filedata{'temp file'} = "$temp_dir/fd_webformex_$file_num.tmp";

							unless (open(TEMP, ">$filedata{'temp file'}")) {
								$err = "unable to open temp file '$filedata{'temp file'}' for writing - $! - $^E";
								next Err;
								}
							binmode(TEMP);

							eval "END { unlink('$filedata{'temp file'}'); }\n" unless ($b_persist_files);
							$$p_upload_files{$name} = \%filedata;

							$b_temp_is_open = 1;
							$state = 2;
							}
						elsif (m!^Content-Disposition: form-data; name="(.+?)"\015?\012?$!) {
							$value = '';
							$name = $1;
							$state = 2;
							}
						else {
							$err = "unknown Content-Disposition header received - " . &he($_);
							next Err;
							}
						next;
						}

					if (($state == 2) and (m!^Content-Type: (.*?)\015?\012?$!)) {
						if ($b_temp_is_open) {
							my $p_data = $$p_upload_files{$name};
							$$p_data{'content-type'} = $1;
							}

						}



					if (($state == 2) and (m!^\015?\012$!)) {
						if ($b_temp_is_open) {
							$state = 4;
							}
						else {
							$state = 3;
							}
						next;
						}

					if ($state == 3) {
						$value .= $_;
						}
					if ($state == 4) {
						if (length($value)) {
							unless (print TEMP $value) {
								$err = "error while writing to temp file - $! - $^E";
								next Err;
								}
							}
						$value = $_;
						}
					}
				$value =~ s!\015\012$!!s;
				if ($b_temp_is_open) {
					print TEMP $value;
					close(TEMP);
					my $p_data = $$p_upload_files{$name};
					$$p_data{'size'} = -s $$p_data{'temp file'};
					}
				elsif ($name) {
					if (defined($$p_hash{$name})) {
						$$p_hash{$name} .= ",$value";
						}
					else {
						$$p_hash{$name} = $value;
						}
					}
				close(FILE);
				unless (unlink($temp_storage)) {
					$err = "unable to delete temporary file '$temp_storage' - $! - $^E";
					next Err;
					}
				last Err;
				}
			else {

				# okay, we have a multipart FILE UPLOAD in-memory

				my @fields = split(m!$boundary!s, $buffer);
				my $x;
				for ($x = 1; $x < $#fields; $x++) {
					local $_ = $fields[$x];
					my ($name, $is_file, $filename, $value) = ('', 0, '', '');
					if (m!Content-Disposition: form-data; name="(.*?)"; filename="(.*?)"!is) {
						($name, $filename) = ($1, $2);
						$is_file = 1;
						}
					elsif (m!Content-Disposition: form-data; name="(.*?)"!is) {
						($name) = ($1);
						}
					else {
						$err = "upload data block did not contain a valid form-data name: <xmp>$_</xmp>";
						next Err;
						}

					if (m!Content-Disposition: form-data; name="$name".*?\015\012\015\012(.*)\015\012--$!is) {
						$value = $1;
						$value =~ s!\015\012$!!so;
						}
					else {
						$err = "unable to extract VALUE portion of form-data block: <xmp>$_</xmp>";
						next Err;
						}

					if (($is_file) and ($p_upload_files)) {
						my $contenttype = '';
						if (m!Content-Type:\s*(\S+)!is) {
							$contenttype = $1;
							}

						my %filedata = (
							'client file name' => $filename,
							'size' => length($value),
							'content' => "'$value'",
							'content-type' => $contenttype,
							);



						unless ($temp_dir) {
							$err = "unable to save file - temp_dir parameter not defined";
							next Err;
							}

						unless ((-e $temp_dir) and (-d $temp_dir)) {
							$err = "unable to save file - temp_dir '$temp_dir' does not exist or is not a directory";
							next Err;
							}

						$global_unique_id = 0 unless ($global_unique_id);
						$global_unique_id++;

						# create a temp file:
						my $file_num = $global_unique_id;
						for (;;) {
							last unless (-e "$temp_dir/fd_webformex_$file_num.tmp");
							$file_num++;
							}
						my $TempFile = "$temp_dir/fd_webformex_$file_num.tmp";

						$err = &WriteFile( $TempFile, $value );
						next Err if ($err);

						$filedata{'temp file'} = $TempFile;
						delete $filedata{'content'};
						# note - this will fail if $temp_dir is relative and their is a chdir later in the prog - use an absolute $temp_dir
						eval "END { unlink('$TempFile'); }\n" unless ($b_persist_files);
						$$p_upload_files{$name} = \%filedata;
						next;
						}

					if (defined($$p_hash{$name})) {
						$$p_hash{$name} .= ",$value";
						}
					else {
						$$p_hash{$name} = $value;
						}
					}

				# Done with multipart form
				last Err;
				}
			}
		elsif ($ENV{'QUERY_STRING'}) {
			@Pairs = split(m!\&!s, $ENV{'QUERY_STRING'});
			}
		else {
			@Pairs = @ARGV;
			}
		foreach (@Pairs) {
			next unless (m!^(.*?)=(.*)$!s);
			my ($name, $value) = (&url_decode($1), &url_decode($2));
			if (defined($$p_hash{$name})) {
				$$p_hash{$name} .= ",$value";
				}
			else {
				$$p_hash{$name} = $value;
				}
			}
		}

	#changed 2001-11-30
	foreach (keys %$p_hash) {
		next unless (m!^(.*)_udav$!);
		next if (defined($$p_hash{$1}));
		$$p_hash{$1} = $$p_hash{$_};
		}

	return $err;
	};

sub standard_binmode {
	my $err = '';
	Err: {
		my $OS = $^O;
		if (($OS) and ($OS =~ m!(win|dos|os2)!i)) {

			unless (binmode(main::STDIN)) {
				$err = "unable to set binmode on STDIN - $!";#notranslate
				next Err;
				}
			unless (binmode(main::STDOUT)) {
				$err = "unable to set binmode on STDOUT - $!";#notranslate
				next Err;
				}
			unless (binmode(main::STDERR)) {
				$err = "unable to set binmode on STDERR - $!";#notranslate
				next Err;
				}
			}
		}
	return $err;
	}





sub GetFiles {
	my ($FolderCount, @Folders, @Files, $Pattern) = (0);
	($Folders[0], $Pattern) = @_;
	# Format with all forward slashes; add a trailing slash to $Directory if
	# it's not present:
	$Folders[0] = &NixPath($Folders[0]);
	$Folders[0] .= '/' unless ($Folders[0] =~ m!/$!);

	while ($FolderCount < (scalar @Folders)) {
		my $Directory = $Folders[$FolderCount];
		$FolderCount++;

		unless (opendir(DIR, $Directory)) {
			&ppstr(5, &pstr(22, $Directory, $!));
			next;
			}
		foreach (readdir(DIR)) {
			next if m!^\.\.?$!; # skip current and higher directories.

			my $Path = "$Directory$_";
			if (-d $Path) {
				push(@Folders, "$Path/");
				next;
				}
			push(@Files, $Path) if ((not $Pattern) or (m!$Pattern!i));
			}
		closedir(DIR);
		}
	return @Files;
	}







sub FormatNumber {
	my ( $expression, $decimal_places, $include_leading_digit, $use_parens_for_negative, $group_digits, $euro_style ) = @_;

	my $dec_ch = ($euro_style) ? ',' : '.';
	my $tho_ch = ($euro_style) ? '.' : ',';

	my $qm_dec_ch = quotemeta( $dec_ch );

	local $_ = $expression;
	unless (m!^\-?\d*\.?\d*$!) {
		$_ = 0;
		}

	my $exp = 1;
	for (1..$decimal_places) {
		$exp *= 10;
		}
	$_ *= $exp;
	$_ = int($_);
	$_ = ($_ / $exp);

	# Add a trailing decimal divider if we don't have one yet
	$_ .= '.' unless (m!\.!);

	# Pad zero'es if appropriate:
	if ($decimal_places) {
		if (m!^(.*)\.(.*)$!) {
			$_ .= '0' x ($decimal_places - length($2));
			}
		}
	# Re-write with localized decimal divider:
	s!\.!$dec_ch!o;

	# Group digits:
	if ($group_digits) {
		while (m!(.*)(\d)(\d\d\d)(\,|\.)(.*)!) {
			$_ = "$1$2$tho_ch$3$4$5";
			}
		}
	if ($include_leading_digit) {
		s!^$qm_dec_ch!0$dec_ch!o;
		}
	# Have we somehow ended up with just a decimal point?  Make it zero then:
	if ("foo$_" eq "foo$dec_ch") {
		$_ = "0";
		}
	# Strip trailing decimal point
	s!$qm_dec_ch$!!o;
	if ($use_parens_for_negative) {
		s!^\-(.*)$!\($1\)!o;
		}
	return $_;
	}

sub FormatDateTime {
	my ($time, $format_type, $b_format_as_gmt) = @_;
	$format_type = 0 unless ($format_type);
	$format_type = 11 if ($format_type eq 'smtp');
	my $date_str = '';

	$b_format_as_gmt = 1 if ($format_type == 11); # force GMT for SMTP-formatted dates

	$time = 0 unless ($time); # force integer

	if ($format_type == 13) {

		if ($b_format_as_gmt) {
			$date_str = scalar gmtime( $time );
			}
		else {
			$date_str = scalar localtime( $time );
			}
		}
	else {

		my ($sec, $min, $milhour, $day, $month_index, $year, $weekday_index) = ($b_format_as_gmt) ? gmtime( $time ) : localtime( $time );

		$year += 1900;

		my $ampm = ( $milhour >= 12 ) ? 'PM' : 'AM';
		my $relhour = (($milhour - 1) % 12) + 1;
		my $month = $month_index + 1;

		# pad with leading zero:
		local $_;
		foreach ($milhour, $relhour, $min, $sec, $month, $day) {
			$_ = "0$_" if (1 == length($_));
			}

		my @MonthNames = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
		my @WeekNames = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

		my $full_weekday = $WeekNames[$weekday_index];
		my $short_weekday = substr($full_weekday, 0, 3);

		my $full_monthname = $MonthNames[$month_index];
		my $short_monthname = substr($full_monthname, 0, 3);

		if ($format_type == 0) {
			$date_str = "$month/$day/$year $relhour:$min:$sec $ampm";
			}
		elsif ($format_type == 1) {
			$date_str = "$full_weekday, $full_monthname $day, $year";
			}
		elsif ($format_type == 2) {
			$date_str = "$month/$day/$year";
			}
		elsif ($format_type == 3) {
			$date_str = "$relhour:$min:$sec $ampm";
			}
		elsif ($format_type == 4) {
			$date_str = "$milhour:$min";
			}
		elsif ($format_type == 10) {
			$date_str = "$short_weekday $month/$day/$year $relhour:$min:$sec $ampm";
			}
		elsif ($format_type == 11) {
			$date_str = "$short_weekday, $day $short_monthname $year $milhour:$min:$sec -0000";
			}
		elsif ($format_type == 12) {
			$date_str = "$year-$month-$day $milhour:$min:$sec";
			}
		elsif ($format_type == 14) {
			$date_str = "$month/$day/$year $milhour:$min";
			}
		}

	unless ($date_str) {
		if ($format_type !~ m!^\d+$!) {
			$date_str = "invalid argument to FormatDateTime(); second parameter '" . &he($format_type) . "' not numeric";
			}
		elsif (($format_type > 14)) {
			$date_str = "invalid argument to FormatDateTime(); second parameter format_type must be integer less than 15; received $format_type";
			}
		}


	return $date_str;
	}






sub NixPath {
	local $_ = defined($_[0]) ? $_[0] : '';
	s!\\!/!mg;
	return $_;
	}

sub SetDefaults {
	my ($text, $p_params) = @_;

	# short-circuit:
	if ((ref($p_params) ne 'HASH') or (not (%$p_params))) {
		return $text;
		}


	my @array = split(m!<(INPUT|SELECT|TEXTAREA)([^\>]+?)\>!is, $text);

	my $finaltext = $array[0];

	my $setval;

	my $x = 1;
	for ($x = 1; $x < $#array; $x += 3) {

		my ($uctag, $origtag, $attribs, $trail) = (uc($array[$x]), $array[$x], $array[$x+1] || '', $array[$x+2] || '');

		Tweak: {

			my $tag_name = '';
			if ($attribs =~ m! NAME\s*=\s*\"([^\"]+?)\"!is) {
				$tag_name = $1;
				}
			elsif ($attribs =~ m! NAME\s*=\s*(\S+)!is) {
				$tag_name = $1;
				}
			else {

				# we cannot modify what we do not understand:
				last Tweak;
				}
			last Tweak unless (defined($$p_params{$tag_name}));
			$setval = &he($$p_params{$tag_name});


			if ($uctag eq 'INPUT') {

				# discover VALUE and TYPE
				my $type = 'TEXT';
				if ($attribs =~ m! TYPE\s*=\s*\"([^\"]+?)\"!is) {
					$type = uc($1);
					}
				elsif ($attribs =~ m! TYPE\s*=\s*(\S+)!is) {
					$type = uc($1);
					}

				# discover VALUE and TYPE
				my $value = '';
				if ($attribs =~ m! VALUE\s*=\s*\"([^\"]+?)\"!is) {
					$value = $1;
					}
				elsif ($attribs =~ m! VALUE\s*=\s*(\S+)!is) {
					$value = $1;
					}

				# we can only set values for known types:

				if (($type eq 'RADIO') or ($type eq 'CHECKBOX')) {

					#changed 2001-11-15; strip pre-existing checks
					$attribs =~ s! (checked="checked"|checked)($| )!$2!ois;

					if ($setval eq $value) {
						$attribs = qq! checked="checked"$attribs!;
						}

					}
				elsif (($type eq 'TEXT') or ($type eq 'PASSWORD') or ($type eq 'HIDDEN')) {

					# but only hidden fields if value is null:

					last Tweak if (($type eq 'HIDDEN') and ($value ne ''));

					# replace any existing VALUE tag:
					my $qm_value = quotemeta($value);
					$attribs =~ s! value\s*=\s*\"$qm_value\"! value="$setval"!iso;
					$attribs =~ s! value\s*=\s*$qm_value! value="$setval"!iso;

					# add the tag if it's not present (i.e. if no VALUE was present in original tag)
					my $qm_setval = quotemeta($setval);
					unless ($attribs =~ m! VALUE="$qm_setval"!is) {
						$attribs = " value=\"$setval\"$attribs";
						}

					}
				}
			elsif ($uctag eq 'SELECT') {

# does not support <OPTION>value syntax, only <OPTION VALUE="value">value

				my $lc_set_value = lc($setval);

				my @frags = ();
				foreach (split(m!<option!is, $trail)) {

					#changed 2001-11-15; strip pre-existing "selected"
					$_ =~ s! (selected|selected="selected")($| )!$2!ois;

					if (m!VALUE\s*=\s*\"(.*?)\"!is) {
						if ($lc_set_value eq lc($1)) {
							$_ = ' selected="selected"' . $_;
							}
						}
					elsif (m!VALUE\s*=\s*(\S+)!is) {
						if ($lc_set_value eq lc($1)) {
							$_ = ' selected="selected"' . $_;
							}
						}
					push(@frags, $_);
					}
				$trail = join('<option', @frags);
				}
			elsif ($uctag eq 'TEXTAREA') {
				$trail =~ s!^.*?</(textarea)>!$setval</$1>!osi;
				}
			last Tweak;
			}

		$finaltext .= "<$origtag$attribs>$trail";
		}
	return $finaltext;
	}


sub where_tf {
	my $err = '';
	my @paths = ();
	Err: {
		local $_;

		my $abs_file_path = '';

		foreach ($file_path_to_script, $0, &query_env('SCRIPT_FILENAME'), &query_env('PATH_TRANSLATED')) {
			next if (m!^./!); # local paths won't be sufficient
			next if (m!safeperl\d*$!i);
			s!\\!/!g;
			next unless (m!/|:!);
			$abs_file_path = $_;
			last;
			}

		unless ($abs_file_path) {
			$err = "unable to determine absolute file path - \$0 or SCRIPT_FILENAME or PATH_TRANSLATED not defined";#notranslate
			next Err;
			}
		unless (-e $abs_file_path) {
			$err = "file discovery returned '$abs_file_path' as absolute file path, but -e existence check failed";#notranslate
			next Err;
			}
		if ($abs_file_path =~ m!^./!) {
			$err = "file discovery returned local path '$abs_file_path' - an absolute path is needed";
			next Err;
			}
		if (-d $abs_file_path) {
			my $test = $abs_file_path . &query_env('SCRIPT_NAME');
			$test =~ s!\\!/!g;
			if ((-e $test) and (not -d $test)) {
				$abs_file_path = $test;
				}
			}
		# untaint - we'll already done all of the file existence checks:
		if ($abs_file_path =~ m!^(.+)$!) {
			$abs_file_path = $1;
			}


		my $abs_url = $web_path_to_script;
		my $script_name = &query_env('SCRIPT_NAME','/');

		unless ($abs_url) {
			foreach ('HTTP_HOST', 'SERVER_NAME') {
				my $var = &query_env($_);
				next unless ($var);
				$abs_url = "http://$var$script_name";
				last;
				}
			}
		unless ($abs_url) {
			my $http_referer = &query_env('HTTP_REFERER');
			if ($http_referer) {
				$abs_url = $http_referer;
				$abs_url =~ s!(\?|\$\|\#)(.*)!!o;
				}
			}

		unless ($abs_url) {
			$err = "unable to determine absolute file path - HTTP_HOST or SERVER_NAME or HTTP_REFERER not defined";#notranslate
			next Err;
			}

		my $qm_rel_url = '';
		if ($abs_url =~ m!^http://([^/]+)/(.*?)$!) {
			$qm_rel_url = quotemeta($2);
			}

		$paths[0] = $paths[1] = $paths[2] = &NixPath($abs_file_path);
		$paths[1] =~ s!/([^/]+)$!!o;
		$paths[2] =~ s!/$qm_rel_url!!o;

		$paths[3] = $abs_url;
		$paths[4] = $abs_url;
		$paths[5] = $abs_url;

		$paths[4] =~ s!/([^/]+)$!!o;
		$paths[5] =~ s!/$qm_rel_url!!o;

		last Err;
		}
	return ($err, @paths);
	}





sub Trim {
	local $_ = defined($_[0]) ? $_[0] : '';
	s!^[\r\n\s]+!!o;
	s![\r\n\s]+$!!o;
	return $_;
	}





sub web_auth_new {
	my %options = @_;
	my $self = {};
	bless($self);

	$self->{'data_folder'} = '.';
	$self->{'make_starter_accounts'} = 0;
	$self->{'seed'} = 'sX';
	my ($name, $value) = ();
	while (($name, $value) = each %options) {
		$self->{$name} = $value;
		}
	$self->{'data_folder'} =~ s!\\!/!g;
	$self->{'data_folder'} .= '/';
	$self->{'data_folder'} =~ s!/+$!/!o; #changed 0017 - collapse trailing slashes
	$self->{'AuthFile'} = $self->{'data_folder'} . '.webauth_passwd';
	$self->{'TokenFile'} = $self->{'data_folder'} . '.webauth_tokens';
	return $self;
	}





sub InventPassword {
	my ($self) = @_;
	my $NewPassword = '';
	my @consonants = ('b', 'c', 'd', 'f', 'g', 'h', 'j', 'k','l', 'm', 'n', 'p','q', 'r', 's', 't', 'v','w','y','x','z');
	my $s_c = scalar @consonants;
	$NewPassword .= $consonants[int($s_c * rand())];
	$NewPassword .= ('a','e','i','o','u')[int(5 * rand())];
	$NewPassword .= $consonants[int($s_c * rand())];
	$NewPassword .= $consonants[int($s_c * rand())];
	$NewPassword .= ('a','e','i','o','u')[int(5 * rand())];
	$NewPassword .= $consonants[int($s_c * rand())];
	$NewPassword .= 10 + int(89 * rand());
	return $NewPassword;
	}





sub DeleteUser {
	my ($self, $username, $b_flush_tokens) = @_;
	my $err = '';
	Err: {
		my $file = $self->{'AuthFile'};
		my $text = '';
		if (-e $file) {
			unless (open(FILE, "<$file")) {
				$err = &pstr(8, $file, $! );
				next Err;
				}
			unless (binmode(FILE)) {
				$err = &pstr(12, $file, $! );
				next Err;
				}
			while (<FILE>) {
				next unless (m!^(.*?)\:(.*?)\r?$!);
				my ($user, $crypt) = ($1, $2);
				next if ($user eq $username);
				$text .= "$user:$crypt\n";
				}
			close(FILE);
			}
		unless (open(FILE, ">$file")) {
			$err = &extended_f_err($file);
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $file, $! );
			next Err;
			}
		print FILE $text;
		close(FILE);
		if ($b_flush_tokens) {
			$err = $self->flush_tokens( $username );
			next Err if ($err);
			}

		}
	return $err;
	}





sub SetPassword {
	my ($self, $username, $password) = @_;
	my $err = '';
	Err: {
		if (($const{'mode'} == 0) and ($username eq $private{'super user'})) {
			$err = &pstr(200,$username);
			next Err;
			}


		my $file = $self->{'AuthFile'};
		my $crypt = crypt($password, $self->{'seed'});
		$err = $self->DeleteUser( $username, 0 );
		next Err if ($err);
		unless (open(FILE, ">>$file")) {
			$err = &pstr(10, $file, $! );
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $file, $! );
			next Err;
			}
		print FILE "$username:$crypt\n";
		close(FILE);
		}
	return $err;
	}





sub ValidatePassword {
	my ($self, $username, $password) = @_;
	my $is_valid = 0;
	my $err = '';
	Err: {
		local $_;
		my $file = $self->{'AuthFile'};
		unless (open(FILE, "<$file")) {
			$err = &pstr(8, $file, $! );
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $file, $! );
			next Err;
			}
		while (defined($_ = <FILE>)) {
			next unless (m!^(.*?)\:(.*?)\r?$!);
			my ($user, $crypt) = ($1, $2);
			if ($user eq $username) {
				if ($crypt eq crypt($password, $self->{'seed'})) {
					$is_valid = 1;
					}
				else {
					sleep(3);
					}
				last;
				}
			}
		close(FILE);
		}
	return ($err, $is_valid);
	}





sub logout {
	my ($self) = @_;
	return ($self->Challenge( 0, 1 ))[4];
	}





sub Challenge {
	my ($self, $p_FORM, $b_logout) = @_;

	my $html_out = '';

	my $trace = '';

	my ($private_token, $public_token, $form_username, $form_password) = ('', '', '', '');

	my $test_cookie = '0';
	my $is_cookies_aware = 0;
	my $http_cookie = &query_env('HTTP_COOKIE');
	if ($http_cookie =~ m!web_auth_cp=([^\;]+)!) {
		$is_cookies_aware = 1;
		my $auth_cookie = $1;
		if ($auth_cookie ne $test_cookie) {
			$private_token = $auth_cookie;
			}
		}
	if (($p_FORM) and ('HASH' eq ref($p_FORM))) {
		if ($$p_FORM{'web_auth_cp'}) {
			$private_token = $$p_FORM{'web_auth_cp'};
			}
		if ($$p_FORM{'web_auth_user'}) {
			$form_username = $$p_FORM{'web_auth_user'};
			}
		if ($$p_FORM{'web_auth_pass'}) {
			$form_password = $$p_FORM{'web_auth_pass'};
			}
		}

	my ($is_auth, $auth_username) = (0, '');

	my $script_name = &query_env('SCRIPT_NAME',$0);

	my $session_lifetime = 3600; # 1 hour
	my $grace_period = 600; # 10 min

	my ($status_msg, %auth_tokens) = ('');


	my $clear_cookie = 0;

	my $present_auth_form = 1;
	my $err = '';
	Err: {



		if ($self->{'make_starter_accounts'}) {
			unless (-e $self->{'AuthFile'}) {
				$err = $self->SetPassword( $private{'super user'}, '658uwantit' );
				if ($err) {
					$present_auth_form = 0;
					next Err;
					}
				}
			}


		next Err if ($b_logout);



		if (($form_username) and ($form_password)) {

			my $is_valid = 0;
			($err, $is_valid) = $self->ValidatePassword( $form_username, $form_password );
			next Err if ($err);

			unless ($is_valid) {
				$err = $str[33];
				next Err;
				}

			# the user provided a valid password; give that man a token!

			$err = $self->read_tokens( \%auth_tokens );
			next Err if ($err);

			$private_token = '';
			foreach (1..16) {
				$private_token .= chr(ord('a') + int(rand(26)));
				}
			$public_token = crypt($private_token, $self->{'seed'});
			my $expires = time() + $session_lifetime;
			$auth_tokens{$public_token} = "$expires,$form_username";

			$err = $self->write_tokens( \%auth_tokens );
			next Err if ($err);

			$auth_username = $form_username;
			$is_auth = 1;
			last Err;
			}



		if ($private_token) {

			$err = $self->read_tokens( \%auth_tokens );
			next Err if ($err);

			$public_token = crypt($private_token, $self->{'seed'});
			unless ($auth_tokens{$public_token}) {
				sleep(3);
				$err = $str[31];
				next Err;
				}

			$auth_tokens{$public_token} =~ m!^(\d+),(.*)$!;
			my ($expires, $username) = ($1, $2);

			if ($expires < time()) {
				my $ago = time() - $expires;
				$clear_cookie = 1 if ($is_cookies_aware);
				$err = $str[32];
				next Err;

				}
			elsif (($expires - $grace_period) < time) {

				# this token is about to expire; set a fresh one:

				$private_token = '';
				foreach (1..8) {
					$private_token .= chr(ord('a') + int(rand(26)));
					}
				$public_token = crypt($private_token, $self->{'seed'});

				$expires = time() + $session_lifetime;
				$auth_tokens{$public_token} = "$expires,$username";

				$err = $self->write_tokens( \%auth_tokens );
				next Err if ($err);

				}
			else {
				# is current token
				}

			$is_auth = 1;
			$auth_username = $username;

			last Err;

			}
		}

	continue {

		my $status_msg = '';

		if ($b_logout) {
			$status_msg = &pstr(4,$str[30]);
			}
		elsif ($err) {
			$status_msg = &pstr(6,$err);
			}



		# AUTH_FAIL

		print "Set-Cookie: web_auth_cp=; path=$script_name\015\012" if ($clear_cookie);
		print "Set-Cookie: web_auth_cp=$test_cookie; path=$script_name\015\012";

		my ($v1, $v2) = ('', '');
		if ($const{'mode'} == 0) {
			$v1 = $private{'super user'};
			$v2 = "658uwantit";
			}

$html_out = <<"EOM";

		<form method="post" action="$script_name" name="F1">

EOM

		unless ($b_logout) {
			my ($name, $value) = ();
			while (($name, $value) = each %$p_FORM) {
				next if ($name =~ m!^web_auth_!i);
				next if (uc($value) eq 'LOGOUT');
				$html_out .= "<input type=\"hidden\" name=\"" . &he($name) . "\" value=\"" . &he($value) . "\" />\n";
				}
			}

if ($present_auth_form) {
$html_out .= <<"EOM";

		<p>$str[35]:</p>
		<table border="0">
			<tr>
				<td align="right"><b>$str[36]:</b></td>
				<td><input name="web_auth_user" value="$v1" /></td>
			</tr><tr>
				<td align="right"><b>$str[37]:</b></td>
				<td><input type="password" name="web_auth_pass" value="$v2" /></td>
			</tr><tr>
				<td><br /></td>
				<td><input type="submit" class="submit" value="$str[48]" /></td>
			</tr>
		</table>
		</form>
		<script type="text/javascript">
		<!--
		if ((document) && (document.F1) && (document.F1.web_auth_user)) {
			document.F1.web_auth_user.focus();
			}
		// -->
		</script>

EOM
	}
else {
	$html_out .= "<p>$str[199]</p>\n";
	}
$html_out .= <<"EOM";

		$status_msg

EOM

		}

	if ($is_auth) {
		print "Set-Cookie: web_auth_cp=$private_token; path=$script_name\015\012";
		}

	return ($is_auth, $private_token, $auth_username, $is_cookies_aware, $html_out);
	}





sub flush_tokens {
	my ($self, $pattern) = @_;
	my $err = '';
	Err: {
		my %auth_tokens = ();
		unless ($pattern) {
			$err = $self->write_tokens( \%auth_tokens );
			last Err;
			}

		$err = $self->read_tokens( \%auth_tokens );
		next Err if ($err);

		my @public_tokens = keys %auth_tokens;
		foreach (@public_tokens) {
			next unless ($auth_tokens{$_} =~ m!^(\d+),(.*)$!);
			my ($expires, $username) = ($1, $2);
			if ($username =~ m!$pattern!i) {
				delete $auth_tokens{$_};
				}
			}

		$err = $self->write_tokens( \%auth_tokens );
		next Err if ($err);

		}
	return $err;
	}




sub read_tokens {
	my ($self, $p_Tokens) = @_;
	my $err = '';
	Err: {
		my $file = $self->{'TokenFile'};
		last Err unless (-e $file);
		unless (open(FILE, "<$file")) {
			$err = &pstr(8, $file, $! );
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $file, $! );
			next Err;
			}
		my $buffer = '';
		my $time = time();
		while (read(FILE, $buffer, 128)) {
			my ($token, $expires, $username) = unpack('A60LA64', $buffer);
			next if ($expires < $time);
			$$p_Tokens{$token} = "$expires,$username";
			}
		close(FILE);
		}
	return $err;
	}





sub write_tokens {
	my ($self, $p_Tokens) = @_;
	my $err = '';
	Err: {
		my $file = $self->{'TokenFile'};
		unless (open(FILE, ">$file")) {
			$err = &extended_f_err($file);
			next Err;
			}
		unless (binmode(FILE)) {
			$err = &pstr(12, $file, $! );
			next Err;
			}
		my ($name, $value) = ();
		while (($name, $value) = each %$p_Tokens) {
			next unless ($value =~ m!^(\d+)\,(.*)$!);
			my ($expires, $username) = ($1, $2);
			print FILE pack('A60LA64', $name, $expires, $username);
			}
		close(FILE);
		}
	return $err;
	}



sub ParseTemplate {
	my ( $file, $start_folder, $p_replace, $p_cache, $p_visited, $b_no_parse_ssi) = @_;

	$start_folder = '.' unless ($start_folder);

	my $return_text = '';

	my $err = '';
	Err: {

		# Initialize:
		unless ($p_replace) {
			$p_replace = {};
			}
		unless ($p_visited) {
			$p_visited = {};
			}


		# Query the cache for the text of the document, or search the filesystem for the file:

		my $text = '';
		my $basename = '';
		if (($p_cache) and ('HASH' eq ref($p_cache)) and (defined($$p_cache{$file}))) {
			$text = $$p_cache{$file};
			}
		else {
			my $fullfile = '';
			my $max_parents = 12;
			for (0..$max_parents) {
				$fullfile = $start_folder . '/' . ('../' x $_) . $file;
				$fullfile = &fs_path($fullfile);
				$fullfile =~ s!/+!/!g;
				last if (-e $fullfile);
				}
			unless (-e $fullfile) {
				$err = "unable to find file '$file'";
				next Err;
				}
			if ($fullfile =~ m!([^\\|/]+)$!) {
				$basename = $1;
				$$p_visited{$basename} = 1;
				}
			($err, $text) = &ReadFile( $fullfile );
			next Err if ($err);
			if (($p_cache) and ('HASH' eq ref($p_cache))) {
				$$p_cache{$file} = $text;
				}
			}


		# Handling replacement value substitutions:

		#conditionals
		foreach (reverse sort keys %$p_replace) {
			next unless (defined($_));
			$$p_replace{$_} = '' if (not defined($$p_replace{$_}));
			if ($$p_replace{$_}) {
				# true
				$text =~ s!<%\s*if\s+$_\s*%>(.*?)<%\s*end\s*if\s*%>!$1!eisg;
				$text =~ s!<%\s*(if\s+not|unless)\s+$_\s*%>.*?<%\s*end\s*if\s*%>!!isg;
				}
			else {
				# false
				$text =~ s!<%\s*if\s+$_\s*%>.*?<%\s*end\s*if\s*%>!!isg;
				$text =~ s!<%\s*(if\s+not|unless)\s+$_\s*%>(.*?)<%\s*end\s*if\s*%>!$2!isg;
				}
			}

		foreach (reverse sort keys %$p_replace) {
			$text =~ s!\%$_\%!$$p_replace{$_}!isg;
			}

		if ($b_no_parse_ssi) {
			$return_text = $text;
			}
		else {
			# Now that replacement values are done, parse SSI tags and include files:

			my $pattern = '<!--#(include\s+file|include\s+virtual|echo\s+var)\s*=\s*\"(.*?)\"\s+-->';
			while ($text =~ m!^(.*?)$pattern(.*)$!is) {
				my ($start, $c1, $incfile, $end) = ($1, lc($2), $3, $4);

				$return_text .= $start;

				if ($c1 =~ m!echo\s+var!i) {
					my $var = uc($incfile);
					if ($var eq 'DATE_GMT') {
						$return_text .= scalar gmtime();
						}
					elsif ($var eq 'DATE_LOCAL') {
						$return_text .= scalar localtime();
						}
					elsif ($var eq 'DOCUMENT_NAME') {
						$return_text .= $1 if ($0 =~ m!([^\\|/]+)$!);
						}
					elsif ($var eq 'DOCUMENT_URI') {
						$return_text .= $ENV{'SCRIPT_NAME'};
						}
					elsif ($var eq 'LAST_MODIFIED') {
						$return_text .= scalar localtime( (stat($0))[9] );
						}
					elsif (defined($ENV{$var})) {
						$return_text .= $ENV{$var};
						}
					else {
						$return_text .= "<!--#echo var=\"$incfile\" -->"; # passthru
						}
					}
				else {

					my $basefile = $incfile;
					if ($incfile =~ m!.*(\\|/)(.*?)$!) {
						$basefile = $2;
						}

					# allow only approved file extensions:

					my $ok_list = 'txt|htm|html|shtml|stm|inc|css';
					if ($basefile !~ m!\.($ok_list)$!i) {
						$return_text .= "<!-- ParseTemplate: not including file '$incfile' because extension not in set '$ok_list' -->";
						}
					elsif ($$p_visited{$basefile}) {
						$return_text .= "<!-- ParseTemplate: loop avoidance: already parsed file '$basefile' somewhere in my ancestor tree -->";
						}
					else {
						$return_text .= &ParseTemplate($incfile, $start_folder, $p_replace, $p_cache, $p_visited, $b_no_parse_ssi );
						}
					}
				$text = $end;
				}
			$return_text .= $text;
			delete $$p_visited{$basename} if ($basename);
			}
		last Err;
		}
	continue {
		$return_text .= &pstr(6, $err );
		}
	return $return_text;
	}







sub fs_path {
	local $_ = defined($_[0]) ? $_[0] : '';

	# trim whitespace:
	$_ = &Trim($_);

	s!\\!/!g;

	# strip pound signs and all that follows (links internal to a page)
	s!\#.*$!!;

	# map trailing "/." to "/"
	s!/+\.$!/!g;


	# collapase // to /
	if (m!^//!) {
		# is unc path:
		s!/+!/!g;
		$_ = "/$_";
		}
	else {
		s!/+!/!g;
		}

	# map "something/.." to ""

	unless ((m!^/!) or (m!^\w\:!)) {
		$_ = "./$_";
		}

	my $new = '';
	while (m!^(.*?)([^/]+)/\.\./(.*?)$!) {
		$_ = $3;
		if (($2 eq '..') or ($2 eq '.')) {
			$new .= "$1/$2/../";
			}
		else {
			$new .= "$1";
			}
		}
	$new .= $_;
	$_ = $new;

	# map "../something" to ""

	$new = '';
	while (m!^(.*?)/\.\./([^/]+)/(.*?)$!) {
		$_ = $3;
		if (($2 eq '..') or ($2 eq '.')) {
			$new .= "$1/../$2/";
			}
		else {
			$new .= "$1";
			}
		}
	$new .= $_;
	$_ = $new;


	# map trailing /.. to /

	s!^/+\.\.$!/!;

	s!([^/]+)/+\.\.$!!o;

	# map "/./" to "/"
	s!/+\./+!/!g;

	return $_;
	}





sub pstr {
	local $_ = $str[$_[0]];
	my $x = 0;
	foreach $x (1..((scalar @_) - 1)) {
		my $c = (s!\$s$x!$_[$x]!g);
		}
	return $_;
	}





sub ppstr {
	local $_ = $str[$_[0]];
	my $x = 0;
	foreach $x (1..((scalar @_) - 1)) {
		my $c = (s!\$s$x!$_[$x]!g);
		}
	print;
	}





sub pppstr {
	local $_ = $str[$_[0]];
	my $x = 0;
	foreach $x (1..((scalar @_) - 1)) {
		my $c = (s!\$s$x!$_[$x]!g);
		}
	if ($const{'is_cmd'}) {
		print "\n$_\n";
		}
	else {
		print "<p>" . $_ . "</p>\n";
		}
	}


sub loadlang {
	my ($lang, $p_str, $b_partial) = @_;
	my $err = '';
	Err: {

		if ((not defined($lang)) or ($lang eq '')) {
			$err = "invalid argument; subroutine loadlang called will null string";
			my ($package, $file, $line) = &he(caller());
			$err .= "<!-- package $package; file $file line $line -->";
			next Err;
			}

		my $full = "$const{'preferences folder'}templates/$lang";
		unless (-e $full) {
			my $f = &he($full);
			$err = "folder '$f' does not exist";
			next Err;
			}
		unless (-d $full) {
			my $f = &he($full);
			$err = "folder '$f' does not exist as a folder";
			next Err;
			}
		unless (-e "$full/strings.txt") {
			my $f = &he($full);
			$err = "language folder '$f' does not contain a strings.txt file";
			next Err;
			}



		# Pull in the language settings:
		my $file = "$const{'preferences folder'}templates/$lang/strings.txt";

		my @new = (''); # Initialize with a null element
		unless (open(FILE, "<$file")) {
			$err = "unable to read from file '$file' - $!";#notranslate
			next Err;
			}
		binmode(FILE);
		local $_;
		while (defined($_ = <FILE>)) {
			s!\015|\012!!sg;
			push(@new,$_);
			if ($b_partial) {
				last if ($#new > 10);
				}
			}
		close(FILE);
		if ($new[1] =~ m!^VERSION (\d+\.\d+\.\d+\.\d+)$!) {
			my $strings_version = $1;
			if ($strings_version ne $VERSION) {
				$err = "strings '$file' is version $strings_version, but this script is version $VERSION. Versions much match";#notranslate
				next Err;
				}
			}
		else {
			my $f = &he($full);
			$err = "strings.txt file in language folder '$f' did not start with required VERSION $VERSION block; instead contained the following:</p><p>" . &text_to_html( join("\n", @new[0..5] ), 1 ) . "</p><p>.end";
			next Err;
			}

		@$p_str = @new;
		last Err;
		}
	return $err;
	}

sub render_h {
	my ($self, $index, @params) = @_;
	return $self->render($index, &he(@params));
	}

sub render {
	my ($self, $index, @params) = @_;
	local $_ = '';
	Err: {
		$_ = $index;
		my $x = 0;
		while (defined($params[$x])) {
			my $value = $params[$x];
			$x++;
			my $c = (s!\$s$x!$value!sg);
			# optional error handling if $c == 0 (no replacements made)
			}
		last Err;
		}
	return $_;
	}

sub load_best_values {
	my ($p_schema, $p_hash) = @_;
	my %finish = ();
	my @errors = ();
	my $err = '';
	Err: {
		my ($key, $err_key);
		foreach $key (keys %$p_schema) {
			my $p_valid = $$p_schema{$key};
			$err_key = &fd_validate( $$p_hash{$key}, @$p_valid );
			if ($err_key) {
				push( @errors, $err_key );
				$finish{$key} = $$p_valid[4];
				}
			else {
				$finish{$key} = $$p_hash{$key};
				}
			}
		last Err;
		}
	if (@errors) {
		my ($first, $last) = ( $str[6], '');
		if ($first =~ m!^(.*)\$s1(.*)$!) {
			($first, $last) = ($1, $2);
			}
		$err = join( "$last$first", @errors );
		}
	return ($err, %finish);
	}

sub validate_hash {
	my ($p_schema, $p_hash, $b_full) = @_;
	my $err = '';
	Err: {
		my $key;
		foreach $key (keys %$p_schema) {
			next if ((not $b_full) and (not defined($$p_hash{$key})));
			$err = &fd_validate( $$p_hash{$key}, @{ $p_schema->{$key} } );
			next Err if ($err);
			}
		last Err;
		}
	return $err;
	}

sub fd_validate($$$$$);
sub fd_validate($$$$$) {
	my ($value, $type, $min, $max, $name) = @_;
	my $err = '';
	Err: {
		$type = 'any' unless (defined($type));
		if ($type =~ m!^\d+$!) {
			$type = ('int', 'real', 'string', 'email', 'hostname', 'regex', 'bool')[$type];
			}

		# type == undef()/any means that anything goes:

		last Err if ($type eq 'any');


		my %types = (
			'int' => 1,
			'real' => 2,
			'string' => 3,
			'email' => 4,
			'hostname' => 5,
			'regex' => 6,
			'bool' => 7,
			'file' => 8,
			'folder' => 9,
			'http_url' => 10,
			'string_p' => 11,
			);

		unless ($types{$type}) {
			$err = $fd_lang->render_h( 'unknown type $s1', $type );
			next Err;
			}



		# undefined values are acceptable if and only if the $min param is also undef()

		if (not defined($value)) {
			if (not defined($min)) {
				last Err;
				}
			else {
				$err = $fd_lang->render( 'received undefined value' );
				next Err;
				}
			}

		# from here on out, we are guaranteed that $value is defined

		if (($type eq 'int') or ($type eq 'real')) {
			# integer or real-number
			$value =~ s!^\+!!;
			}



		# store value length for later checks:

		my $vlen = length($value);


		# under what conditions can the value *not* be blank?
		#	if int, real, bool
		# or
		#	if $min is defined and $min > 0

		if ($vlen == 0) {
			if (($type =~ m!^(int|real|bool)$!) or ($min)) {
				$err = $fd_lang->render( 'value cannot be blank' );
				next Err;
				}
			else {
				last Err;
				}
			}

		# what are the system maximum string limits?

		my %sys_max = (
			'email' => 255,
			'hostname' => 255,
			'regex' => 65535,
			'file' => 255,
			'folder' => 255,
			);

		if (($sys_max{$type}) and ($sys_max{$type} < $vlen)) {
			$err = $fd_lang->render( 'value is $s1 characters long but the maximum supported by this software is $s2 characters', $vlen, $sys_max{$type} );
			next Err;
			}


		if (($type eq 'int') or ($type eq 'real')) {
			# integer or real-number

			if ($type eq 'int') {
				unless ($value =~ m!^(\-?\d+)$!) {
					$err = $fd_lang->render( 'must be of the format "$s1"', 'ddd' );
					next Err;
					}
				}
			else {
				unless ($value =~ m!^-?\d*\.?\d*$!) {
					$err = $fd_lang->render( 'must be of the format "$s1"', 'dd.dd' );
					next Err;
					}
				}
			if (defined($min)) {
				if ($value < $min) {
					$err = $fd_lang->render( 'minimum acceptable value is $s1', $min );
					next Err;
					}
				}
			if (defined($max)) {
				if ($value > $max) {
					$err = $fd_lang->render( 'maximum acceptable value is $s1', $max );
					next Err;
					}
				}
			last Err;
			}

		elsif ($type eq 'string') {
			if ((defined($min)) and ($min > $vlen)) {
				$err = $fd_lang->render( 'string is $s1 characters, but minimum acceptable length is $s2 characters', $vlen, $min );
				next Err;
				}
			if ((defined($max)) and ($max < $vlen)) {
				$err = $fd_lang->render( 'string is $s1 characters, but maximum acceptable length is $s2 characters', $vlen, $max );
				next Err;
				}
			}
		elsif ($type eq 'string_p') {
			# string-plain; cannot contain HTML
			if ((defined($min)) and ($min > $vlen)) {
				$err = $fd_lang->render( 'string is $s1 characters, but minimum acceptable length is $s2 characters', $vlen, $min );
				next Err;
				}
			if ((defined($max)) and ($max < $vlen)) {
				$err = $fd_lang->render( 'string is $s1 characters, but maximum acceptable length is $s2 characters', $vlen, $max );
				next Err;
				}
			if ($value =~ m!\&|\>|\<|\"!s) {
				$err = $fd_lang->render( 'string cannot contain any of the following four characters: &amp; &lt; &gt; &quot' );
				next Err;
				}
			}
		elsif ($type eq 'email') {
			unless ($value =~ m!^(.+?)\@(.+?)$!) {
				$err = $fd_lang->render( 'must be of the format "$s1"', 'user@host' );
				next Err;
				}
			my $domain = $2;
			if ($domain =~ m![^a-zA-Z0-9\.\-]!) {
				$err = "host portion contains characters outside the allowed character set of A-Z, 0-9, '.' and '-'";
				next Err;
				}
			if ($value =~ m!\s!) {
				$err = 'value cannot contain whitespace';
				next Err;
				}
			if (($value =~ m!\.([^\.]+)$!) and (2 < length($1))) {
				my $tld = quotemeta(lc($1));
				unless (' biz com edu info int museum net org gov mil ' =~ m! $tld !) {
					$err = $fd_lang->render_h( 'unrecognized top-level domain "$s1"', $tld );
					next Err;
					}
				}
			}
		elsif ($type eq 'hostname') {
			if ($value =~ m![^a-zA-Z0-9\.\-]!) {
				$err = "value contains characters outside the allowed character set of A-Z, 0-9, '.' and '-'";
				next Err;
				}
			if ($max) {
				my $addr = (gethostbyname($value))[4];
				unless (defined($addr)) {
					$err = "value could not be resolved to an IP address; check for proper spelling";
					next Err;
					}
				}
			}
		elsif ($type eq 'regex') {
			if ($value =~ m!\?\{!) {
				$err = 'regular expression contains illegal ?{} code-executing regular expression';
				next Err;
				}
			eval '"foo" =~ m!$value!;';
			if ($@) {
				$err = 'regular expression cannot be evaluated - ' . &he($@);
				eval '1;'; # used to set $@ back to ''
				next Err;
				}
			}
		elsif ($type eq 'bool') {
			unless (($value eq '0') or ($value eq '1')) {
				$err = $fd_lang->render( 'value must be either "0" or "1"' );
				next Err;
				}
			}
		elsif ($type eq 'file') {
			if ((defined($min)) and ($max)) {
				unless (-e $value) {
					$err = $fd_lang->render( 'file does not exist' );
					next Err;
					}
				if (-d $value) {
					$err = $fd_lang->render( 'path points to a folder; must point to a normal file' );
					next Err;
					}
				}
			}
		elsif ($type eq 'folder') {
			if ((defined($min)) and ($max)) {
				unless (-e $value) {
					$err = $fd_lang->render( 'folder does not exist' );
					next Err;
					}
				unless (-d $value) {
					$err = $fd_lang->render( 'path points to a file; must point to a folder' );
					next Err;
					}
				}
			}
		elsif ($type eq 'http_url') {
			if (defined($min)) {
				unless ($value =~ m!^http://.+$!) {
					$err = $fd_lang->render( 'must be of the format "$s1"', 'http://host.tld/path/' );
					next Err;
					}
				}
			}
		else {
			$err = $fd_lang->render_h( 'validation data type "$s1" not defined', $type );
			last Err;
			}
		last Err;
		}
	continue {

		my %type_names = (
			'int' => 'integer value',
			'real' => 'real number value',
			'string' => 'string',
			'email' => 'email address',
			'hostname' => 'hostname value',
			'file' => 'file',
			'folder' => 'folder',
			'regex' => 'Perl regular expression',
			);
		my $type_name = $type_names{$type} || 'value';


		$err = $fd_lang->render( '$s1 failed validation; $s2', $type_name, $err );

		my $h_value = &he($value);
		if ($h_value) {
			$err =~ s!$type_name !$type_name '$h_value' !;
			}
		if ($name) {
			$err =~ s!$type_name !$type_name '$name' !;
			}
		#$err .= $fd_lang->render( '.</p><p><b>Caller:</b> package $s1; file $s2 line $s3', caller() );
		}
	return $err;
	}

sub ue(@);
sub ue(@) {
	my @out = @_;
	local $_;
	foreach (@out) {
		$_ = '' if (not defined($_));
		s!([^a-zA-Z0-9_.-])!uc(sprintf("%%%02x", ord($1)))!eg;
		}
	if ((wantarray) or ($#out > 0)) {
		return @out;
		}
	else {
		return $out[0];
		}
	}








=item text_to_html

=cut

sub text_to_html($$);
sub text_to_html($$) {
	my ($text, $b_no_url) = @_;
	$text = &he($text);
	&force_CRLF( \$text );
	$text =~ s!http://(\S+)!<a href="http://$1">http://$1</a>!sg unless ($b_no_url);
	$text =~ s!\015\012!<br />\015\012!sg;
	return $text;
	}


sub get_age_str {
	my ($age) = @_;
	my $age_str = '';
	$age += 59; # round up
	if ($age > (2 * 86400)) {
		$age_str = sprintf( '%s days ago', int($age / 86400) );
		}
	elsif ($age > (100 * 60)) {
		$age_str = sprintf( '%s hours ago', int($age / 3600) );
		}
	else {
		$age_str = sprintf( '%s minutes ago', int($age / 60) );
		}
	return $age_str;
	}







=item validate_system_settings

Usage:

	$err = &validate_system_setting( \%hash );
	next Err if ($err);

NOTE: this subroutine performs read-write operations on the input %hash hash.

This subroutine will return $err if there is a problem with the values entered in %hash, but it will also replace the offending value with the system default.  In this way, it can be used to audit admin-initiated changes in the UI, and also to audit values as they are read off of the disk at system start-up.

=cut

sub validate_system_settings($);
sub validate_system_settings($) {
	my ($p_hash) = @_;
	my @errors = ();
	Err: {


		my $te = '';
		$te = &fd_validate( $$p_hash{'Mail Server'}, 'hostname', 0, 0, 'Mail Server' );
		if ($te) {
			push( @errors, $te );
			}

		my $b_sec_error = 0;

		$te = &fd_validate( $$p_hash{'sec_mode'}, 'int', 0, 4, 'Security Mode' );
		if ($te) {
			push( @errors, $te );
			$b_sec_error = 1;
			}


		my $var;
		foreach $var ('Permission - CGI Scripts', 'Permission - Normal Files', 'Permission - Folder') {
			$te = &fd_validate( $$p_hash{$var}, 'string_p', 4, 4, $var );
			if ($te) {
				push( @errors, $te );
				$b_sec_error = 1;
				next;
				}
			$te = &fd_validate( $$p_hash{$var}, 'int', 0, 7777, $var );
			if ($te) {
				push( @errors, $te );
				$b_sec_error = 1;
				next;
				}
			if ($$p_hash{$var} =~ m!(8|9)!) {
				push( @errors, &pstr( 288, $var, &he($$p_hash{$var}), $1 ) );
				$b_sec_error = 1;
				next;
				}
			}

		if ($b_sec_error) {
			# re-parse all file-security permissions using auto-detect
			$$p_hash{'sec_mode'} = 0;
			}


		if ($$p_hash{'RegKey'}) {
			my $virtual = $const{'code_validate'};
			unless (&$virtual( $$p_hash{'RegKey'} )) {
				#should not happen
				push( @errors, qq!$str[227] [<a href="$const{'help file'}1092.html">$str[55]</a>]! );
				$$p_hash{'RegKey'} = '';
				}
			}

		$te = &fd_validate( $$p_hash{'mode'}, 'int', 0, 3, 'License Mode' );
		if ($te) {
			push( @errors, $te );
			$$p_hash{'mode'} = 1; # default Trial Shareware
			}

		foreach $var ('Media Types', 'CGI Types', 'Known Types') {
			$te = &fd_validate( $$p_hash{$var}, 'string_p', 0, 1024, $var );
			if ($te) {
				push( @errors, $te );
				$$p_hash{$var} = '';
				}
			}


		$te = &fd_validate( $$p_hash{'Min Password Length'}, 'int', 0, 8, 'Minimum Password Length' );
		if ($te) {
			push( @errors, $te );
			$$p_hash{'Min Password Length'} = 0;
			}

		# strip leading/trailing whitespace, and force a trailing slash:
		foreach $var ('Base Folder', 'Base URL', 'Images URL') {
			$$p_hash{$var} = &Trim($$p_hash{$var});
			next if ($$p_hash{$var} =~ m!/$!);
			$$p_hash{$var} .= '/';
			}
		last Err;
		}

	my ($first, $last) = ( $str[6], '' );

	if ($first =~ m!^(.*)\$s1(.*)$!) {
		($first, $last) = ($1, $2);
		}

	my $err = join( "$last$first", @errors );
	return $err;
	};



sub system_settings_load($$$);
sub system_settings_load($$$) {
	my ($file, $p_effective, $p_raw) = @_;
	my $sys_load_warnings = '';
	my $err = '';
	Err: {

		my $text;
		($err, $text) = &ReadFile( $file );
		next Err if ($err);

		my %merge = %$p_raw;
		foreach (split(m!\r?\n!s, $text)) {
			next unless (m!^(.+)\==(.*)$!);
			my ($name, $value) = ($1, $2);
			next unless (defined($merge{$name}));
			$value =~ s!\\CRLF!\015\012!sg;
			$merge{$name} = $value;
			}

		%$p_raw = %merge;

		# if there are validation failures, we will overwrite them with default values, and then add the warning info to the queue for later display in StartHTML

		$sys_load_warnings = &validate_system_settings( \%merge );

		%$p_effective = %merge;
		$$p_effective{'Images URL'} = &he($$p_effective{'Images URL'});
		}
	return ($err, $sys_load_warnings);
	};




=item file_security_init

Usage:

	$err = &file_security_init();
	next Err if ($err);

Initializes the global @file_sec array based on the system 'sec_mode' setting.  If sec_mode == 0 for auto-detect, then this subroutine handles the auto-detection process.

Currently there is no error handling.  The $err return value is for future use.

This routine trusts that the sec_mode and the various Permissions settings from the %system_eff global hash will be valid-format.  This subroutine should only be called after &validate_system_settings( \%system_eff ).

=cut

sub file_security_init($);
sub file_security_init($) {
	my ($sec_mode) = @_;
	my $err = '';
	Err: {

		unless ($sec_mode) {
			$sec_mode = &detect_sec_mode();
			}

		# @file_sec == b_use_chmod, perm folder, data file, script file

		if ($sec_mode == 2) { # setuid
			@file_sec = (1, 755, 644, 755);
			}
		elsif ($sec_mode == 3) { # permissive
			@file_sec = (1, 777, 666, 777);
			}
		elsif ($sec_mode == 4) { # custom
			@file_sec = (1, $system_eff{'Permission - Folder'}, $system_eff{'Permission - Normal Files'}, $system_eff{'Permission - CGI Scripts'});
			}
		elsif ($sec_mode == 1) { # none
			@file_sec = (0);
			}

		if ($file_sec[0]) {
			for (1..3) {
				unless ($file_sec[$_] =~ m!(\d\d\d)$!) {
					$err = "file security descriptor must be of the format ddd";
					next Err;
					}
				$file_sec[$_] = oct("0$1");
				}
			}
		last Err;
		}
	return $err;
	};



sub clean_path {
	my $path = &Trim($_[0]);

	my ($base, $question, $query) = ($path, '', '');

	if ($path =~ m!^(.+?)(\??)(.*)$!s) {
		($base, $question, $query) = ($1, $2, $3);
		}

	local $_ = $base;

	# strip pound signs and all that follows (links internal to a page)
	s!\#.*$!!;

	# map /%7E to /~ (common source of duplicate URL's)
	s!\/\%7E!\/\~!ig;

	# map "/./" to "/"
	s!/+\./+!/!g;

	# map trailing "/." to "/"
	s!/+\.$!/!g;

	# map "/folder/../" => "/"
	while (s!([^/]+)/+\.\./+!/!) {}

	# map /../foo => /foo
	while (s!^/+\.\./+!/!) {}

	s!^/+\.\.$!/!;

	# collapse back-to-back slashes in the path
	s!/+!/!g;

	return $_ . $question . $query;
	}



1;
