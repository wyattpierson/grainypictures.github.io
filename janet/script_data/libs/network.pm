use strict;

sub SendMailEx {
	my %params = @_;
	my $basename = '';
	my $full_message = '';
	my $trace = '';
	my $err = '';
	Err: {

		if ($params{'pipeto'}) {
			$err = &sendmail_valid($params{'pipeto'});
			next Err if ($err);
			}


		local $_;

		# validate inputs:
		if ((not $params{'to name'}) and ($params{'to_name'})) {
			$params{'to name'} = $params{'to_name'};
			}
		if ((not $params{'from name'}) and ($params{'from_name'})) {
			$params{'from name'} = $params{'from_name'};
			}
		if ((not $params{'message'}) and ($params{'body'})) {
			$params{'message'} = $params{'body'};
			}

		foreach ('to', 'from') {
			unless ($params{$_}) {
				$err = "invalid argument. Parameter '$_' is required";
				next Err;
				}
			}

		$params{'port'} = 25 unless ($params{'port'});

		# Use strictly compliant line enders:
		my $CRLF = "\015\012";

		# build the full message:

		$full_message = '';


		if ($params{'raw'}) {
			$full_message = $params{'raw'};
			}
		else {
			for ('to', 'from') {
				if ($params{"$_ name"}) {
					$full_message .= qq!$_: <$params{$_}> "$params{"$_ name"}"$CRLF!;
					}
				else {
					$full_message .= qq!$_: <$params{$_}>$CRLF!;
					}
				}
			my $date = &FormatDateTime( time(), 'smtp' );
			$full_message .= "Date: $date$CRLF";
			if ($params{'subject'}) {
				$full_message .= "Subject: $params{'subject'}$CRLF";
				}
			if ($params{'is_html'}) {
				$full_message .= "Content-Type: text/html$CRLF";
				}
			$full_message .= $CRLF;
			$full_message .= $params{'message'};
			}

		# Fix for bare LF

		$full_message =~ s!\012!\015\012!sg;
		$full_message =~ s!\015+!\015!sg;

		# Escape any literal CRLF . CRLF sequences (this is the end-of-message sequence in SMTP)
		$full_message =~ s!\015\012\.\015\012!\015\012\. \015\012!sg;


		unless (($params{'pipeto'}) or ($params{'host'})) {
			$err = "unable to send message because no mail transport agent was defined. You must define an SMTP server value or a Sendmail Program on the system settings page";
			next Err;
			}

		# Message has been built - now send it:

		$params{'handler_order'} = '1234' unless (defined($params{'handler_order'}));
		TryToSend: foreach (split(m!!, $params{'handler_order'})) {
			next TryToSend unless (m!^\d$!);

			if (($_ == 1) and ($params{'pipeto'})) {
				if (open(PIPE, "|$params{'pipeto'}")) {
					# okay... send it w/ only \n
					my $temp_fm = $full_message;
					$temp_fm =~ s!\015\012!\012!sg;
					print PIPE $temp_fm;
					close(PIPE);
					$trace = $full_message;
					last TryToSend;
					}
				$err = &pstr(78,$params{'pipeto'},$!);
				next TryToSend;
				}

			if (($_ == 2) and ($params{'host'})) {
				($err, $trace) = &sendmail_socket( $params{'host'}, $params{'port'}, $params{'to'}, $params{'from'}, $full_message );
				next TryToSend if ($err);
				last TryToSend;
				}

			}
		}
	return ($err, $trace);
	}





