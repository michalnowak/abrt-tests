#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of abrt-should-return-rating-0-on-fail
#   Description: tests whether abrt returns zero on backtrace generation fail
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

TEST="abrt-should-return-rating-0-on-fail"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartTest
        sleep 3m &
        sleep 1
        kill -11 %1
        sleep 10
        if [ $(report-cli -l -f | wc -l) -ne 0 ]; then
                PATH_D="$(report-cli -l -f | grep Directory | tail -n1 | awk '{ print $2}')"
                rlLog "PATH_D=$PATH_D"
        else
                rlDie "No crash recorded"
        fi
        rlRun "abrt-action-generate-backtrace -d ${PATH_D}" 0 "Backtrace generated"
        rlRun "abrt-action-analyze-backtrace -d ${PATH_D}" 0 "Rating generated"
        if [ ! -e ${PATH_D}/backtrace_rating ]; then rlLog "$(tail /var/log/messages)"; rlDie "File 'backtrace_rating' in $PATH_D does not exist"; fi
        RATING_N="$(cat ${PATH_D}/backtrace_rating)"
        if [ -z "${RATING_N}" ]; then
                rlLogError "RATING EMPTY -> FAIL"
        else
                rlLog "RATING=$RATING_N"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "report-cli -d $PATH_D" 0 "Delete the crash"
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd

