#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of init-scripts-LSB
#   Description: init scripts must meet LSB specifications
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

TEST="init-scripts-LSB"
PACKAGE="abrt"
SERVICE="${PACKAGE}d"

rlDie "This should be ported to systemd."

rlJournalStart
    rlPhaseStartSetup "Prepare"
        #rlServiceStop $SERVICE
	killall abrtd
    rlPhaseEnd
    rlPhaseStartTest "Mandatory actions"
        for ACTION in "start" "stop" "restart" "force-reload" "status" ; do
            rlRun "grep -i \"usage.*$ACTION\" /etc/init.d/$SERVICE"
        done
    rlPhaseEnd
    rlPhaseStartTest "Start"
        rlRun "service $SERVICE start" 0
        rlRun "service $SERVICE status" 0
        rlRun "service $SERVICE start" 0
        rlRun "service $SERVICE status" 0
        rlRun "service $SERVICE restart" 0
        rlRun "service $SERVICE status" 0
    rlPhaseEnd
    rlPhaseStartTest "Stop"
        rlRun "service $SERVICE stop" 0
        rlRun "service $SERVICE status" 3
        rlRun "service $SERVICE stop" 0
        rlRun "service $SERVICE status" 3
    rlPhaseEnd
    rlPhaseStartTest "PID File"
        service ${SERVICE} start 0
        rlRun "kill -n 9 $(cat /var/run/${SERVICE}.pid)" 0
	sleep 2
        rlRun "service ${SERVICE} status" 1
    rlPhaseEnd
    rlPhaseStartTest "Lock file"
        rlRun "rm -f /var/run/${SERVICE}.pid" 0
        rlRun "service ${SERVICE} status" 2
        rlRun "service ${SERVICE} stop" 0
    rlPhaseEnd
    rlPhaseStartTest "Condrestart"
        service $SERVICE restart
        service $SERVICE | grep "condrestart" && COND="1" || COND="0"
        if [ "$COND" -eq "1" ]; then
            rlRun "service $SERVICE condrestart" 0
            rlRun "service $SERVICE status" 0
        else
            [ -f /var/lock/subsys/${SERVICE} ] && rm -rf /var/lock/subsys/${SERVICE}
        fi
        service $SERVICE stop
    rlPhaseEnd
    rlPhaseStartTest "Invalid arguments"
        rlRun "service $SERVICE" 2
    rlPhaseEnd
    rlPhaseStartCleanup "Restore"
        #rlServiceRestore $SERVICE
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
