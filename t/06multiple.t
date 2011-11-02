#!/usr/bin/perl -w

use strict;

use Test::More tests => 8;

use Test::DatabaseRow;
use Test::Builder::Tester;

$Test::DatabaseRow::dbh = FakeDBI->new(results => 2);

test_out("ok 1 - matches");
row_ok(table => "dummy",
       where => [ dummy => "dummy" ],
       tests => [ fooid => 123,
                  name  => "fred",
                  name  => qr/re/  ],
       label => "matches");
test_test("basic");

test_out("ok 1 - matches");
row_ok(table   => "dummy",
       where   => [ dummy => "dummy" ],
       results => 2,
       label   => "matches");
test_test("right number");

test_out("ok 1 - matches");
row_ok(table       => "dummy",
       where       => [ dummy => "dummy" ],
       min_results => 2,
       label       => "matches");
test_test("right number, min");

test_out("ok 1 - matches");
row_ok(table       => "dummy",
       where       => [ dummy => "dummy" ],
       max_results => 2,
       label       => "matches");
test_test("right number, max");

test_out("not ok 1 - matches");
test_fail(+4);
test_diag("Got the wrong number of rows back from the database.");
test_diag("  got:      2 rows back");
test_diag("  expected: 3 rows back");
row_ok(table   => "dummy",
       where   => [ dummy => "dummy" ],
       results => 3,
       label   => "matches");
test_test("wrong number");

test_out("not ok 1 - matches");
test_fail(+4);
test_diag("Got too few rows back from the database.");
test_diag("  got:      2 rows back");
test_diag("  expected: 3 rows or more back");
row_ok(table   => "dummy",
       where   => [ dummy => "dummy" ],
       min_results => 3,
       label   => "matches");
test_test("wrong number, min");

test_out("not ok 1 - matches");
test_fail(+4);
test_diag("Got too many rows back from the database.");
test_diag("  got:      2 rows back");
test_diag("  expected: 1 rows or fewer back");
row_ok(table   => "dummy",
       where   => [ dummy => "dummy" ],
       max_results => 1,
       label   => "matches");
test_test("wrong number, max");

$Test::DatabaseRow::dbh = FakeDBI->new(results => 0);

test_out("ok 1 - matches");
not_row_ok(table   => "dummy",
           where   => [ dummy => "dummy" ],
           label   => "matches");
test_test("not_row");

# fake database package
package FakeDBI;
sub new { my $class = shift; return bless { @_ }, $class };
sub quote { return "qtd<$_[1]>" };

sub prepare
{
  my $this = shift;

  # die if we need to
  if ($this->fallover)
    { die "Khaaaaaaaaaaaaan!" }

  return FakeSTH->new($this);
}

sub results  { return $_[0]->{results}  }
sub nomatch  { return $_[0]->{nomatch}  }
sub fallover { return $_[0]->{fallover} }

package FakeSTH;
sub new { return bless { parent => $_[1] }, $_[0] };
sub execute { return 1 };

sub fetchrow_hashref
{
  my $this = shift;
  my $parent = $this->{parent};

  $this->{returned}++;

  return if $parent->nomatch;
  return if $this->{returned} > $parent->results;

  if ($this->{returned} == 1)
    { return { fooid => 123, name => "fred" } }

  if ($this->{returned} == 2)
    { return { fooid => 124, name => "bert" } }

  if ($this->{returned} == 3)
    { return { fooid => 125, name => "ernie" } }

  # oops, someone wanted more results than we prepared
  return;
}
