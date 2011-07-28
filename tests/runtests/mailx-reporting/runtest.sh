#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of mailx-reporting
#   Description: Tests Mailx
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

. /usr/share/beakerlib/beakerlib.sh

TEST="mailx-reporting"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        cp mailx.conf $TmpDir
        rlRun "pushd $TmpDir"
        sleep 3m &
        sleep 2
        kill -11 %1
        sleep 3
        rlLog "report-cli: $(report-cli -l -f)"
        PATH_D="$(report-cli -l -f | grep Directory | awk '{ print $2 }' | tail -n1)"
        rlLog "PATH_D = $PATH_D"
    rlPhaseEnd

    rlPhaseStartTest
        while pidof sos > /dev/null; do
                rlLogInfo "Zzz for 5 seconds..."
                sleep 5
        done
        rlRun "abrt-action-mailx -v -d $PATH_D -c mailx.conf" 0 "Report via mailx"
	sleep 5
        mailx -H -u root | tail -n1 > mail.out
        rlAssertGrep "abrt@localhost" mail.out
        rlLog "$(cat mail.out)"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlRun "report-cli -d $PATH_D" 0 "Remove crash directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
