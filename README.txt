This script is designed to dump a day's worth of Tweets into your LiveJournal.

== Usage ==
1) create a .birdcagerc in your home dir (~/.birdcagerc) with the following contents:
  lj_sec=friends
  twitter_user=br3nda
  lj_user=br3nda
  lj_site=livejournal.com
  lj_pass=<your password>
2) run birdcage
  ./birdcage.pl

== Dependencies ==
birdcage.pl needs the following modules, all available either in the
standard Perl distribution, or via CPAN:

LWP::Simple
Date::Manip
LJ::Simple

== Dream Width ==
To use birdcage.pl with Dreamwidth.org, set lj_site=dreamwidth.org

== Bird Cage Wiki ==
Birdcage can be found at http://github.com/Br3nda/birdcage/wiki


