#!/usr/bin/env bash
set -o errexit
set -o xtrace

: ${CEPH_NODE:?"Failure. Empty CEPH_NODE variable."}
: ${OPERATION:?"Failure. Empty OPERATION variable."}

: ${SSH_USER:="root"}
: ${SSH_PASSWORD:="r00tme"}

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_CMD="sshpass -p ${SSH_PASSWORD} ssh ${SSH_OPTIONS}"
SCP_CMD="sshpass -p ${SSH_PASSWORD} scp ${SSH_OPTIONS}"

main(){
    if [[ ${OPERATION} == "prepare" ]]; then
        prepare_ceph "${CEPH_NODE}"
    elif [[ ${OPERATION} == "create_pool" ]]; then
        : ${POOL_NAME:?"Failure. Empty POOL_NAME variable."}
        : ${POOL_PG_NUM:?"Failure. Empty POOL_PG_NUM variable."}
        create_pool "${CEPH_NODE}" "${POOL_NAME}" "${POOL_PG_NUM}"
    elif [[ ${OPERATION} == "delete_pool" ]]; then
        : ${POOL_NAME:?"Failure. Empty POOL_NAME variable."}
        delete_pool "${CEPH_NODE}" "${POOL_NAME}"
    fi
}

create_pool(){
    local host="${1}"; shift || true
    local pool_name="${1}"; shift || true
    local pool_pg_num="${1}"; shift || true

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd pool create ${pool_name} ${pool_pg_num}
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${host} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

delete_pool(){
    local host="${1}"; shift || true
    local pool_name="${1}"; shift || true

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd pool delete ${pool_name} ${pool_name} --yes-i-really-really-mean-it
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${host} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

prepare_ceph(){
    local host="${1}"; shift || true

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd set noscrub
ceph osd set nodeep-scrub
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${host} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

main ${@}