sub sendmail_socket {
	my ($host,$port,$to,$from,$raw) = @_;
	my $is_open = 0;
	my $trace = '';
	my $err = '';
	Err: {
		# connect to the SMTP server
		my ($PF,$SS) = ();
		($err,$PF,$SS) = &leansock($host,$port,\*MAIL);
		next Err if ($err);
		$is_open = 1;
		my @commands = (
			[ 'Welcome',
				220, 0, '',
				],
			[ 'HELO',
				250, 1, "HELO $host",
				],
			[ 'Mail From',
				250, 1, "MAIL FROM:<$from>",
				],
			[ 'Recipient/To',
				250, 1, "RCPT TO:<$to>",
				],
			[ 'Data Initialize',
				354, 1, "DATA",
				],
			[ 'Data Transfer',
				250, 1, "$raw\015\012.\015\012",
				],
			);
		my $i = 0;
		for ($i = 0; $i <= $#commands; $i++) {
			my ($expect_code, $sendrecv, $send_data) = ($commands[$i][1], $commands[$i][2], $commands[$i][3]);
			if ($sendrecv) {
				$send_data .= "\015\012";
				my $data_len = length($send_data);
				my $send_len = send(*MAIL, $send_data, 0);
				unless (defined($send_len)) {
					$err = &pstr(80,$!,$^E);
					next Err;
					}
				if ($send_len != $data_len) {
					$err = &pstr(79,$send_len,$data_len,$!,$^E);
					next Err;
					}
				$trace .= $send_data;
				}
			my $response_code = '';
			my $response_text = '';
			local $_;
			while (defined($_ = readline(*MAIL))) {
				$response_text .= $_;
				$trace .= $_;
				s!(\r|\n|\015|\012)!!g;#correct for MacPerl
				if ((m!^(\d\d\d)\-!) and ($1 ne '000')) {
					$response_code = $1 unless ($response_code);
					}
				elsif (m!^(\d\d\d)\r?(\s|$)!) {
					$response_code = $1 unless ($response_code);
					last;
					}
				else {
					$err = &pstr(75,$host,$port,$commands[$i][0],$response_text);
					next Err;
					}
				}
			unless ($response_code =~ m!$expect_code!) {
				$err = &pstr(77,$host,$port,$commands[$i][0],$expect_code,$response_code,$response_text);
				next Err;
				}
			}
		}
	close(*MAIL) if ($is_open);
	return ($err, $trace);
	}





sub leansock {
	my ($host,$port,$p_socket,$PF,$SS) = @_;
	my $err = '';
	Err: {
		my $addr = (gethostbyname($host))[4];
		unless ($addr) {
			$err = &pstr(203, $host, $!, $^E);
			next Err;
			}
		unless (($PF) and ($SS)) {
			eval 'use Socket;';
			if ($@) {
				# yuck...
				($PF, $SS) = (6, 1);
				}
			else {
				($PF, $SS) = (PF_INET(), SOCK_STREAM());
				}
			}
		unless (socket($$p_socket, $PF, $SS, scalar getprotobyname('tcp'))) {
			$err = &pstr(204, $!, $^E);
			next Err;
			}
		unless (connect($$p_socket, pack('S n a4 x8', $PF, $port, $addr))) {
			$err = &pstr(205, $host, $port, $!, $^E);
			close($$p_socket);
			next Err;
			}
		unless (binmode($$p_socket)) {
			$err = &pstr(202,$!);
			close($$p_socket);
			next Err;
			}
		my $h = select($$p_socket);
		$| = 1;
		select($h);
		}
	return ($err,$PF,$SS);
	}





sub sendmail_valid {
	my ($path) = @_;
	my $err = '';
	Err: {
		my $b_valid = 0;
		local $_;
		foreach (@sendmail) { # global
			next unless ($path eq $_);
			next unless (m!^(\S+)!);
			my $local = $1;
			unless (-e $local) {
				my ($full, $base) = &he($_, $local);
				$err = "base path '$base' of sendmail command line '$full' fails the file existence test";
				next Err;
				}
			$b_valid = 1;
			last Err;
			}
		my $full = &he($path);
		$err = "sendmail path '$full' is not listed in the system \@sendmail array";
		next Err;
		last Err;
		}
	return $err;
	}




sub http_import {
	my ($p_upload_files) = @_;
	my $err = '';
	Err: {

		my $sa = $FORM{'sa'} || '';

		my $status = ($sa eq 'save') ? $str[72] : $str[66]; # "save data" vs "overview"

print <<"EOM";

<p><b><a href="$const{'admin_url'}Action=Main">$str[56]</a> &gt;
	<a href="$const{'admin_url'}Action=ListFiles">$str[53]</a> &gt;
	<a href="$const{'admin_url'}Action=HI">Add Web Files</a> &gt;
	$status</b></p>

EOM


		$err = &priv_check(1,'use_html_editor','p_upload');
		next Err if ($err);

		if ($sa eq 'save') {

			my ($clean_url, $host, $port, $path);

			foreach (sort keys %FORM) {
				next unless (m!^file\d+$!);
				next unless (($FORM{$_}) and ($FORM{$_} ne 'http://'));
				($err, $clean_url, $host, $port, $path) = &parse_url_ex($FORM{$_});
				next Err if ($err);

				my $is_cgi = 0;

				my $local_file_name;


				if ($path =~ m!^(.*)/(.+?)$!) {
					my ($temp_error, $temp_is_cgi) = &CheckName( $2, 1 );


					if ($temp_error eq '') {
						$local_file_name = $2;
						$is_cgi = $temp_is_cgi;
						}
					}
				unless ($local_file_name) {
					if ($host =~ m!^a-z\.0-9\-!) {
						$err = "hostname contains invalid characters";
						next Err;
						}
					my $x = 1000;
					while ($x++) {
						last if ($x > 2000);
						next if (-e "$host.$x.tmp");
						$local_file_name = "$host.$x.tmp";
						last;
						}
					}

				my $extension = '';
				if ($local_file_name =~ m!^.*\.([^\.\/\\]+)$!) {
					$extension = $1;
					}

				if (1 == $STATE{'p_upload'}) {
					# only media files...

					my $qm_ext = quotemeta($extension);

					my $media = " $system_eff{'Media Types'} ";
					unless ($media =~ m! $qm_ext !) {
						my $hname = &he($local_file_name);
						my $h_ext = &he($extension);

						&ppstr(6, &pstr(50, $hname, $h_ext, $media ) );

						next;
						}
					}



				my $h_url = &he($clean_url);
				print '<p>' . &pstr( 161, qq!starting network request for <a href="$h_url">$h_url</a>..! ) . '</p>';


				unless (open(FILE, ">$local_file_name")) {
					$err = "unable to open file for writing - $!";
					next Err;
					}
				binmode(FILE);

				my $bytes = 0;

				($err, $const{'PF'}, $const{'SS'} ) = &leansock( $host, $port, \*HTTP, $const{'PF'}, $const{'SS'} );
				next Err if ($err);

my $request = <<"EOM";
GET $path HTTP/1.0
Host: $host:$port
Referer: Web Import Routine ($const{'product'})
X-Forwarded-For: $private{'REMOTE_ADDR'}

EOM


				&force_CRLF( \$request );

				print HTTP $request;

				my $response = <HTTP>;

				unless ($response =~ m!^HTTP/1\.\d (\d+)(.*?)$!s) {
					$err = "unable to process HTTP response code";
					next Err;
					}
				my ($code, $desc) = ($1, &he(&Trim($2)));

				if ($code != 200) {
					$err = "unable to retrieve file - server responded with $code $desc";
					next Err;
					}

				&pppstr( 161, "server responded to request with $code $desc" );

				while (defined($_ = <HTTP>)) {
					last if (m!^\015?\012$!s);
					}
				while (defined($_ = <HTTP>)) {
					$bytes += length($_);
					print FILE $_;
					}

				close(HTTP);
				close(FILE);
				&Mask( $local_file_name, $is_cgi );

				my $h_name = &he($local_file_name);
				&ppstr( 4, qq!saved $bytes bytes as file <a href="$STATE{'web_path'}$h_name">$h_name</a>! );
				print qq!<hr size="1" />\n!;
				}


			last Err;
			}
		if ($sa) {
			$err = &pstr( 286, &he($sa) );
			next Err;
			}



		if ($STATE{'p_upload'} == 1) {
			# only Media Types allowed... warn the user...
			print "<p>You are only allowed to upload or import Media Types with the following file extensions:</p><blockquote><p>$system_eff{'Media Types'}</p></blockquote>\n";
			}


		my $field_count = $STATE{'multi_upload_count'};

print <<"EOM";

$const{'AdminForm'}
<input type="hidden" name="Action" value="HI" />
<input type="hidden" name="sa" value="save" />

<p><input type="submit" class="submit" value="Import" /></p>
<ol>
EOM

for (1..$field_count) {
	print qq!<li><p><input name="file$_" value="http://" size="$const{'TEXT_INPUT_SIZE'}" /></p></li>\n!;
	}

print <<"EOM";
</ol>
<p><input type="submit" class="submit" value="Import" /></p>

</form>

EOM
		last Err;
		}
	return $err;
	}





sub parse_url_ex {
	local $_ = $_[0];
	my ($clean_url, $host, $port, $path) = ('', '', 80, '/');
	my $err = '';
	Err: {
		unless ($_) {
			$err = "URL cannot be blank";
			next Err;
			}
		if ($_ eq 'http://') {
			$err = "must enter URL of the form http://host.tld/path/";
			next Err;
			}


		# add trailing slash if none present
		$_ .= '/' if (m!^http://([^/]+)$!i);

		unless (m!^http://([\w|\.|\-]+)\:?(\d*)/(.*)$!i) {
			my $h_url = &he($_);
			$err = "URL must pattern match http://host.tld/path/ - entered '$h_url'";
			next Err;
			}
		($host, $port, $path) = (lc($1), $2 || 80, &clean_path("/$3"));
		if ($port == 80) {
			$clean_url = "http://$host$path";
			}
		else {
			$clean_url = "http://$host:$port$path";
			}
		last Err;
		}
	return ($err, $clean_url, $host, $port, $path);
	}






1;
