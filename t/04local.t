#!/usr/bin/perl -w

use strict;

# check that this is running on my laptop and nowhere else

BEGIN
{
  my $skiptext = "1..0 # Skipped: these tests run on authors pc only\n";

  eval
  {
    # check the hostname is right

    require Sys::Hostname;
    Sys::Hostname->import;

    unless (hostname() eq "uk-wrk-0017")
    {
      print $skiptext;
      exit;
    }

    # even if that's the same, better check I'm in /etc/passwd

    require Tie::File;
    require Fcntl;
    tie my @array, 'Tie::File', "/etc/passwd", mode => Fcntl::O_RDONLY(),
     or die "Can't open file!: $!";

    unless (grep { /Mark Fowler/ } @array)
    {
      print $skiptext;
      exit;
    }
  };

  # problems loading any of those modules?  Not my machine.
  if ($@)
  {
      print $skiptext;
      exit;
  }
}

use Test::More tests => 9;
use Indico::DB::Simple;
use Test::DatabaseRow;
use Test::Exception;
use Test::Builder::Tester;

$Test::DatabaseRow::dbh = Indico::DB::Simple->intranet;

row_ok(table => "Banner",
       where => [ bannerID => 1 ],
       tests => [ Name => "test", image => "testjb", bannerID => 1],
       label => "banner works");

row_ok(table => "Banner",
       where => { LIKE => { "Redirect" => '%2profero.com' } },
       tests => [ Name => "test", image => "testjb" ],
       label => "like works");

# things also tested with a fake dbh, but tested here again for
# completeness

test_out("not ok 1 - matches");
test_fail(+2);
test_diag("No matching row returned");
row_ok(table => "Banner",
       where => { LIKE => { "Redirect" => 'Something that will never be there' } },
       tests => [ Name => "test", image => "testjb" ],
       label => "matches");
test_test("no returned data");

dies_ok { row_ok( sql    => "any old gumph",
	          tests  => [ fooid => 1 ]) } "handles problems with sql";

# better check that SQL in the example section does exactly what
# I say it should

use SQL::Abstract;
my $sql = SQL::Abstract->new();

my ($sql_text, @bind) = $sql->select("contacts",
                                 "*",
                                 { name => [ "Trelane",
                                             "Trel",
                                             "MarkF" ],
                                   road => { 'like' => "Liverpool%" },
                                 });

is($sql_text, q{SELECT * FROM contacts WHERE ( ( ( name = ? ) OR ( name = ? ) OR ( name = ? ) ) AND road like ? )}, "SQL::Abstract 1");
is($bind[0],"Trelane",   "SQL::Abstract 2");
is($bind[1],"Trel",      "SQL::Abstract 3");
is($bind[2],"MarkF",     "SQL::Abstract 4");
is($bind[3],"Liverpool%","SQL::Abstract 5");


