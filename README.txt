
This script is designed to dump a day's worth of Tweets into your
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

