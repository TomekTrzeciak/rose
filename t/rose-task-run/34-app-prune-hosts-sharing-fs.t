#!/bin/bash
#-------------------------------------------------------------------------------
# (C) British Crown Copyright 2012-7 Met Office.
#
# This file is part of Rose, a framework for meteorological suites.
#
# Rose is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Rose is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Rose. If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------
# Test "rose_prune" built-in application:
# Prune items in job hosts sharing a common file system (but not with the suite
# host).
#-------------------------------------------------------------------------------
. $(dirname $0)/test_header

JOB_HOSTS="$(rose config --default= 't' 'job-hosts-sharing-fs')"
JOB_HOST_1="$(awk '{print $1}' <<<"${JOB_HOSTS}")"
JOB_HOST_2="$(awk '{print $2}' <<<"${JOB_HOSTS}")"
if [[ -z "${JOB_HOST_1}" || -z "${JOB_HOST_2}" ]]; then
    skip_all '"[t]job-hosts-sharing-fs" not defined with 2 host names'
fi

tests 4

export ROSE_CONF_PATH=
mkdir -p "${HOME}/cylc-run"
SUITE_RUN_DIR=$(mktemp -d --tmpdir="${HOME}/cylc-run" 'rose-test-battery.XXXXXX')
NAME="$(basename "${SUITE_RUN_DIR}")"
#-------------------------------------------------------------------------------
TEST_KEY="${TEST_KEY_BASE}"
run_pass "${TEST_KEY}" \
    rose suite-run -C "${TEST_SOURCE_DIR}/${TEST_KEY_BASE}" --name="${NAME}" \
    --no-gcontrol --host='localhost' --debug \
    -S "JOB_HOST_1=\"${JOB_HOST_1}\"" -S "JOB_HOST_2=\"${JOB_HOST_2}\"" \
    -- --debug

TEST_KEY="${TEST_KEY_BASE}-prune.log"
grep \
    "ssh .* \\(${JOB_HOST_1}\\|${JOB_HOST_2}\\) .* share/cycle/19700101T0000Z;" \
    "${SUITE_RUN_DIR}/prune.log" >'prune-ssh.log'
run_pass "${TEST_KEY}-prune-ssh-wc-l" test "$(wc -l <'prune-ssh.log')" -eq 2

if head -n 1 'prune-ssh.log' | grep ".* ${JOB_HOST_1} .*"; then
    run_pass "${TEST_KEY}-delete-1" \
        grep -q "delete: ${JOB_HOST_1}:share/cycle/19700101T0000Z" \
        "${SUITE_RUN_DIR}/prune.log"
    run_fail "${TEST_KEY}-delete-2" \
        grep -q "delete: ${JOB_HOST_2}:share/cycle/19700101T0000Z" \
        "${SUITE_RUN_DIR}/prune.log"
else
    run_pass "${TEST_KEY}-delete-2" \
        grep -q "delete: ${JOB_HOST_2}:share/cycle/19700101T0000Z" \
        "${SUITE_RUN_DIR}/prune.log"
    run_fail "${TEST_KEY}-delete-1" \
        grep -q "delete: ${JOB_HOST_1}:share/cycle/19700101T0000Z" \
        "${SUITE_RUN_DIR}/prune.log"
fi
#-------------------------------------------------------------------------------
rose suite-clean -q -y "${NAME}"
exit 0
