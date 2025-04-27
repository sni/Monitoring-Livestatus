Name:           perl-Monitoring-Livestatus
Version:        0.82
Release:        1%{?dist}
Summary:        Perl Nagios Livestatus module
Group:          Development/Libraries
License:        Perl License
URL:            https://github.com/sni/Monitoring-Livestatus
Source0:        https://github.com/sni/Monitoring-Livestatus/archive/v0.82.tar.gz
BuildArch:      noarch
BuildRequires:	perl(Module::Install)	
# Tests only
BuildRequires:  perl(base)
BuildRequires:  perl(Test::More)
BuildRequires:	perl(Cpanel::JSON::XS)
Requires:  perl(:MODULE_COMPAT_%(eval "`perl -V:version`"; echo $version))
Requires:	perl(Cpanel::JSON::XS)

%description
Monitoring::Livestatus can be used to access the data of the check_mk
Livestatus Addon for Nagios and Icinga.

%prep
%setup -q -n Monitoring-Livestatus-%{version}

%build
perl Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
make pure_install PERL_INSTALL_ROOT=%{buildroot}
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'
find %{buildroot} -type d -depth -exec rmdir {} 2>/dev/null ';'
chmod -R u+w %{buildroot}/*

%check
make test

%files
%doc Changes README
%{perl_vendorlib}/Monitoring/
%{_mandir}/man3/*.3*

%changelog
* Sat Nov 10 2018 - 0.82
    - add tls support for tcp livestatus connections

* Fri Jan 26 2018 - 0.80
    - support ipv6 connections
    - change to Cpanel::JSON::XS

* Fri Dec 23 2016 - 0.78
    - fix spelling errors (#5)

* Tue Sep 27 2016 - 0.76
    - fix utf-8 decoding error: missing high surrogate character in surrogate pair
    - fixed typo
    - removed MULTI class

* Fri Apr 22 2011 - 0.74
    - fixed problem with bulk commands

