# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name         'Monitoring-Livestatus';
all_from     'lib/Monitoring/Livestatus.pm';
perl_version '5.006';
license      'perl';

resources(
    'homepage',   => 'http://search.cpan.org/dist/Monitoring-Livestatus/',
    'bugtracker'  => 'http://github.com/sni/Monitoring-Livestatus/issues',
    'repository', => 'http://github.com/sni/Monitoring-Livestatus',
);


requires 'IO::Socket::UNIX';
requires 'IO::Socket::INET';
requires 'Digest::MD5';
requires 'Scalar::Util';
requires 'Test::More'        => '0.87';
requires 'Thread::Queue'     => '2.11';
requires 'utf8';
requires 'Encode';
requires 'JSON::XS';

# test requirements
test_requires 'File::Copy::Recursive';
test_requires 'Test::Pod' => 1.14;
test_requires 'Test::Perl::Critic';
test_requires 'Test::Pod::Coverage';
test_requires 'Perl::Critic::Policy::Dynamic::NoIndirect';
test_requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs';
test_requires 'Perl::Critic::Policy::ValuesAndExpressions::ProhibitAccessOfPrivateData';

auto_install;
WriteAll;
