#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of cli-sanity
#   Description: does sanity on report-cli
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

TEST="cli-sanity"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartTest --version
	rlRun "report-cli --version | grep 'report-cli'"
#	rlAssertEquals "report-cli and RPM claim the same version of installed abrt" "$(report-cli -V | awk '{ print $2 }')" "$(rpmquery --qf='%{VERSION}' abrt)"
    rlPhaseEnd

    rlPhaseStartTest --help
	rlRun "report-cli --help" 0
	rlRun "report-cli --help 2>&1 | grep 'Usage: report-cli'"
    rlPhaseEnd


    rlPhaseStartTest --list
	ulimit -c unlimited
	rpmverify $(xargs rpmquery -la) > /dev/null &
	kill -11 %1
	sleep 3
	rlRun "report-cli -l | grep -i 'Executable'"
	rlRun "report-cli -l | egrep -i 'Package.*bash|Package.*rpm'"
    rlPhaseEnd

    rlPhaseStartTest "--list -f" # list full
	rlRun "report-cli -l | grep -i 'Executable'"
	rlRun "report-cli -l | egrep -i 'Package.*bash|Package.*rpm'"
    rlPhaseEnd

    rlPhaseStartTest "--report FAKEDIR"
	rlRun "report-cli --report FAKEDIR" 1
    rlPhaseEnd

    rlPhaseStartTest "--report always DIR"
	DIR=$(report-cli -l -f | grep 'Directory' | head -n1 | awk '{ print $2 }')
	EDITOR='cat' echo "1" | report-cli --report $DIR -y > output.out 2>&1

	echo "* * *"
	cat output.out
	echo "* * *"

	rlAssertGrep "Email was sent to" output.out
	rlAssertGrep "The report was appended to" output.out
    rlPhaseEnd


    rlPhaseStartTest "--delete FAKEDIR"
	rlRun "report-cli --delete FAKEDIR" 1
    rlPhaseEnd

    rlPhaseStartTest "--delete DIR"
	DIR_DELETE=$(report-cli -l -f | grep 'Directory' | head -n1 | awk '{ print $2 }')
	rlRun "report-cli --delete $DIR_DELETE"
    rlPhaseEnd

    rlPhaseStartCleanup
	rm -f *core* output.out
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd

