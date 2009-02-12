#!/usr/bin/perl
#
# birdcage.pl 0.2.2
#
# Copyright (C) 2009 Greck Cannon
# All rights reserved.
#
###############################################################################
#
#
# CHANGELOG
#
# 0.2.2
# - Added BSD license notification.
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

use Getopt::Long qw(GetOptions);
use Pod::Usage;

if(!GetOptions(\%opt,
     'help|?',
     'twitter_user' => \$twitter_user,
     'twitter_pass' => \$twitter_pass,
     'lj_user' => \$lj_user,
     'lj_pass' => \$lj_pass,
     )) {
   pod2usage(-exitval => 1, 'verbose'=>0);
}

pod2usage(-exitval => 0, -verbose => 2) if($opt{'help'});

#
# TWITTER ACCOUNT INFORMATION
#
$twitter_user = "user";
$twitter_pass = "pass";

#
# LIVEJOURNAL ACCOUNT INFORMATION
#
$lj_user = "user";
$lj_pass = "pass";
#
# public, friends, private
#
$lj_sec = "public";
#
# tags
#
#@lj_tags = ( "twitter" );
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

&Date_Init("TZ=$tz");
$midnight_today = UnixDate(scalar(localtime),"%a,+%d+%b+00:00:00+%Z");

for ( $i = 0; $i < 3; ++$i ) {

    if ( $tweets_xml = get("http://$twitter_user:$twitter_pass\@twitter.com/statuses/user_timeline/$twitter_user.xml?count=20&since=$midnight_today") ) {
        last;
} else {
        sleep 5;
}

}

if ( not defined($tweets_xml) ) {
    die "$0: Twitter request failed";
}

@tweets = split '\n', $tweets_xml;

#
# I know, there's a real XML parser I should be using...
#

while ( $_ = shift @tweets ) {

    if ( /<created_at>(.+)<\/created_at>/ ) {
    
        $tstamp = UnixDate(ParseDate($1),"%H:%M:%S");
    
}

    if ( /<text>(.*)<\/text>/ ) {
    
        unshift @entry, "<TR><TD VALIGN=\"top\"><CODE>$tstamp</CODE></TD><TD VALIGN=\"top\">&nbsp;&mdash;&nbsp;</TD><TD VALIGN=\"top\">$1</TD></TR>";
    
}

}

$entry = '<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0">' . "\n";

foreach $_ ( @entry ) { $entry .= "$_\n"; }

$entry .= '</TABLE>' . "\n";

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

$lj->SetSubject(\%lj_event,"Twitter, digested by birdcage.pl")
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

 __END__

=head1 NAME

 birdcage.pl --help

=head1 SYNOPSIS

   birdcage.pl [options] <filename>

   Options:

   -? --help  detailed help message

=head1 DESCRIPTION

  This script is designed to dump a days worth of Tweets into your
  LiveJournal.  The API is a bit weird, and only allows you to reach
  back at most 20 statuses, so... to save a ton of logic, birdcage.pl
  is hardcoded to read all Tweets (unless you make more than 20 in a
  day!) since midnight today.  The two caveats are: set the time zone
  below to match whatever time zone your LiveJournal is in, and have
  cron run birdcage.pl at one minute until midnight, *adjusted for
  any difference in time zones between your server and LiveJournal*.
  E.g., if your LJ is in US/Central and your server is in US/Pacific,
  schedule the cron job to run at 21:59.
  
  birdcage.pl needs the following modules, all available either in the
  standard Perl distribution, or via CPAN:

 LWP::Simple
 Date::Manip
 LJ::Simple
 Getopt::Long
 Pod::Usage
 
=head1 OPTIONS

   --comment

=head1 EXAMPLES

  ./birdcage.pl ../index.php
  
=head1 LICENCE

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
     * Neither the name of the Greck Cannon nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY GRECK CANNON "AS IS" AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL GRECK CANNON BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut
