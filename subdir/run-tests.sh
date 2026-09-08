#!/bin/bash
# Wrapper proving the `script` input reaches the workflow: it does nothing but
# hand over to the real entry point.
echo "run-tests.sh wrapper invoked with: $*"
exec bash ./test-module.sh "$@"
