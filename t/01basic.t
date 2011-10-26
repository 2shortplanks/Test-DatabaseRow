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

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
	      			      sql   => 
q{SELECT * FROM foo WHERE fooid = 123}))[0],
q{SELECT * FROM foo WHERE fooid = 123},
"simple test");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
	      			      sql   => 
[q{SELECT * FROM foo WHERE fooid = ?}, 123]))[0],
q{SELECT * FROM foo WHERE fooid = ?},
"simple test sql arrayref");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
	      			      sql   => 
[q{SELECT * FROM foo WHERE fooid = ?}, 123]))[1]->[0],
123,
"simple test sql arrayref");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
				      table => "foo",
				      where => { '=' => { fooid => 123 }}))[0],
q{SELECT * FROM foo WHERE fooid = qtd<123>},
"simple test");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
	 			      table => "foo",
				      where => [ fooid => 123 ]))[0],
q{SELECT * FROM foo WHERE fooid = qtd<123>},
"short format test");

###
# multiple items
###

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
				      table => "foo",
				      where => { '=' => { fred   => "wilma" ,
						 	  barney => "betty" ,
						        }
					   }))[0],
q{SELECT * FROM foo WHERE barney = qtd<betty> AND fred = qtd<wilma>},
"simple test");

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
				      table => "foo",
				      where => [ fred => "wilma",
						 barney => "betty",]))[0],
q{SELECT * FROM foo WHERE barney = qtd<betty> AND fred = qtd<wilma>},
"short format test");

###
# multiple multiple items
###

is((Test::DatabaseRow::_build_select( dbh   => $dbh,
				      table => "foo",
				      where => { '=' =>    { fred   => "wilma" ,
							     barney => "betty" ,
							   },
						 'LIKE' => { pet => "dino%" },
					       }))[0],
q{SELECT * FROM foo WHERE barney = qtd<betty> AND fred = qtd<wilma> AND pet LIKE qtd<dino%>},
"multiple");

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


###
# munge array
###

my $hashref = Test::DatabaseRow::_munge_array( [ numbers => 123,
                                              string  => "foo",
                                              regex   => qr/foo/ ] );

is($hashref->{'=~'}{regex},   qr/foo/, "regex rearanged");
is($hashref->{'=='}{numbers}, 123,     "number rearagned");
is($hashref->{'eq'}{string},  "foo",   "string rearagned");


# fake database package
package FakeDBI;
sub new { return bless {}, shift };
sub quote { return "qtd<$_[1]>" };
