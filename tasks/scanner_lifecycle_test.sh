#!/bin/sh
# stagehand::scanner_lifecycle test harness (999.12-02-PLAN.md Task 2).
# Ported from puppet-console's adapters/stagehand/tasks/scanner_lifecycle_test.sh,
# converting the prior ripgrep-based assertions to the equivalent POSIX
# `grep -qF` form (fixed-string match -- the original patterns are literal
# text, no regex feature was actually needed) since this repo's CI
# task-tests job runs each test under plain `sh` with no ripgrep guarantee.
#
# Assertions (unchanged from the original):
#   - the ownership guard on uninstall (`owned_here ||`)
#   - the never-claim-a-pre-existing-install guard
#     (`has_scanner && ! owned_here`)
#   - the OpenSCAP platform-lock die message
#   - the Trivy checksum-mismatch die message
set -eu

task=$(dirname "$0")/scanner_lifecycle.sh
grep -qF 'owned_here ||' "$task"
grep -qF 'has_scanner && ! owned_here' "$task"
grep -qF 'OpenSCAP platform lock is missing' "$task"
grep -qF 'Trivy checksum mismatch' "$task"
printf 'scanner lifecycle ownership guards: ok\n'
