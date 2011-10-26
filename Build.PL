use Module::Build;
my $build = new Module::Build
(
  module_name    => 'Test::DatabaseRow',
  license        => 'perl',
  requires       => {
                      'Test::Builder' => 0.15,
                      'DBI'           => 0, 
                    },
  recommends     => {
                    },
  build_requires => { 'Test::Builder::Tester' => '0.09'
                   },
  create_makefile_pl => 'traditional',
);
$build->create_build_script;
