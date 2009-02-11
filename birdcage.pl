#!/usr/bin/perl
#
# birdcage.pl 0.2.1
# Copyright (C) 2007 Greck Cannon
# greck@unpunk.com
#
# This script is designed to dump a day's worth of Tweets into your
# LiveJournal.  The API is a bit weird, and only allows you to reach
# back at most 20 statuses, so... to save a ton of logic, birdcage.pl
# is hardcoded to read all Tweets (unless you make more than 20 in a
# day!) since midnight today.  The two caveats are: set the time zone
# below to match whatever time zone your LiveJournal is in, and have
# cron run birdcage.pl at one minute until midnight, *adjusted for
# any difference in time zones between your server and LiveJournal*.
# E.g., if your LJ is in US/Central and your server is in US/Pacific,
# schedule the cron job to run at 21:59.
#
# birdcage.pl needs the following modules, all available either in the
# standard Perl distribution, or via CPAN:
#
# LWP::Simple
# Date::Manip
# LJ::Simple
#
# CHANGELOG
#
# 0.2.1
# - Added max 3 retries when logging in to LJ and again when posting.
#
# 0.2
# - Switched from using QuickPost to using the full PostEntry method.
# - Added support for userpics and tags.
#
# 0.1
# - Initial release.
#


my $result = GetOptions('help' => \$help, 'username=s' => \$username, 'password=s' => \$password, 'sync' => \$sync);

#
# TWITTER ACCOUNT INFORMATION
#
$twitter_user = '';
$twitter_pass = '';

#
# LIVEJOURNAL ACCOUNT INFORMATION
#
$lj_user = ''; 
$lj_pass = '';
#
# public, friends, private
#
$lj_sec = "friends";
#
# tags
#
@lj_tags = ( "twitter" );
#
# userpic (use "keywords" value)
#
#$lj_userpic = "twitterrific";

#
# TIME ZONE
#
$tz = "US/Pacific";

#
# *********************************************************
# *** YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW HERE ***
# *********************************************************
#

use POSIX qw(strftime);
use LWP::Simple;
use Date::Manip;
use LJ::Simple;
use Net::Twitter;

&Date_Init("TZ=$tz");
$midnight_today = UnixDate(scalar(localtime),"%a,+%d+%b+00:00:00+%Z");
my $twit = Net::Twitter->new( username => $twitter_user, password => $twitter_pass);
$timeline = $twit->user_timeline({id => $twitter_user});

#
# I know, there's a real XML parser I should be using...
#

#while ( $_ = shift @tweets ) {


$i = 0;
my @entries;
foreach my $tweet (@{ $timeline }) {
	#next if $tweet->{'text'} =~ /http:/;
	next if $tweet->{'text'} =~ /\@[A-Z]/i;
	next if (!$tweet->{'text'});
	$entries[$i] = "<li>" . $tweet->{'text'} ."</li>\n";
	$i++;
}
@entries = reverse(@entries);

$entry = '<ul>' . "\n";
foreach my $line (@entries) {
  $entry .= $line;
}
$entry .= '</ul>' . "\n";

for ( $i = 0; $i < 3; ++$i ) {

	if ( $lj = new LJ::Simple ( { user => $lj_user, pass => $lj_pass } ) ) {
		last;
	} else {
		sleep 5;
	}

}


if ( not defined($lj) ) {
	die "$0: Failed to login to LiveJournal ($LJ::Simple::error)";
}

%lj_event=();

$lj->NewEntry(\%lj_event)
	or die "$0: Failed to create new entry ($LJ::Simple::error)";

$lj->SetProtect(\%lj_event,$lj_sec)
	or die "$0: Failed to set protection ($LJ::Simple::error)";

$lj->SetEntry(\%lj_event,$entry)
	or die "$0: Failed to set entry ($LJ::Simple::error)";

$lj->SetSubject(\%lj_event,"Todays' Twitter rants")
	or die "$0: Failed to set subject ($LJ::Simple::error)";

if ( defined @lj_tags ) {
	$lj->Setprop_taglist(\%lj_event,@lj_tags)
		or die "$0: Failed to set tags ($LJ::Simple::error)";
}

$lj->Setprop_preformatted(\%lj_event,1)
	or die "$0: Failed to set formatting ($LJ::Simple::error)";

if ( defined $lj_userpic ) {
	$lj->Setprop_picture_keyword(\%lj_event,$lj_userpic)
		or die "$0: Failed to set userpic ($LJ::Simple::error)";
}

for ( $i = 0; $i < 3; ++$i ) {

	( $lj_item_id, $lj_anum, $lj_html_id )=$lj->PostEntry(\%lj_event);

	if ( defined($lj_item_id) ) {
		last;
	} else {
		sleep 5;
	}

}

if ( not defined($lj_item_id) ) {
	die "$0: Failed to post entry ($LJ::Simple::error)";
}
