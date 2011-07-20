#!/bin/bash

service sendmail start

pushd $(dirname $0)

. abrt-testing-defs.sh

yum install -y beakerlib dejagnu btparser-devel time

rm -rf $ABRT_TESTOUT_ROOT
mkdir -p $ABRT_TESTOUT_ROOT

for test in abrt-nightly-build.sh */runtest.sh; do
	echo "---> $test"
	./runner.sh $test

	TESTNAME="$(grep 'TEST=\".*\"' $test | awk -F '=' '{ print $2 }' | sed 's/"//g')"
	test_result="FAIL"
	if [ -e $ABRT_TESTOUT_ROOT/TESTOUT-${TESTNAME}.log ]; then
		if ! grep -q FAIL $ABRT_TESTOUT_ROOT/TESTOUT-${TESTNAME}.log; then
			test_result="PASS"
		fi
	fi
	echo -e "\n---> ${test_result}\n"
	#read
	#break
done

date="$(date +%F)"
if grep -q FAIL $ABRT_TESTOUT_ROOT/abrt-test-output.summary; then
	RESULT="FAIL"
else
	RESULT="PASS"
fi

tar cfJ $ABRT_TESTOUT_ROOT.tar.xz $ABRT_TESTOUT_ROOT
echo -n "Sending report to <$MAILTO>: "
if cat $ABRT_TESTOUT_ROOT/abrt-test-output.summary | mail -v -s "[$date] [$RESULT] ABRT testsuite report" -r abrt-testsuite-bot@example.com -a $ABRT_TESTOUT_ROOT.tar.xz $MAILTO; then
	echo "OK"
	#rm -r $ABRT_TESTOUT_ROOT $ABRT_TESTOUT_ROOT.tar.xz
else
	echo "FAILED"
fi

popd

echo "Shutdown now..."
shutdown -h now

