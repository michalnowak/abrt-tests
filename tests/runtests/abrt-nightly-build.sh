#!/bin/bash

. /usr/share/beakerlib/beakerlib.sh

PACKAGE="abrt"
TEST="abrt-nightly-build"

rlJournalStart

rlPhaseStartSetup
	rlShowRunningKernel

	TmpDir=`mktemp -d`
	pushd $TmpDir

	git clone git://git.fedorahosted.org/libreport.git
	pushd libreport/
	yum-builddep -y --nogpgcheck libreport

	# stupid workaround
	yum reinstall -y "*docbook*"

	./autogen.sh
	rpm --eval '%configure' | sh # ./configure
	make srpm
	rlRun "rpmbuild --rebuild libreport-*.src.rpm" 0 "Build libreport RPMs"
	make
	make install
	createrepo /root/rpmbuild/RPMS/*/
	popd # libreport/

	cat > /etc/mock/fedora-15-x86_64.cfg <<__END__
config_opts['root'] = 'fedora-15-x86_64'
config_opts['target_arch'] = 'x86_64'
config_opts['legal_host_arches'] = ('x86_64',)
config_opts['chroot_setup_cmd'] = 'groupinstall buildsys-build'
config_opts['dist'] = 'fc15'  # only useful for --resultdir variable subst

config_opts['yum.conf'] = """
[main]
cachedir=/var/cache/yum
debuglevel=1
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1
syslog_ident=mock
syslog_device=
# grub/syslinux on x86_64 need glibc-devel.i386 which pulls in glibc.i386, need to exclude all
# .i?86 packages except these.
#exclude=[0-9A-Za-fh-z]*.i?86 g[0-9A-Za-km-z]*.i?86 gl[0-9A-Za-hj-z]*.i?86 gli[0-9A-Zac-z]*.i?86 glib[0-9A-Za-bd-z]*.i?86
# The above is not needed anymore with yum multilib policy of "best" which is the default in Fedora.

# repos

[fedora]
name=fedora
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-15&arch=x86_64
failovermethod=priority

[updates-released]
name=updates
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f15&arch=x86_64
failovermethod=priority

[updates-testing]
name=Fedora Test Updates
failovermethod=priority
baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/testing/15/x86_64/


[local2]
name=local2
baseurl=file:///root/rpmbuild/RPMS/x86_64/
"""
__END__

	rlRun "git clone git://git.fedorahosted.org/abrt.git" 0 "Clone abrt.git"
	yum-builddep -y --nogpgcheck abrt
	rpmquery btparser-devel > /dev/null || yum install -y btparser-devel --enablerepo="updates-testing"
	/usr/sbin/useradd test --groups mock --create-home
rlPhaseEnd

rlPhaseStartTest "Build ABRT"
	pushd abrt/
	rlRun "./autogen.sh"
	rlRun "rpm --eval '%configure' | sh" 0 "Configure" # ./configure
	make srpm
	cp abrt-*.src.rpm ~test/abrt.src.rpm
	rlRun "su - test -c 'mock -v -r fedora-15-x86_64 ~test/abrt.src.rpm'" 0 "Build ABRT in Mock"
	yum install -y /var/lib/mock/fedora-15-x86_64/result/abrt* /root/rpmbuild/RPMS/*/libreport*.rpm
	yum remove -y "abrt*" "libreport*"
	pushd ../libreport/
	make install
	popd
	rlRun "make"
	rlRun "make install"
	sed -i 's/OpenGPGCheck.*=.*yes/OpenGPGCheck = no/' /etc/abrt/abrt.conf
	popd # abrt/
rlPhaseEnd

#rlPhaseStartTest "Test Install ABRT"
#	rlRun "rpm -Uvh --test /var/lib/mock/fedora-15-x86_64/result/*.rpm" 0 "ABRT is installable"
#rlPhaseEnd

rlPhaseStartCleanup
	popd # TmpDir

	rm -rf $TmpDir
	userdel -r test

rlPhaseEnd

rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary

rlJournalEnd
