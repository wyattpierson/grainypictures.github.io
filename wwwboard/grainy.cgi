#!/usr/bin/perl

############################################
##                                        ##
##                 WebBBS                 ##
##           by Darryl Burgdorf           ##
##                                        ##
##           Configuration File           ##
##                                        ##
############################################

## (1) Define the location of your files:

require "/usr/home/grainypi/www/cgi-bin/webbbs.pl";

$dir = "/usr/home/grainypi/www/htdocs/wwwboard/board";
$cgiurl = "http://www.grainypictures.com/cgi-bin/grainy.cgi";

## (2) Tailor the appearance and functionality of your BBS:

$bodyspec = "BGCOLOR=\"#ffffff\" TEXT=\"#000000\"";

$HeadLinesFile = "";
$HeaderFile = "/usr/home/grainypi/www/htdocs/wwwboard/header.txt";
$FooterFile = "/usr/home/grainypi/www/htdocs/footer.html";

$MessageHeaderFile = "";
$MessageFooterFile = "/usr/home/grainypi/www/htdocs/footer.html";

$DefaultType = "By Threads, Reversed";
$DefaultTime = "Two Months";

$boardname = "Grainy Pictures Discussion Board";

$InputColumns = 75;
$InputRows = 15;

$HourOffset = 3;

$ArchiveOnly = 0;
$AllowHTML = 0;
$AutoQuote = 1;
$SingleLineBreaks = 1;

$UseCookies = 1;
require "/usr/home/grainypi/www/cgi-bin/cookie.lib";

$UseAdmin = 1;

$Max_Days = "";
$Max_Messages = "";

$ArchiveDir = "/usr/local/etc/httpd/sites/viewaskew.com/htdocs/board/archives";

## (3) Define your visitors' capabilities:

$AllowUserDeletion = 1;
$AllowEmailNotices = 1;
$AllowPreview = 0;

$AllowURLs = 1;
$AllowPics = 1;

$NaughtyWords = "";

## (4) Define your e-mail notification features:

$mailprog = '/usr/home/grainypi/bin/sendmail';
$maillist_address = "ming\@grainypictures.com";
$email_list = "";

$HeaderOnly = 0;
$AdminEmail = 0;

&WebBBS;

## (5) If necessary, set up the WebAdverts configuration subroutine

sub insertadvert {
	require "/full/path/to/ads_display.pl";
	$adverts_dir = "/full/path/to/ads";
	$display_cgi = "http://foo.com/ads/ads.pl";
	$advertzone = $_[0];
	$ADVUseLocking = 1;
	$ADVLogIP = 0;
	$NonSSI = 0;
	$DefaultBanner = "";
	$ADVNoPrint = 1;
	&ADVsetup;
}

