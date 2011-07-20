#!/bin/bash

pushd $(dirname $0)

. abrt-testing-defs.sh

if [ $1 ]; then
	TESTNAME="$(grep 'TEST=\".*\"' $1 | awk -F '=' '{ print $2 }' | sed 's/"//g')"

	OUTPUTFILE="$ABRT_TESTOUT_ROOT/TESTOUT-${TESTNAME}.log"
	mkdir -p $(dirname $OUTPUTFILE)

	if [ "$(cat /proc/sys/kernel/core_pattern)" == "core" ]; then
		if [ -x /usr/sbin/abrt-install-ccpp-hook ]; then
			/usr/sbin/abrt-install-ccpp-hook install
		fi
	fi
	if ! pidof abrtd 2>&1 > /dev/null; then
		if [ -x /usr/sbin/abrtd ]; then
			if [ -x /bin/systemctl ]; then
				/bin/systemctl restart dbus.service
			else
				/usr/sbin/service dbus restart
			fi
			/usr/sbin/abrtd -s
		fi
	fi
	if ! pidof abrt-dump-oops 2>&1 > /dev/null; then
		if [ -x /usr/bin/abrt-dump-oops ]; then
			/usr/bin/abrt-dump-oops -d /var/spool/abrt -rwx /var/log/messages &
		fi
	fi
	sleep 5

	echo "core_pattern: $(cat /proc/sys/kernel/core_pattern)"
	echo "abrtd PID: $(pidof abrtd)"
	echo "abrt-dump-oops PID: $(pidof abrt-dump-oops)"

	pushd $(dirname $1)
	./$(basename $1) 2>&1 | tee $OUTPUTFILE
	popd

	abrt-install-ccpp-hook uninstall
	killall abrtd
	killall abrt-dump-oops

	popd

	exit 0
else
	popd
	echo_err "Provide test name"
fi

