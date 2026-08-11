#!/bin/sh

VERSION=$1
if [ -z "$VERSION" ]; then
    VERSION=0.82
fi
# run from the topdir
curl https://github.com/sni/Monitoring-Livestatus/archive/v${VERSION}.tar.gz > dist/v${VERSION}.tar.gz
mock -r epel-7-x86_64 --resultdir=/tmp/perl-Monitoring-Livestatus --spec=dist/perl-Monitoring-Livestatus.spec --sources=dist/v${VERISON}.tar.gz --buildsrpm && \
mock -r epel-7-x86_64 --resultdir=/tmp/perl-Monitoring-Livestatus /tmp/perl-Monitoring-Livestatus/perl-Monitoring-Livestatus-${VERSION}-1.el7.src.rpm

