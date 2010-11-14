#!/usr/bin/perl
#
# birdcage.pl
#
$version="0.3.5";
#
# Copyright (C) 2007-2009 Greck Cannon
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the Greck Cannon nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY GRECK CANNON ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL GRECK CANNON BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
###############################################################################
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
#
# TO-DO
# - update all the in-line documentation
# - lots of error checking
#
# 0.3.5
# - change \n to <BR> to preserve original intent
# - added link in subject (we'll see if that breaks any styles)
# - anchored s{</text>}{} to EOL... just in case
#
# 0.3.4
# - handle <text>...</> with embedded \n
# - got rid of an inadvertently-left-in line of debug code
#
# 0.3.3
# - added version to LJ post subject for metrics
#
# 0.3.2
# - added the <!--id--> comment at the beginning of each row
#
# 0.3.1
# - added support for Windows to use birdcage.rc in dirname($0)
#
# 0.3
# - added rudimentary URL detection/linking
# - fixed up entity tags for < and >
# - fixed up the "not respecting since" problem with since_id
# - initial hack at config in ~/.birdcagerc
# - added detection of time zone offset from statuses
# - notice if there are no statuses, and don't post!
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

#
# OK, all the config goes in ~/.birdcagerc now!
# all the same options as before, usage hasn't changed
# now go make it, there's no error checking yet :-)
# and don't forget to chmod it 600 since it has your passwords in it!
# note, tz is gone, it's read from the status stream now
#
# twitter_user=<user>
# twitter_pass=<pass>
# lj_user=<user>
# lj_pass=<pass>
# # lj_sec can be one of public, friends, private
# lj_sec=friends
# # lj_tags can be a comma-separated list
# lj_tags=twitter
# # userpic use "keywords" value
# lj_userpic=twitterrific
#

use Cwd qw(abs_path);
use File::Basename;
use LWP::Simple;
use Date::Manip;
use LJ::Simple;

&Date_Init("TZ=UTC");

if ( $^O eq "MSWin32" ) {

	$configspec = dirname(abs_path($0)) . "/birdcage.rc";

} else {

	$configspec = (getpwuid($>))[7] . "/.birdcagerc";

}

if ( open CONFIG, "$configspec" ) {

        while ( <CONFIG> ) {

                next if /^#/;

                chomp;
                ( $key, $value ) = split '=', $_, 2;
                $config{$key} = $value;

        }

        close CONFIG;

} else { die "$0: I think your config should be in `$configspec', but couldn't open it"; }

$config{'lj_site'} = 'livejournal.com' unless ($config{'lj_site'});

$url = "http://twitter.com/statuses/user_timeline.xml?screen_name=" . $config{'twitter_user'} ."&count=";
$url .= $config{'since_id'} ? "100&since_id=$config{'since_id'}" : "20";

for ( $i = 0; $i < 3; ++$i ) {

	if ( $tweets_xml = get("$url") ) {
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
# (and this becomes more apparent the bigger of a hack this becomes)
#

while ( $_ = shift @tweets ) {

	if ( /<id>(.+)<\/id>/ ) {
	
		$id = $1;
		$latest_id = $id if $id > $latest_id;

	}

	if ( /<created_at>(.+)<\/created_at>/ ) {
	
		$tstamp = $1;
	
	}

   	if ( /<text>(.*)/ ) {

		$text = $1;

		if ( not $text =~ /<\/text>/ ) {
		
			do {
			
				$_ = shift @tweets;
				$text .= "<BR>$_";
				
			} while ( not $_ =~ /<\/text>/ );
		
		}

		$text =~ s{</text>$}{};
		$text =~ s{(http://.+?)(\s|$)}{<A HREF="\1">\1</A>\2}g;
		$text =~ s{&amp;lt;}{&lt;}g;
		$text =~ s{&amp;gt;}{&gt;}g;

	}
	
	if ( /<user>/ ) {

		while ( $_ = shift @tweets ) {

			last if /<\/user>/;
	
			if ( /<utc_offset>(.+)<\/utc_offset>/ ) {
			
				$utc_offset_seconds = $1;
				$utc_offset_hours = $utc_offset_seconds/3600;
				$utc_offset_minutes = ($utc_offset_seconds-(3600*$utc_offset_hours))/60;
				if ( $utc_offset_hours < 0 ) {
					$direction = "-";
					$utc_offset_hours *= -1;
				} else {
					$direction = "+";
				}
					
				$utc_offset = sprintf("%s%02d%02d",$direction,$utc_offset_hours,$utc_offset_minutes);
	
			}
			
		}
		
	}
	
	if ( /<\/status>/ ) {

		$statuses++;
	
		$tstamp = UnixDate(Date_ConvTZ(ParseDate($tstamp),"UTC",$utc_offset),"%H:%M:%S");

		unshift @entry, "<!--$id--><li>$tstamp $text</li>";
	
	}

}

$entry = '<ul>';
foreach $_ ( @entry ) { 
  $entry .= "$_\n"; 
}
$entry .= '</ul>';


if ( not $statuses ) {
	exit 0;
}

for ( $i = 0; $i < 3; ++$i ) {

	if ( $lj = new LJ::Simple ( { user => $config{'lj_user'}, pass => $config{'lj_pass'}, site => $config{'lj_site'} } ) ) {
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

$lj->SetProtect(\%lj_event,$config{'lj_sec'})
	or die "$0: Failed to set protection ($LJ::Simple::error)";

$lj->SetEntry(\%lj_event,$entry)
	or die "$0: Failed to set entry ($LJ::Simple::error)";

$lj->SetSubject(\%lj_event,"Twitter summary")
	or die "$0: Failed to set subject ($LJ::Simple::error)";

if ( defined $config{'lj_tags'} ) {
	@lj_tags = split ',', $config{'lj_tags'};
	$lj->Setprop_taglist(\%lj_event,@lj_tags)
		or die "$0: Failed to set tags ($LJ::Simple::error)";
}

$lj->Setprop_preformatted(\%lj_event,1)
	or die "$0: Failed to set formatting ($LJ::Simple::error)";

if ( defined $config{'lj_userpic'} ) {
	$lj->Setprop_picture_keyword(\%lj_event,$config{'lj_userpic'})
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

} else {

	$config{'since_id'} = $latest_id;

	if ( open CONFIG, ">$configspec" ) {
	
			foreach $c ( keys %config ) {
			
				print CONFIG "$c=$config{$c}\n";
			
			}
	
			close CONFIG;
	
	}

}
