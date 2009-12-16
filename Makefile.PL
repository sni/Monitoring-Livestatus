# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name         'Nagios-MKLivestatus';
all_from     'lib/Nagios/MKLivestatus.pm';
perl_version '5.006';
license      'perl';

requires 'IO::Socket::UNIX';
requires 'IO::Socket::INET';
requires 'threads'           => '1.07';
requires 'Thread::Queue'     => '2.11';
test_requires 'File::Copy::Recursive';

auto_install;
WriteAll;
