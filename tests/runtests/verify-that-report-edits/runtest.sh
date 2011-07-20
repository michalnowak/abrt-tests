#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of verify-that-report-edits
#   Description: Make sure manual edits to reports actually make it into submitted data.
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

TEST="verify-that-report-edits"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
	# Make some noise
	ulimit -c unlimited
	sleep 300 &
	kill -SIGSEGV %1
	sleep 5
	[ -e /tmp/abrt.log ] && log_present="YES" && rlFileBackup /tmp/abrt.log
    rlPhaseEnd

    rlPhaseStartTest
	crash_PATH=$(report-cli -l -f | grep Directory | tail -n1 | awk '{ print $2 }')
	rlLog "PATH=$crash_PATH"
	echo -e "1\n1\n" | EDITOR="./fakeditor.sh" report-cli --report $crash_PATH 2>&1 | tee out
	rlAssertGrep "The report has been updated" out

	smart_quote="$(grep 'smart_quote=' fakeditor.sh | awk -F '"' '{ print $2 }')"
	rlLog "smart_quote=$smart_quote"
	rlAssertGrep "$smart_quote" /tmp/abrt.log
    rlPhaseEnd

    rlPhaseStartCleanup
	rlRun "report-cli --delete $crash_PATH" 0 "Delete $crash_PATH"
	rm -f *core*
	if [ $log_present ]; then
		rlFileRestore
	else
		rm -f /tmp/abrt.log
	fi
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
