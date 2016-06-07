#!/usr/bin/env bash

set -o errexit
set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="/tmp/$(uuidgen)"
RESULTS_DIR="/tmp/data-results"

: ${CEPH_MON_IP:?"Failure. Empty CEPH_MON_IP variable."}
: ${SECRET_KEY:?"Failure. Empty SECRET_KEY variable."}

: ${THREAD_MIN_NUM:="1"}
: ${THREAD_MAX_NUM:="20"}
: ${THREAD_INCR_SIZE:="20"}
: ${OBJECT_MIN_SIZE_IN_MB:="4"}
: ${OBJECT_MAX_SIZE_IN_MB:="94"}
: ${OBJECT_INCR_SIZE:="100"}
: ${TOTAL_TRANSMITTED_MB:="2048"}

CONTAINER_NAME_PREFIX="$(uuidgen)_"
CONTAINER_NAME_NUMBER="1"
ACCESS_KEY="admin"
SNAPSHOT_INTERVAL="5"
PG_NUM="8192"

COSBENCH_HOME="/root/cos"
COSBENCH_ARCHIVE="${COSBENCH_HOME}/archive"
COSBENCH_CLI="${COSBENCH_HOME}/cli.sh"

run_write_test() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    local test_name="write-ceph-test"

    export mon_ip="${CEPH_MON_IP}"
    export access_key="${ACCESS_KEY}"
    export secret_key="${SECRET_KEY}"
    export threads="${thread_num}"
    export interval="${SNAPSHOT_INTERVAL}"
    export obj_size_in_mb="${object_size}"
    export total_ops="$(( TOTAL_TRANSMITTED_MB/object_size ))"
    export pool_prefix="${CONTAINER_NAME_PREFIX}"
    export pool_number="${CONTAINER_NAME_NUMBER}"

    envsubst < "${__dir}/write-test-template.xml" > "${TMP_DIR}/write-test.xml"

    unset mon_ip access_key secret_key threads interval total_ops pool_prefix obj_size_in_mb pool_number

    local run_id=$( "${COSBENCH_CLI}" submit "${TMP_DIR}/write-test.xml" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info | grep '^'"${run_id}"'[[:space:]]' )"
        [[ -z ${is_run} ]] && break
        sleep 10
    done

    rm "${TMP_DIR}/write-test.xml"

    cp -r "${COSBENCH_ARCHIVE}/${run_id}-${test_name}" "${RESULTS_DIR}/"
}

run_rewrite_test() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    local test_name="rewrite-ceph-test"

    export mon_ip="${CEPH_MON_IP}"
    export access_key="${ACCESS_KEY}"
    export secret_key="${SECRET_KEY}"
    export threads="${thread_num}"
    export interval="${SNAPSHOT_INTERVAL}"
    export obj_size_in_mb="${object_size}"
    export total_ops="$(( TOTAL_TRANSMITTED_MB/object_size ))"
    export pool_prefix="${CONTAINER_NAME_PREFIX}"
    export pool_number="${CONTAINER_NAME_NUMBER}"

    envsubst < "${__dir}/rewrite-test-template.xml" > "${TMP_DIR}/rewrite-test.xml"

    unset mon_ip access_key secret_key threads interval total_ops pool_prefix obj_size_in_mb pool_number

    local run_id=$( "${COSBENCH_CLI}" submit "${TMP_DIR}/rewrite-test.xml" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info | grep '^'"${run_id}"'[[:space:]]' )"
        [[ -z ${is_run} ]] && break
        sleep 10
    done

    rm "${TMP_DIR}/rewrite-test.xml"

    cp -r "${COSBENCH_ARCHIVE}/${run_id}-${test_name}" "${RESULTS_DIR}/"
}

run_read_test() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    local test_name="read-ceph-test"

    export mon_ip="${CEPH_MON_IP}"
    export access_key="${ACCESS_KEY}"
    export secret_key="${SECRET_KEY}"
    export threads="${thread_num}"
    export interval="${SNAPSHOT_INTERVAL}"
    export obj_size_in_mb="${object_size}"
    export total_ops="$(( TOTAL_TRANSMITTED_MB/object_size ))"
    export pool_prefix="${CONTAINER_NAME_PREFIX}"
    export pool_number="${CONTAINER_NAME_NUMBER}"

    envsubst < "${__dir}/read-test-template.xml" > "${TMP_DIR}/read-test.xml"

    unset mon_ip access_key secret_key threads interval total_ops pool_prefix obj_size_in_mb pool_number

    local run_id=$( "${COSBENCH_CLI}" submit "${TMP_DIR}/read-test.xml" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info | grep '^'"${run_id}"'[[:space:]]' )"
        [[ -z ${is_run} ]] && break
        sleep 10
    done

    rm "${TMP_DIR}/read-test.xml"

    cp -r "${COSBENCH_ARCHIVE}/${run_id}-${test_name}" "${RESULTS_DIR}/"
}

run_delete_test() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    local test_name="delete-ceph-test"

    export mon_ip="${CEPH_MON_IP}"
    export access_key="${ACCESS_KEY}"
    export secret_key="${SECRET_KEY}"
    export threads="${thread_num}"
    export interval="${SNAPSHOT_INTERVAL}"
    export obj_size_in_mb="${object_size}"
    export total_ops="$(( TOTAL_TRANSMITTED_MB/object_size ))"
    export pool_prefix="${CONTAINER_NAME_PREFIX}"
    export pool_number="${CONTAINER_NAME_NUMBER}"

    envsubst < "${__dir}/delete-test-template.xml" > "${TMP_DIR}/delete-test.xml"

    unset mon_ip access_key secret_key threads interval total_ops pool_prefix obj_size_in_mb pool_number

    local run_id=$( "${COSBENCH_CLI}" submit "${TMP_DIR}/delete-test.xml" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info | grep '^'"${run_id}"'[[:space:]]' )"
        [[ -z ${is_run} ]] && break
        sleep 10
    done

    rm "${TMP_DIR}/delete-test.xml"

    cp -r "${COSBENCH_ARCHIVE}/${run_id}-${test_name}" "${RESULTS_DIR}/"
}

run_read_write_test() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    local test_name="read-write-ceph-test"

    export mon_ip="${CEPH_MON_IP}"
    export access_key="${ACCESS_KEY}"
    export secret_key="${SECRET_KEY}"
    export threads="${thread_num}"
    export interval="${SNAPSHOT_INTERVAL}"
    export obj_size_in_mb="${object_size}"
    export total_ops="$(( TOTAL_TRANSMITTED_MB/object_size ))"
    export min_ops_num_for_read="1"
    export max_ops_num_for_read="${total_ops}"
    export min_ops_num_for_write="$(( total_ops + 1 ))"
    export max_ops_num_for_write="$(( total_ops*2 ))"
    export pool_prefix="${CONTAINER_NAME_PREFIX}"
    export pool_number="${CONTAINER_NAME_NUMBER}"

    envsubst < "${__dir}/read-write-test-template.xml" > "${TMP_DIR}/read-write-test.xml"

    unset mon_ip access_key secret_key threads interval total_ops pool_prefix obj_size_in_mb pool_number

    local run_id=$( "${COSBENCH_CLI}" submit "${TMP_DIR}/read-write-test.xml" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info | grep '^'"${run_id}"'[[:space:]]' )"
        [[ -z ${is_run} ]] && break
        sleep 10
    done

    rm "${TMP_DIR}/read-write-test.xml"

    cp -r "${COSBENCH_ARCHIVE}/${run_id}-${test_name}" "${RESULTS_DIR}/"
}

run_all_tests() {
    local thread_num="${1}"; shift || true
    local object_size="${1}"; shift || true

    run_write_test "${thread_num}" "${object_size}"
    run_rewrite_test "${thread_num}" "${object_size}"
    run_read_test "${thread_num}" "${object_size}"
    run_delete_test "${thread_num}" "${object_size}"
    run_read_write_test "${thread_num}" "${object_size}"
}

config_ceph_client() {
    local mon_ip="${1}"; shift || true
    local secret_key="${1}"; shift || true

    cat > /etc/ceph/ceph.client.admin.keyring <<__EOF__
[client.admin]
        key = ${secret_key}
        caps mds = "allow *"
        caps mon = "allow *"
        caps osd = "allow *"
__EOF__

    cat > /etc/ceph/ceph.conf <<__EOF__
[global]
mon_host = ${mon_ip}
__EOF__
}

main() {
    local thread_num="${THREAD_MIN_NUM}"

    config_ceph_client "${CEPH_MON_IP}" "${SECRET_KEY}"

    ceph osd pool create "${CONTAINER_NAME_PREFIX}${CONTAINER_NAME_NUMBER}" "${PG_NUM}"

    mkdir -p "${TMP_DIR}"
    mkdir -p "${RESULTS_DIR}"
    find "${RESULTS_DIR}" -regex "${RESULTS_DIR}/"'w.*' -delete  
    
    local thread_num=$(( THREAD_MIN_NUM - THREAD_INCR_SIZE ))

    while true; do
        : $(( thread_num+=THREAD_INCR_SIZE ))
        (( thread_num > THREAD_MAX_NUM )) && thread_num=${THREAD_MAX_NUM}
        local object_size=$(( OBJECT_MIN_SIZE_IN_MB - OBJECT_INCR_SIZE ))
        while true; do
            : $(( object_size+=OBJECT_INCR_SIZE ))
            (( object_size > OBJECT_MAX_SIZE_IN_MB )) && object_size=${OBJECT_MAX_SIZE_IN_MB}

            run_all_tests "${thread_num}" "${object_size}"

            (( object_size >= OBJECT_MAX_SIZE_IN_MB )) && break
        done
        (( thread_num >= THREAD_MAX_NUM )) && break
    done

    rm -r "${TMP_DIR}"

    ceph osd pool delete "${CONTAINER_NAME_PREFIX}${CONTAINER_NAME_NUMBER}" "${CONTAINER_NAME_PREFIX}${CONTAINER_NAME_NUMBER}" --yes-i-really-really-mean-it

    rm -f /tmp/test-results.tgz
    tar zcvf "${__dir}/test-results.tgz" "${RESULTS_DIR}/"
    find "${RESULTS_DIR}" -regex "${RESULTS_DIR}/"'w.*' -delete
}


main
