#!perl
use strict;
use Test::More;

unless (require Test::Kwalitee) {
    Test::More::plan(
        skip_all => "Test::Kwalitee required for kwalitee assurance"
    );
}
Test::Kwalitee::kwalitee_ok();
done_testing;
