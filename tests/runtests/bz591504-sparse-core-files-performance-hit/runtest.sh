#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of bz591504-sparse-core-files-performance-hit
#   Description: test sparse core files performance hit
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

. /usr/share/beakerlib/beakerlib.sh

TEST="bz591504-sparse-core-files-performance-hit"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
	yum-builddep -y gdb
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	yumdownloader --source gdb
	yum-builddep -y gdb-*.src.rpm
	rpm -ivh gdb-*.src.rpm
	specfile="$(rpm --eval '%_specdir')/gdb.spec"
	#rpmbuild -bc $specfile
	rpmbuild -bp $specfile
	gdbtestdir="$(rpm --eval '%_builddir')/gdb-*/gdb/testsuite"
	pushd $gdbtestdir
	rpm --eval '%configure' | sh # ./configure
	make site.exp
    rlPhaseEnd

    rlPhaseStartTest
	goldratio=5
	times=3
	# Here's the time spent in test when abrt is stopped
	stoptime=0

	service abrtd stop
	# Test run
	runtest gdb.base/bigcore.exp &> /dev/null
	for run in $(seq $times); do
		rlRun "/usr/bin/time -f '%e' -o bigcore-stop.time.$run runtest gdb.base/bigcore.exp"
	done
	for cnt in $(seq $times); do
		stoptime=$(echo "$(cat bigcore-stop.time.$cnt) + $stoptime" | bc -l)
	done
	stoptime=$(echo "$stoptime / $times" | bc)
	echo "Stop time is set to: $stoptime"

	service abrtd start
	starttimeout=$(echo "$goldratio * $stoptime" | bc)
	echo "Start timeout is set to: $starttimeout"
	# Test run
	runtest gdb.base/bigcore.exp &> /dev/null
	for run in $(seq $times); do
		# run w/ abrt on should not take more that five times compared to run w/ abrt turned off
		rlWatchdog "runtest gdb.base/bigcore.exp" $starttimeout
		ec=$?
		echo "Exit code: $ec"
		rlAssert0 "runtest gdb.base/bigcore.exp performed fine" $ec
	done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd" # $gdbtestdir
        rlRun "popd" # $TmpDir
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
