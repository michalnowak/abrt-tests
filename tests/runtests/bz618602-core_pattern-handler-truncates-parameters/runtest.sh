#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of bz618602-core_pattern-handler-truncates-parameters
#   Description: Tests max size of core_pattern
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

TEST="bz618602-core_pattern-handler-truncates-parameters"
PACKAGE="abrt"

rlJournalStart
    rlPhaseStartSetup
	rlRun "abrt-install-ccpp-hook uninstall" 0 "Uninstall ABRT CCPP hook"
	core_pattern_bkp="$(cat /proc/sys/kernel/core_pattern)"
	rlLog "Former core_pattern was: $core_pattern_bkp"
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "echo really_long_long_long_long_long_long_long_long_corename_s%s_c%c_p%p_u%u_g%g_t%t_h%h_e%e > /proc/sys/kernel/core_pattern" 0 "Set core_pattern to long garbage"
	abrtd -s
	chars_in_core_pattern="$[$(cat /proc/sys/kernel/core_pattern | wc -c) - 1]"
	rlAssertGreaterOrEqual "core_pattern length should be >= 127" $chars_in_core_pattern 127
    rlPhaseEnd
rlJournalPrintText
rlJournalPrintText >> $ABRT_TESTOUT_ROOT/abrt-test-output.summary
rlJournalEnd
