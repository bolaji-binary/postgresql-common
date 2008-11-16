# Test default and explicit encoding on upgrades

use strict; 

use lib 't';
use TestLib;

use Test::More tests => ($#MAJORS == 0) ? 1 : 36;

use lib '/usr/share/postgresql-common';
use PgCommon;

if ($#MAJORS == 0) {
        pass 'only one major version installed, skipping upgrade tests';
        exit 0;
}

my $outref;
my $oldv = $MAJORS[0];
my $newv = $MAJORS[-1];

is ((exec_as 0, "pg_createcluster --start --locale=ru_RU $oldv main", $outref), 0,
    "creating ru_RU $oldv cluster");

is ((exec_as 'postgres', 'psql -c "create database latintest" template1', $outref), 0,
    "creating DBs with LATIN encoding");

is ((exec_as 'postgres', "printf 'A\\324B' | psql -c \"create table t(x varchar); copy t from stdin\" latintest", $outref), 
    0, 'write LATIN database content');

is_program_out 'postgres', "echo \"select * from t\" | psql -Atq latintest",
    0, "A\324B\n", 'old latintest DB has correctly encoded string';

is ((exec_as 'postgres', 'psql -Atl', $outref), 0, 'psql -Atl on old cluster');
ok ((index $$outref, 'latintest|postgres|ISO_8859_5') >= 0, 'latintest is LATIN encoded');
ok ((index $$outref, 'template1|postgres|ISO_8859_5') >= 0, 'template1 is LATIN encoded');

# upgrade without specifying locales, should be kept
like_program_out 0, "pg_upgradecluster -v $newv $oldv main", 0, qr/^Success/im;

is ((exec_as 'postgres', "psql --cluster $newv/main -Atl", $outref), 0, 'psql -Atl on upgraded cluster');
ok ((index $$outref, 'latintest|postgres|ISO_8859_5') >= 0, 'latintest is LATIN encoded');
ok ((index $$outref, 'template1|postgres|ISO_8859_5') >= 0, 'template1 is LATIN encoded');
is_program_out 'postgres', "echo \"select * from t\" | psql --cluster $newv/main -Atq latintest",
    0, "A\324B\n", 'new latintest DB has correctly encoded string';

is ((system "pg_dropcluster --stop $newv main"), 0, 'dropping upgraded cluster');
is ((system "pg_ctlcluster $oldv main start"), 0, 'restarting old cluster');

# upgrade with explicitly specifying other locale
like_program_out 0, "pg_upgradecluster --locale ru_RU.UTF-8 -v $newv $oldv main", 0, qr/^Success/im;

is ((exec_as 'postgres', "psql --cluster $newv/main -Atl", $outref), 0, 'psql -Atl on upgraded cluster');
ok (($$outref =~ 'latintest|postgres|(UTF8|UNICODE)') >= 0, 'latintest is UTF8 encoded');
ok (($$outref =~ 'template1|postgres|(UTF8|UNICODE)') >= 0, 'template1 is UTF8 encoded');
is_program_out 'postgres', "echo \"select * from t\" | psql --cluster $newv/main -Atq latintest",
    0, "AдB\n", 'new latintest DB has correctly encoded string';

is ((system "pg_dropcluster --stop $newv main"), 0, 'dropping upgraded cluster');

is ((system "pg_dropcluster $oldv main"), 0, 'dropping old cluster');

check_clean;

# vim: filetype=perl
