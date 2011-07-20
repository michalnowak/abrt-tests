#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of bz652338-removed-proc-PID
#   Description: Tests if abrt survives non-existent /proc/<PID>/ file
#   Author: Michal Nowak <mnowak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

TEST="bz652338-removed-proc-PID"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	core_pipe_limit_bkp="$(cat /proc/sys/kernel/core_pipe_limit)"
	rlRun "echo 1 > /proc/sys/kernel/core_pipe_limit" 0 "Set core_pipe_limit to 1 from previous $core_pipe_limit_bkp"
        rlRun "yum install -y mlocate" 0 "Install locate & updatedb binaries"
    rlPhaseEnd

    rlPhaseStartTest
	tail -f -n 0 /var/log/messages > var-log-messages &

	sleep 2

	rlRun "sleep 5 &" 0 "Exec process #1"
	rlRun "sleep 10 &" 0 "Exec process #2"
	rpmquery -al > /dev/null 2>&1 &
	updatedb &
	locate a > /dev/null &

	rlRun "jobs" 0 "List background jobs"

	killall -11 rpmquery &
	killall -11 updatedb &
	killall -11 locate &
	rlRun "kill -11 %2" 0 "Kill process #1"
	rlRun "kill -11 %3" 0 "Kill process #2"

	rlRun "report-cli -l -f"
	kill %1 || kill -9 %1 # kill tailf

	echo
	rlLog "var-log-messages output"
	cat var-log-messages
	echo
	rlAssertGrep "Skipping core dump" var-log-messages

	rlRun "report-cli -l -f | grep -i package | grep abrt" 1 "abrt did not crashed" ||\
		rlLog "$(report-cli -l -f | grep package | grep abrt)"

	dirs="$(report-cli -l -f | grep Directory | awk '{ print $2 }')"
	for dir in $dirs; do
		report-cli -d $dir
	done
    rlPhaseEnd

    rlPhaseStartCleanup
	rlRun "echo $core_pipe_limit_bkp > /proc/sys/kernel/core_pipe_limit" 0 "Restore core_pipe_limit back to $core_pipe_limit_bkp"
	rlBundleLogs abrt var-log-messages
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
