
sub force_CRLF {
	my ($p_text) = @_;
	$p_text =~ s!\015\012!\012!sg;
	$p_text =~ s!\015!\012!sg;
	$p_text =~ s!\012!\015\012!sg;
	}



sub ReadFile {
	my ($file) = @_;
	my $text = '';
	my $err_msg = '';
	Err: {
		unless (open(FILE, "<$file")) {
			$err_msg = "unable to read file '$file' - $!";
			next Err;
			}
		unless (binmode(FILE)) {
			$err_msg = "unable to set binmode on file '$file' - $!";
			next Err;
			}
		while (<FILE>) {
			$text .= $_;
			}
		close(FILE);
		}
	return ($err_msg, $text);
	}

sub WriteFile {
	my ($file, $text) = @_;
	my $err_msg = '';
	Err: {
		unless (defined($file)) {
			$err_msg = "invalid argument - 'file' parameter not defined";
			next Err;
			}
		unless (defined($text)) {
			$err_msg = "invalid argument - 'text' parameter not defined";
			next Err;
			}
		unless (open(FILE, ">$file")) {
			$err_msg = "unable to write to file '$file' - $!";
			next Err;
			}
		unless (binmode(FILE)) {
			$err_msg = "unable to set binmode on file '$file' - $!";
			next Err;
			}
		print FILE $text;
		close(FILE);
		}
	return $err_msg;
	}

sub Trim {
	local $_ = defined($_[0]) ? $_[0] : '';
	s!^[\r\n\s]+!!o;
	s![\r\n\s]+$!!o;
	return $_;
	}
1;
