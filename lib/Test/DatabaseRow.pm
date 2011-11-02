package Test::DatabaseRow;

# require at least a version of Perl that is merely ancient, but not
# prehistoric
use 5.006;

use strict;
use warnings;

use Carp;

# set row_ok to be exported
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(row_ok not_row_ok);

# set the version number
our $VERSION = "1.05";

# horrible, horrible global vars
our $dbh;
our $force_utf8;

# okay, try loading Regexp::Common

# if we couldn't load Regexp::Common then we use the one regex that I
# copied and pasted from there that we need.  We could *always* do
# this, but at least this way if someone cares enough they can upgrade
# Regexp::Common when it changes and they don't have to wait for me to
# upgrade this module too

our %RE;
unless (eval { require Regexp::Common; Regexp::Common->import; 1 }) {
  $RE{num}{real} = qr/
    (?:(?i)(?:[+-]?)(?:(?=[0123456789]|[.])
    (?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)
    (?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))
  /x;
}

=head1 NAME

Test::DatabaseRow - simple database tests

=head1 SYNOPSIS

 use Test::More tests => 3;
 use Test::DatabaseRow;

 # set the default database handle
 local $Test::DatabaseRow::dbh = $dbh;

 # sql based test
 row_ok( sql   => "SELECT * FROM contacts WHERE cid = '123'",
         tests => [ name => "trelane" ],
         label => "contact 123's name is trelane");

 # test with shortcuts
 row_ok( table => "contacts",
         where => [ cid => 123 ],
         tests => [ name => "trelane" ],
         label => "contact 123's name is trelane");

 # complex test
 row_ok( table => "contacts",
         where => { '='    => { name   => "trelane"            },
                    'like' => { url    => '%shortplanks.com'   },},

         tests => { '=='   => { cid    => 123,
                                num    => 134                  },
                    'eq'   => { person => "Mark Fowler"        },
                    '=~'   => { road   => qr/Liverpool R.?.?d/ },},

         label => "trelane entered into contacts okay" );

=head1 DESCRIPTION

This is a simple module for doing simple tests on a database, primarily
designed to test if a row exists with the correct details in a table or
not.

This module exports several functions.

=head2 row_ok

The C<row_ok> function takes named attributes that control which rows
in which table it selects, and what tests are carried out on those rows.

By default it performs the tests against only the first row returned
from the database, but parameters passed to it can alter that
behavior.

=over 4

=item dbh

The database handle that the test should use.  In lieu of this
attribute being passed the test will use whatever handle is set
in the C<$Test::DatabaseRow::dbh> global variable.

=item sql

Manually specify the SQL to select the rows you want this module to execute.

This can either be just a plain string, or it can be an array ref with the
first element containing the SQL string and any further elements containing
bind variables that will be used to fill in placeholders.

  # using the plain string version
  row_ok(sql   => "SELECT * FROM contacts WHERE cid = '123'",
         tests => [ name => "Trelane" ]);

  # using placeholders and bind variables
  row_ok(sql   => [ "SELECT * FROM contacts WHERE cid = ?", 123 ],
         tests => [ name => "Trelane" ]);

=item table

Build the SELECT statement programatically.  This parameter contains the name
of the table the  SELECT statement should be executed against.  You cannot
pass both a C<table> parameter and a C<sql> parameter.  If you specify
C<table> you B<must> pass a C<where> parameter also (see below.)

=item where

Build the SELECT statement programatically.  This parameter should contain
options that will combine into a WHERE clause in order to select the row
that you want to test.

This options normally are a hash of hashes.  It's a hashref keyed by SQL
comparison operators that has in turn values that are further hashrefs
of column name and values pairs.  This sounds really complicated, but
is quite simple once you've been shown an example.  If we could get
get the data to test with a SQL like so:

  SELECT *
    FROM tablename
   WHERE foo  =    'bar'
     AND baz  =     23
     AND fred LIKE 'wilma%'
     AND age  >=    18

Then we could have the function build that SQL like so:

  row_ok(table => "tablename",
         where => { '='    => { foo  => "bar",
                                baz  => 23,       },
                    'LIKE' => { fred => 'wimla%', },
                    '>='   => { age  => '18',     },});

Note how each different type of comparison has it's own little hashref
containing the column name and the value for that column that the
associated operator SQL should search for.

This syntax is quite flexible, but can be overkill for simple tests.
In order to make this simpler, if you are only using '=' tests you
may just pass an arrayref of the columnnames / values.  For example,
just to test

  SELECT *
    FROM tablename
   WHERE foo = 'bar'
     AND baz = 23;

You can simply pass

  row_ok(table => "tablename",
         where => [ foo  => "bar",
                    baz  => 23,    ]);

Which, in a lot of cases, makes things a lot quicker and simpler to
write.

NULL values can confuse things in SQL.  All you need to remember is that
when building SQL statements use C<undef> whenever you want to use a
NULL value.  Don't use the string "NULL" as that'll be interpreted as
the literal string made up of a N, a U and two Ls.

As a special case, using C<undef> either in a C<=> or in the short
arrayref form will cause a "IS" test to be used instead of a C<=> test.
This means the statements:

  row_ok(table => "tablename",
         where => [ foo  => undef ],)

Will produce:

  SELECT *
    FROM tablename
   WHERE foo IS NULL

=item tests

The comparisons that you want to run between the expected data and the
data in the first line returned from the database.  If you do not
specify any tests then the test will simply check if I<any> rows are
returned from the database and will pass no matter what they actually
contain.

Normally this is a hash of hashes in a similar vein to C<where>.
This time the outer hash is keyed by Perl comparison operators, and
the inner hashes contain column names and the expected values for
these columns.  For example:

  row_ok(sql   => $sql,
         tests => { "eq" => { wibble => "wobble",
                              fish   => "fosh",    },
                    "==" => { bob    => 4077       },
                    "=~" => { fred   => qr/barney/ },},);

This checks that the column wibble is the string "wobble", column fish
is the string "fosh", column bob is equal numerically to 4077, and
that fred contains the text "barney".  You may use any infix
comparison operator (e.g. "<", ">", "&&", etc, etc) as a test key.

The first comparison to fail (to return false) will cause the whole
test to fail, and debug information will be printed out on that comparison.

In a similar fashion to C<where> you can also pass a arrayref for
simple comparisons.  The function will try and Do The Right Thing with
regard to the expected value for that comparison.  Any expected value that
looks like a number will be compared numerically, a regular expression
will be compared with the C<=~> operator, and anything else will
undergo string comparison.  The above example therefore could be
rewritten:

  row_ok(sql   => $sql,
         tests => [ wibble => "wobble",
                    fish   => "fosh",
                    bob    => 4077,
                    fred   => qr/barney/ ]);

=item verbose

Setting this option to a true value will cause verbose diagnostics to
be printed out during any failing tests.  You may also enable this
feature by setting either C<$Test::DatabaseRow::verbose> variable the
C<TEST_DBROW_VERBOSE> environmental variable to a true value.

=item store_rows

Sometimes, it's not enough to just use the simple tests that
B<Test::DatabaseRow> offers you.  In this situation you can use the
C<store_rows> function to get at the results that row_ok has extacted
from the database.  You should pass a reference to an array for the
results to be stored in;  After the call to C<row_ok> this array
will be populated with one hashref per row returned from the database,
keyed by column names.

  row_ok(sql => "SELECT * FROM contact WHERE name = 'Trelane'",
         store_rows => \@rows);

  ok(Email::Valid->address($rows[0]{'email'}));

=item store_row

The same as C<store_rows>, but only the stores the first row returned
in the variable.  Instead of passing in an array reference you should
pass in either a reference to a hash...

  row_ok(sql => "SELECT * FROM contact WHERE name = 'Trelane'",
         store_rows => \%row);

  ok(Email::Valid->address($row{'email'}));

...or a reference to a scalar which should be populated with a
hashref...

  row_ok(sql => "SELECT * FROM contact WHERE name = 'Trelane'",
         store_rows => \$row);

  ok(Email::Valid->address($row->{'email'}));

=back

=head2 Checking the number of results

By default C<row_ok> just checks the first row returned from the
database matches the criteria passed.  By setting the parameters below
you can also cause the module to check that the correct number of rows
are returned from by the select statment (though only the first row
will be tested against the test conditions.)

=over 4

=item results

Setting this parameter causes the test to ensure that the database
returns exactly this number of rows when the select statement is
executed.  Setting this to zero allows you to ensure that no matching
rows were found by the database, hence this parameter can be used
for negative assertions about the database.

  # assert that Trelane is _not_ in the database
  row_ok(sql     => "SELECT * FROM contacts WHERE name = 'Trelane'",
         results => 0 );

  # convience function that does the same thing
  not_row_ok(sql => "SELECT * FROM contacts WHERE name = 'Trelane'")

=item min_results / max_results

This parameter allows you to test that the database returns
at least or no more than the passed number of rows when the select
statement is executed.

=back

=cut

sub row_ok {
  my %args = @_;

  # check the database handle was passed / we have it already
  $args{dbh} ||= $Test::DatabaseRow::dbh;
  unless ($args{dbh})
    { croak "No dbh passed and no default dbh set"; }

  # do we need to load the Encode module?  Don't do this unless we have to
  my $want_utf8_munging = $args{force_utf8} || $force_utf8;
  if ($want_utf8_munging && !$INC{"Encode.pm"}) {
    eval "use Encode; 1"
      or croak "Can't load Encode, but force_utf8 is enabled";
  }

  my @data;
  my ($sql, @bind);
  eval {
    # make all database problems fatal
    local $args{dbh}{RaiseError} = 1;

    # get the SQL and execute it
    ($sql, @bind) = _build_select(%args);
    my $sth = $args{dbh}->prepare($sql);
    $sth->execute( @bind );

    # store the results
    while (my ($row_data) = $sth->fetchrow_hashref) {
      # munge the utf8 flag if we need to
      if ($want_utf8_munging)
        { Encode::_utf8_on($_) foreach values %{ $row_data } }

      # store the data
      push @data, $row_data;
    }
  1 } or croak $@;

  # store the results in the passed data structure if there is
  # one.  We can use the actual data structures as control won't
  # return to the end of the routine.  In theory some really weird
  # stuff could happen if this was a a shared variable between
  # multiple threads, but let's just hope nothing does that.

  if ($args{store_rows}) {
    croak "Must pass an arrayref in 'store_rows'"
      unless ref($args{store_rows}) eq "ARRAY";
    @{ $args{store_rows} } = @data;
  }

  if ($args{store_row}) {
    if (ref($args{store_row}) eq "HASH") {
      %{ $args{store_row} } = %{ $data[0] };
    } else {
      unless (eval { ${ $args{store_row} } = $data[0]; 1 }) {
      	if (index($@,"Not a SCALAR reference") != -1)
          { croak "Must pass a scalar or hash reference with 'store_row'" }
        croak $@;
      }
    }
  }

  # work out what we're called
  my $label = $args{label} || "simple db test";

  # perform tests on the data

  # fail the test if we're running just one test and no matching row was
  # returned
  my $nrows = @data;
  if(!defined($args{min_results}) &&
     !defined($args{max_results}) &&
     !defined($args{results}) &&
     $nrows == 0) {
    _fail($label,"No matching row returned");
    _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
    return 0;
  }

  # check we got the exected number of rows back if they specified exactly
  if(defined($args{results}) && $nrows != $args{results}) {
    _fail($label, "Got the wrong number of rows back from the database.",
                  "  got:      $nrows rows back",
                  "  expected: $args{results} rows back");
    _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
    return 0;
  }

  # check we got enough matching rows back
  if(defined($args{min_results}) && $nrows < $args{min_results}) {
    _fail($label,"Got too few rows back from the database.",
                 "  got:      $nrows rows back",
                 "  expected: $args{min_results} rows or more back");
    _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
    return 0;
  }

  # check we got didn't get too many matching rows back
  if(defined($args{max_results}) && $nrows > $args{max_results}) {
    _fail($label,"Got too many rows back from the database.",
                 "  got:      $nrows rows back",
                 "  expected: $args{max_results} rows or fewer back");
    _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
    return 0;
  }

  my $tests = $args{tests}
    or return _pass($label);

  # is this a dtrt operator?  If so, call _munge_array to
  # make it into a hashref if that's possible
  if (ref $tests eq "ARRAY")
    { eval { $tests = _munge_array($tests); 1 } or croak $@ }

  # check we've got a hash
  unless (ref($tests) eq "HASH")
    { croak "Can't understand the argument passed in 'tests'" }

  # pull the first line off the data list
  my $data = shift @data;

  # now for each test
  foreach my $oper (sort keys %{$tests}) {
    my $valuehash = $tests->{ $oper };

    # check it's a hashref (hopefully of colnames/expected vals)
    unless (ref($valuehash) eq "HASH")
      { croak "Can't understand the argument passed in 'tests'" }

    # process each entry in that hashref
    foreach my $colname (sort keys %{$valuehash}) {
      # work out what we expect
      my $expect = $valuehash->{ $colname };
      my $got    = $data->{ $colname };

      unless (exists($data->{ $colname })) {
        croak "No column '$colname' returned from sql" if $args{sql};
        croak "No column '$colname' returned from table '$args{table}'";
      }

      # try the comparison
      unless (do {
        # disable warnings as we might compare undef
	      local $SIG{__WARN__} = sub {}; # $^W not work

	      # do a string eval
        eval "\$got $oper \$expect"
      }) {
      	_fail($label,"While checking column '$colname'\n");
        if( $oper =~ /\A (?:eq|==) \z/x ) {
      	  _is_diag($got, $oper, $expect);
      	  _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
      	  return 0;
        }
    	  _cmp_diag($got, $oper, $expect);
    	  _sql_diag($args{dbh}->{Name}, $sql, @bind) if _verbose(%args);
    	  return 0;
      }
    }
  }

  # okay, got this far, must have been okay
  return _pass($label);
}

sub _munge_array {
  # get the array of tests
  my @tests = @{ shift() };

  # new place where we're storing our freshly created hash
  my $newtests = {};

  if (@tests % 2 != 0)
    { croak "Can't understand the passed test arguments" }

  # for each key/value pair
  while (@tests) {
    my $key   = shift @tests;
    my $value = shift @tests;

    # set the comparator based on the type of value we're comparing
    # against.  This can lead to some annoying cases, but if they
    # want proper comparison they can use the non dwim mode

    if (!defined($value)) {
      $newtests->{'eq'}{ $key } = $value;
    } elsif (ref($value) eq "Regexp") {
      $newtests->{'=~'}{ $key } = $value;
    } elsif ($value =~ /\A $Test::DatabaseRow::RE{num}{real} \z/x) {
      $newtests->{'=='}{ $key } = $value;
    } else {
      # default to string comparison
      $newtests->{'eq'}{ $key } = $value;
    }
  }

  return $newtests;
}

# build a sql statement
sub _build_select {
  my %args = @_;

  # was SQL manually passed?
  if ($args{sql}) {
    return (ref($args{sql}) eq "ARRAY") ? @{ $args{sql} } : ($args{sql});
  }

  my $select = "SELECT * FROM ";

  ###
  # the table
  ###

  my $table = $args{table}
   or croak "No 'table' or 'sql' passed as an argument";

  $select .= $table . " ";

  ###
  # the where clause
  ###

  my $where = $args{where}
   or croak "'table' passed as an argument, but no 'where' argument";

  # convert it all to equals tests if we were using the
  # shorthand notation
  if (ref $where eq "ARRAY") {
    $where = { "=" => { @{$where} } };
  }

  # check we've got a hash
  unless (ref($where) eq "HASH")
    { croak "Can't understand the argument passed in 'where'" }

  $select .= "WHERE ";
  my @conditions;
  foreach my $oper (sort keys %{$where}) {
    my $valuehash = $where->{ $oper };

    unless (ref($valuehash) eq "HASH")
      { croak "Can't understand the argument passed in 'where'" }

    foreach my $field (sort keys %{$valuehash}) {
      # get the value
      my $value = $valuehash->{ $field };

      # should this be "IS NULL" rather than "= ''"
      if ($oper eq "=" && !defined($value)) {
      	push @conditions, "$field IS NULL";
      } elsif (!defined($value)) {
      	# just an undef.  I hope $oper is "IS" or "IS NOT"
      	push @conditions, "$field $oper NULL";
      } else {
      	# proper value, quote it properly
      	push @conditions, "$field $oper ".$args{dbh}->quote($value);
      }
    }
  }

  $select .= join ' AND ', @conditions;
  return ($select);
}

=head2 not_row_ok

The not_row_ok is shorthand notation for "the database returned
no rows when I executed this SQL".

For example:

  not_row_ok(sql => <<'SQL');
    SELECT *
      FROM languages
     WHERE name = 'Java'
  SQL

Checks to see the database doesn't have any rows in the language
table that have a name "Java".  It's exactly the same as if
we'd written:

  row_ok(sql => <<'SQL', results => 0);
    SELECT *
      FROM languages
     WHERE name = 'Java'
  SQL

=cut

sub not_row_ok
{
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return row_ok(@_, results => 0);
}

=head2 Other SQL modules

The SQL creation routines that are part of this module are designed
primarily with the concept of getting simple single rows out of the
database with as little fuss as possible.  This having been said, it's
quite possible that you need to use a more complicated SQL generation
scheme than the one provided.

This module is designed to work (hopefully) reasonably well with the
other modules on CPAN that can automatically create SQL for you.  For
example, B<SQL::Abstract> is a module that can manufacture much more
complex select statements that can easily be 'tied in' to C<row_ok>:

  use SQL::Abstract;
  use Test::DatabaseRow;
  my $sql = SQL::Abstract->new();

  # more complex routine to find me heuristically by looking
  # for any one of my nicknames and my street address
  row_ok(sql   => [ $sql->select("contacts",
                                 "*",
                                 { name => [ "Trelane",
                                             "Trel",
                                             "MarkF" ],
                                   road => { 'like' => "Liverpool%" },
                                 })],
         tests => [ email => 'mark@twoshortplanks.com' ],
         label => "check mark's email address");

=head2 utf8 hacks

Often, you may store data utf8 data in your database.  However, many
modern databases still do not store the metadata to indicate the data
stored in them is utf8 and thier DBD drivers may not set the utf8 flag
on values returned to Perl.  This means that data returned to Perl
will be treated as if it is encoded in your normal charecter set
rather than being encoded in utf8 and when compared to a byte for
byte an identical utf8 string may fail comparison.

    # this will fail incorrectly on data coming back from
    # mysql since the utf8 flags won't be set on returning data
    use utf8;
    row_ok(sql   => $sql,
           tests => [ name => "Napol\x{e9}on" ]);

The solution to this is to use C<Encode::_utf_on($value)> on each
value returned from the database, something you will have to do
yourself in your application code.  To get this module to do this for
you you can either pass the C<force_utf8> flag to C<row_ok>.

    use utf8;
    row_ok(sql        => $sql,
           tests      => [ name => "Napol\x{e9}on" ],
           force_utf8 => 1);

Or set the global C<$Test::DatabaseRow::force_utf8> variable

   use utf8;
   local $Test::DatabaseRow::force_utf8 = 1;
   row_ok(sql        => $sql,
          tests      => [ name => "Napol\x{e9}on" ]);

Please note that in the above examples with C<use utf8> enabled I
could have typed unicode eacutes into the string directly rather than
using the C<\x{e9}> escape sequence, but alas the pod renderer you're
using to view this documentation would have been unlikely to render
those examples correctly, so I didn't.

Please also note that if you want the debug information that this
module creates to be redered to STDERR correctly for your utf8
terminal then you may need to stick

   binmode STDERR, ":utf8";

At the top of your script.

=head1 BUGS

You I<must> pass a C<sql> or C<where> argument to limit what is
returned from the table.  The case where you don't want to is so
unlikely (and it's much more likely that you've written a bug in your
test script) that omitting both of these is treated as an error.  If
you I<really> need to not pass a C<sql> or C<where> argument, do C<< where
=> [ 1 => 1 ] >>.

We currently only test the first line returned from the database.
This probably could do with rewriting so we test all of them.  The
testing of this data is the easy bit; Printing out useful diagnostic
infomation is hard.  Patches welcome.

Passing shared variables (variables shared between multiple threads
with B<threads::shared>) in with C<store_row> and C<store_rows> and
then changing them while C<row_ok> is still executing is just asking
for trouble.

The utf8 stuff only really works with perl 5.8 and later.  It just
goes horribly wrong on earlier perls.  There's nothing I can do to
correct that.  Also, no matter what version of Perl you're running,
currently no way provided by this module to force the utf8 flag to be
turned on for some fields and not on for others.

The inbuilt SQL builder always assumes you mean C<IS NULL> not 
C<= NULL> when you pass in C<undef> in a C<=> section

=head1 AUTHOR

Written by Mark Fowler B<mark@twoshortplanks.com>

Copyright Profero 2003, 2004.  Copyright Mark Fowler 2011.

Some code taken from B<Test::Builder>, written by Michael Schwern.
Some code taken from B<Regexp::Common>, written by Damian Conway.  Neither
objected to it's inclusion in this module.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bugs (and requests for new features) can be reported to the open source
development team at Profero though the CPAN RT system:
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-DatabaseRow>

=head1 SEE ALSO

L<Test::More>, L<DBI>

=cut

########################################################################
# testing functions
########################################################################

# get the test builder singleton
my $tester = Test::Builder->new();

sub _pass {
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return $tester->ok(1, shift);
}

sub _fail {
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  $tester->ok(0, shift);
  $tester->diag($_) foreach @_;
  return 0;
}

 # prints out handy diagnostic text if we're printing out verbose text
sub _sql_diag {
  my ($dbh_name, $sql, @bind) = @_;

  # print out the SQL
  $tester->diag("The SQL executed was:");
  $tester->diag(map { "  $_\n" } split /\n/x, $sql);

  # print out the bound parameters
  if (@bind) {
    $tester->diag("The bound parameters were:");
    foreach my $bind (@bind) {
      if (defined($bind))
       { $tester->diag("  '$bind'") }
      else
       { $tester->diag("  undef") }
    }
  }

  # print out the database
  return $tester->diag("on database '$dbh_name'");
}

# returns true iff we should be printing verbose diagnostic messages
sub _verbose {
  my %args = @_;
  return $args{verbose}
    || $Test::DatabaseRow::verbose
    || $ENV{TEST_DBROW_VERBOSE};
}

# _cmp_diag and is__diag were originally private functions in
# Test::Builder (and were written by Schwern).  In theory we could
# call them directly there and it should make no difference but since
# they are private functions they could change at any time (or even
# vanish) as new versions of Test::Builder are released.  To protect
# us from that happening we've defined them here.

sub _cmp_diag {
  my($got, $type, $expect) = @_;

  $got    = defined $got    ? "'$got'"    : 'undef';
  $expect = defined $expect ? "'$expect'" : 'undef';

  return $tester->diag(sprintf <<"DIAGNOSTIC", $got, $type, $expect);
    %s
        %s
    %s
DIAGNOSTIC
}

sub _is_diag {
  my($got, $type, $expect) = @_;

  foreach my $val (\$got, \$expect) {
      if( defined ${$val} ) {
          if( $type eq 'eq' ) {
              # quote and force string context
              ${$val} = "'${$val}'"
          }
          else {
              # force numeric context
              ${$val} = ${$val}+0;
          }
      }
      else {
          ${$val} = 'NULL';
      }
  }

  return $tester->diag(sprintf <<"DIAGNOSTIC", $got, $expect);
         got: %s
    expected: %s
DIAGNOSTIC
}

1;

