#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of btparser-make-check
#   Description: Runs make check in btparser's sources
#   Author: Michal Nowak <mnowak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 3 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

TEST="btparser-make-check"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
	rlShowRunningKernel

	TmpDir=$(mktemp -d)
	pushd $TmpDir

	git clone git://git.fedorahosted.org/btparser.git
	pushd btparser/
	yum-builddep -y --nogpgcheck btparser
	./autogen.sh
	rpm --eval '%configure' | sh # ./configure
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "make check" 0 "Make check"
    rlPhaseEnd

    rlPhaseStartCleanup
	popd # btparser/
	popd # TmpDir
	rm -rf $TmpDir
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
