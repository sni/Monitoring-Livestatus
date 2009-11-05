use 5.008000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Nagios::MKLivestatus',
    VERSION_FROM      => 'lib/Nagios/MKLivestatus.pm', # finds $VERSION
    PREREQ_PM         => { threads => 1.07 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Nagios/MKLivestatus.pm', # retrieve abstract from module
       AUTHOR         => 'Sven Nierlein <nierlein@cpan.org>') : ()),
);
