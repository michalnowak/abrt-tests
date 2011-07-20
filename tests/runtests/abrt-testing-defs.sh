#!/bin/bash

export ABRT_TESTOUT_ROOT="/tmp/abrt-TESTOUT"
export MAILTO="mnowak@redhat.com"

function echo_err {
	echo "ERROR: $1"
	exit 1
}
