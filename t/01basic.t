#!/usr/bin/perl -w

use strict;

use Test::More tests => 15;

###
# load the module
###

BEGIN { use_ok "Test::DatabaseRow" }

###
# simple tests
###

# create a fake dbh connection.  The quote function in this class
# just marks the text up with "qtd<text>" so we can see what would
# have been really quoted if it was a real dbh connection
my $dbh = FakeDBI->new();

{
  my @select = Test::DatabaseRow::_build_select(
    dbh => $dbh,
    sql => q{SELECT * FROM foo WHERE fooid = 123},
  );

  is($select[0],
     q{SELECT * FROM foo WHERE fooid = 123},
     "simple test"
  );
}

########################################################################

{
  my @select = Test::DatabaseRow::_build_select(
    dbh => $dbh,
    sql => [ q{SELECT * FROM foo WHERE fooid = 123} ],
  );

  is_deeply(\@select,
    [ q{SELECT * FROM foo WHERE fooid = 123} ],
    "simple test sql arrayref no bind"
  );
}

########################################################################

{
  my $array = [ q{SELECT * FROM foo WHERE fooid = ? AND bar = ?}, 123, 456 ];

  my @select = Test::DatabaseRow::_build_select(
    dbh => $dbh,
    sql => $array,
  );

  is_deeply(
    $array,
    [ q{SELECT * FROM foo WHERE fooid = ? AND bar = ?}, 123, 456 ],
    "array passed in unaltered",
  );

  is_deeply(\@select,
    [ q{SELECT * FROM foo WHERE fooid = ? AND bar = ?}, 123, 456 ],
    "simple test sql arrayref with bind"
  );
}

########################################################################

{
  my $where = { '=' => { fooid => 123, bar => "abc" } };

  my @select = Test::DatabaseRow::_build_select(
    dbh   => $dbh,
    table => "foo",
    where => $where
  );

  is_deeply(
    $where,
    { '=' => { fooid => 123, bar => "abc" } },
    "where datastructure unaltered"
  );

  is_deeply( \@select,
    [ q{SELECT * FROM foo WHERE bar = qtd<abc> AND fooid = qtd<123>} ],
    "simple equals test"
  );
}

########################################################################

{
  my $where = [ fooid => 123, bar => "abc" ];

  my @select = Test::DatabaseRow::_build_select(
    dbh   => $dbh,
    table => "foo",
    where => $where
  );

  is_deeply(
    $where,
    [ fooid => 123, bar => "abc" ],
    "where datastructure unaltered"
  );

  is_deeply( \@select,
    [ q{SELECT * FROM foo WHERE bar = qtd<abc> AND fooid = qtd<123>} ],
    "simple equals test with shortcut"
  );
}

########################################################################

###
# nulls
###

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
                      table => "foo",
                      where => [ fooid => undef ]))[0],
q{SELECT * FROM foo WHERE fooid IS NULL},
"auto null test");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
                      table => "foo",
                      where => { "=" => { fooid => undef } }))[0],
q{SELECT * FROM foo WHERE fooid IS NULL},
"auto null test2");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
                      table => "foo",
                      where => { "IS NOT" => { fooid => undef } }))[0],
q{SELECT * FROM foo WHERE fooid IS NOT NULL},
"auto null test3");

########################################################################

###
# munge array
###

my $hashref = Test::DatabaseRow::_munge_array( [ numbers => 123,
                                              string  => "foo",
                                              regex   => qr/foo/ ] );

is($hashref->{'=~'}{regex},   qr/foo/, "regex rearanged");
is($hashref->{'=='}{numbers}, 123,     "number rearagned");
is($hashref->{'eq'}{string},  "foo",   "string rearagned");


########################################################################

# fake database package
package FakeDBI;
sub new { return bless {}, shift };
sub quote { return "qtd<$_[1]>" };
