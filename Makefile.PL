use inc::Module::Install;

name           'Test-DatabaseRow';
all_from       'lib/Test/DatabaseRow.pm';

requires       'DBI'                   => 0;
build_requires 'Test::Builder::Tester' => 0.09;

license 'perl';
githubmeta;

WriteAll;
