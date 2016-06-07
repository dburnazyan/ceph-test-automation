#!/usr/bin/env bash

: ${WORKLOAD_TEMPLATE_FILES_DIR:?"FAILURE. Variable WORKLOAD_TEMPLATE_FILES_DIR not set"}
: ${COSBENCH_CLI:?"FAILURE. Variable COSBENCH_CLI not set."}

: ${MON_NODES:?"Failure. Empty MON_NODES variable."}
: ${OSD_NODES:?"Failure. Empty OSD_NODES variable."}
: ${ENV_NAME:?"Failure. Empty ENV_NAME variable."}

: ${SLAVE_NODES:?"Failure. Empty SLAVE_NODES variable."}
: ${DRIVERS_PER_SLAVE:?"Failure. Empty DRIVERS_PER_SLAVE variable."}

: ${MGMT_NET_RANGE:?"ERROR"}
: ${MGMT_NET_MASK:?"ERROR"}
#[[ ${MGMT_NET_IF_GTW+unset} ]] || echo "ERROR" && exit 1
: ${MGMT_NET_DEV:?"ERROR"}
: ${MGMT_NET_IS_VLAN:?"ERROR"}

: ${EXT_NET_RANGE:?"ERROR"}
: ${EXT_NET_MASK:?"ERROR"}
#[[ ${EXT_NET_IF_GTW+unset} ]] || echo "ERROR" && exit 1
: ${EXT_NET_DEV:?"ERROR"}
: ${EXT_NET_IS_VLAN:?"ERROR"}

: ${PUB_NET_RANGE:?"ERROR"}
: ${PUB_NET_MASK:?"ERROR"}
#[[ ${PUB_NET_IF_GTW+unset} ]] || echo "Error" && exit 1
: ${PUB_NET_DEV:?"ERROR"}
: ${PUB_NET_IS_VLAN:?"ERROR"}

: ${SEPARATE_REPL_NET:?"ERROR"}
#[[ ${REPL_NET_RANGE+unset} ]] || echo "Error" && exit 1
#[[ ${REPL_NET_MASK+unset} ]] || echo "Error" && exit 1
#[[ ${REPL_NET_IF_GTW+unset} ]] || echo "Error" && exit 1
#[[ ${REPL_NET_DEV+unset} ]] || echo "Error" && exit 1
#[[ ${REPL_NET_IS_VLAN+unset} ]] || echo "Error" && exit 1
: ${COSBENCH_URL:?"ERROR"}
: ${ACCESS_KEY:?"ERROR"}
: ${COSBENCH_SNAPSHOT_INTERVAL:?"ERROR"}
: ${COSBENCH_CONTROLLER_ROOT_PATH:?"ERROR"}
: ${ATOP_LOG:?"ERROR"}

: ${SSH_OPTIONS:?"ERROR"}
: ${SSH_USER:?"ERROR"}
: ${SSH_PASSWORD:?"ERROR"}

: ${SSH_CMD:?"ERROR"}
: ${SCP_CMD:?"ERROR"}

deploy_cluster(){
    MON_NODES="${MON_NODES}" \
    OSD_NODES="${OSD_NODES}" \
    ENV_NAME="${ENV_NAME}" \
    MGMT_NET_RANGE="${MGMT_NET_RANGE}" \
    MGMT_NET_MASK="${MGMT_NET_MASK}" \
    MGMT_NET_IF_GTW="${MGMT_NET_IF_GTW}" \
    MGMT_NET_DEV="${MGMT_NET_DEV}" \
    MGMT_NET_IS_VLAN="${MGMT_NET_IS_VLAN}" \
    EXT_NET_RANGE="${EXT_NET_RANGE}" \
    EXT_NET_MASK="${EXT_NET_MASK}" \
    EXT_NET_IF_GTW="${EXT_NET_IF_GTW}" \
    EXT_NET_DEV="${EXT_NET_DEV}" \
    EXT_NET_IS_VLAN="${EXT_NET_IS_VLAN}" \
    PUB_NET_RANGE="${PUB_NET_RANGE}" \
    PUB_NET_MASK="${PUB_NET_MASK}" \
    PUB_NET_IF_GTW="${PUB_NET_IF_GTW}" \
    PUB_NET_DEV="${PUB_NET_DEV}" \
    PUB_NET_IS_VLAN="${PUB_NET_IS_VLAN}" \
    SEPARATE_REPL_NET="${SEPARATE_REPL_NET}" \
    REPL_NET_RANGE="${REPL_NET_RANGE}" \
    REPL_NET_MASK="${REPL_NET_MASK}" \
    REPL_NET_IF_GTW="${REPL_NET_IF_GTW}" \
    REPL_NET_DEV="${REPL_NET_DEV}" \
    REPL_NET_IS_VLAN="${REPL_NET_IS_VLAN}" \
    bash "${__dir}/../deploy.sh"
}

collect_info(){
    local host="${1}"; shift || true

    ${SCP_CMD} "./collect_info.py" ${SSH_USER}@${host}:"/tmp/collect_info.py"
    ${SSH_CMD} ${SSH_USER}@${host} "/tmp/collect_info.py"


    ${SCP_CMD} "./collect_info.py" ${SSH_USER}@${host}:"/tmp/collect_info.py"

}

setup_zabbix_agent(){
    local host="${1}"; shift || true
    local host_ip="${1}"; shift || true

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
work_dir=\$(mktemp -d)
cd \${work_dir}
wget http://repo.zabbix.com/zabbix/3.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.0-1+trusty_all.deb
dpkg --install zabbix-release_3.0-1+trusty_all.deb
apt-get update
apt-get -y install zabbix-agent
sed --in-place s/^Server=.*/Server=${ZABBIX_SERVER}/g /etc/zabbix/zabbix_agentd.conf
sed --in-place s/^Hostname=.*/Hostname=${host}/g /etc/zabbix/zabbix_agentd.conf
apt-get -y install git
git clone https://github.com/grundic/zabbix-disk-performance.git
cd zabbix-disk-performance
cp userparameter_diskstats.conf /etc/zabbix/zabbix_agentd.d/userparameter_diskstats.conf
mkdir --parents /var/lib/zabbix/scripts
cp lld-disks.py /var/lib/zabbix/scripts/lld-disks.py
chown --recursive zabbix:zabbix /var/lib/zabbix
chmod 775 /var/lib/zabbix/scripts/lld-disks.py
service zabbix-agent restart
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${host} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete

    ./setupZabbix.py --zabbix=http://${ZABBIX_SERVER}/zabbix --user=Admin --password=zabbix --host=${host}
}

configure_ceph(){
    local ceph_node="${MON_NODES/ *}"

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd set noscrub
ceph osd set nodeep-scrub
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${ceph_node}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${ceph_node} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

install_slaves_and_setup_controller(){
    local ssh_base_command="cd ${COSBENCH_CONTROLLER_ROOT_PATH};"

    ${SSH_CMD} ${SSH_USER}@${COSBENCH_CONTROLLER} "${ssh_base_command} ./stop-controller.sh"

    for slave in ${SLAVE_NODES}; do
        install_and_start_cosb_drivers "${slave/\/*}"
    done

    configure_controller
    ${SSH_CMD} ${SSH_USER}@${COSBENCH_CONTROLLER} "${ssh_base_command} ./start-controller.sh"
}

configure_controller(){
    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    node_list=(${SLAVE_NODES})
    node_list=(${node_list[@]#*\/})
    port_start_num=18088
    node_count="${#node_list[@]}"
    cat > ${tmp_script} <<__EOF__
[controller]
drivers = $(( DRIVERS_PER_SLAVE*node_count ))
log_level = DEBUG
log_file = log/system.log
archive_dir = archive
__EOF__

    for i in $(seq 1 ${DRIVERS_PER_SLAVE}); do
        for j in $(seq 1 ${node_count}); do
            cat >> ${tmp_script} <<__EOF__

[driver$(( (i-1)*node_count+j ))]
log_file = log/driver.log
log_level = DEBUG
name = mon${j}-${i}
url = http://${node_list[j-1]}:$((port_start_num +100*(i-1)))/driver
__EOF__
        done
    done

    ${SCP_CMD} "${tmp_script}" ${SSH_USER}@${COSBENCH_CONTROLLER}:"${COSBENCH_CONTROLLER_ROOT_PATH}/conf/controller.conf"

    find ${tmp_script} -path ${tmp_script} -delete
}

install_and_start_cosb_drivers(){
    local host="$1"; shift || true

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
apt-get install -y unzip librados-dev
wget --output-document=cosbench.zip ${COSBENCH_URL}
unzip -d cosbench cosbench.zip
cd cosbench/*/
chmod u+x start-driver.sh
./start-driver.sh ${DRIVERS_PER_SLAVE}
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${host} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

get_ceph_secret_key(){
    local host="${MON_NODES/ *}"

    local ssh_command="ceph auth get-key client.${ACCESS_KEY}"

    local secret_key="$(${SSH_CMD} ${SSH_USER}@${host} ${ssh_command})"

    echo "${secret_key}"
}
gather_test_results(){
    local run_id="${1}"; shift || true
    local local_dir="${1}"; shift || true

    ${SCP_CMD} ${SSH_USER}@${COSBENCH_CONTROLLER}:"${COSBENCH_CONTROLLER_ROOT_PATH}/archive/${run_id}-*/*" "${local_dir}/"
}

write_objects(){
    local threads="${1}"; shift || true
    local object_size_in_mb="${1}"; shift || true
    local total_transmitted_mb="${1}"; shift || true
    local pool_base_name="${1}"; shift || true
    local pool_name_suffix="${1}"; shift || true

    local test_name="write-test"

    local workload_file="$(mktemp --suffix=.xml)"

    local secret_key="$(get_ceph_secret_key)"

    #MON_IP="10.40.0.30" \
    MON_IP="10.40.0.30" \
    ACCESS_KEY="${ACCESS_KEY}" \
    SECRET_KEY="${secret_key}" \
    THREADS="${threads}" \
    INTERVAL="${COSBENCH_SNAPSHOT_INTERVAL}" \
    OBJ_SIZE_IN_BYTES="$(( object_size_in_mb*1024*1024 ))" \
    TOTAL_OPS="$(( total_transmitted_mb/object_size_in_mb ))" \
    POOL_BASE_NAME="${pool_base_name}" \
    POOL_NAME_SUFFIX="${pool_name_suffix}" \
    envsubst < "${WORKLOAD_TEMPLATE_FILES_DIR}/write.xml.tmpl" > "${workload_file}"
    local run_out=$( "${COSBENCH_CLI}" submit "${workload_file}" "${COSBENCH_CONTROLLER}:19088" )
    if [[ ${run_out} =~ ^Accepted ]]; then
        local run_id=$(echo ${run_out#*:})
    else
        echo "Can't run test: ${run_out}"
        exit 1
    fi
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info "${COSBENCH_CONTROLLER}:19088" | grep '^'"${run_id}"'[[:space:]]' )"
        [[ ${is_run} ]] || break
        sleep 10
    done

    find ${workload_file} -path "${workload_file}" -delete

    RUN_ID="${run_id}"
}

read_objects(){
    local threads="${1}"; shift || true
    local object_size_in_mb="${1}"; shift || true
    local total_transmitted_mb="${1}"; shift || true
    local pool_base_name="${1}"; shift || true
    local pool_name_suffix="${1}"; shift || true

    local test_name="read-test"

    local workload_file="$(mktemp --suffix=.xml)"

    local secret_key="$(get_ceph_secret_key)"

    MON_IP="${MON_NODES/ *}" \
    ACCESS_KEY="${ACCESS_KEY}" \
    SECRET_KEY="${secret_key}" \
    THREADS="${threads}" \
    INTERVAL="${COSBENCH_SNAPSHOT_INTERVAL}" \
    OBJ_SIZE_IN_BYTES="$(( object_size_in_mb*1024*1024 ))" \
    TOTAL_OPS="$(( total_transmitted_mb/object_size_in_mb ))" \
    POOL_BASE_NAME="${pool_base_name}" \
    POOL_NAME_SUFFIX="${pool_name_suffix}" \
    envsubst < "${WORKLOAD_TEMPLATE_FILES_DIR}/read.xml.tmpl" > "${workload_file}"

    local run_id=$( "${COSBENCH_CLI}" submit "${workload_file}" "${COSBENCH_CONTROLLER}:19088" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info "${COSBENCH_CONTROLLER}:19088" | grep '^'"${run_id}"'[[:space:]]' )"
        [[ ${is_run} ]] || break
        sleep 10
    done

    find ${workload_file} -path "${workload_file}" -delete

    RUN_ID="${run_id}"
}

read_write_objects(){
    local threads="${1}"; shift || true
    local object_size_in_mb="${1}"; shift || true
    local total_transmitted_mb="${1}"; shift || true
    local pool_base_name="${1}"; shift || true
    local pool_name_suffix="${1}"; shift || true

    local test_name="read-write-test"

    local workload_file="$(mktemp --suffix=.xml)"

    local secret_key="$(get_ceph_secret_key)"

    MON_IP="${MON_NODES/ *}" \
    ACCESS_KEY="${ACCESS_KEY}" \
    SECRET_KEY="${secret_key}" \
    THREADS="${threads}" \
    INTERVAL="${COSBENCH_SNAPSHOT_INTERVAL}" \
    OBJ_SIZE_IN_BYTES="$(( object_size_in_mb*1024*1024 ))" \
    TOTAL_OPS="$(( total_transmitted_mb/object_size_in_mb ))" \
    POOL_BASE_NAME="${pool_base_name}" \
    POOL_NAME_SUFFIX="${pool_name_suffix}" \
    envsubst < "${WORKLOAD_TEMPLATE_FILES_DIR}/read-write.xml.tmpl" > "${workload_file}"

    local run_id=$( "${COSBENCH_CLI}" submit "${workload_file}" "${COSBENCH_CONTROLLER}:19088" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info "${COSBENCH_CONTROLLER}:19088" | grep '^'"${run_id}"'[[:space:]]' )"
        [[ ${is_run} ]] || break
        sleep 10
    done

    find ${workload_file} -path "${workload_file}" -delete

    RUN_ID="${run_id}"
}

delete_objects(){
    local threads="${1}"; shift || true
    local object_size_in_mb="${1}"; shift || true
    local total_transmitted_mb="${1}"; shift || true
    local pool_base_name="${1}"; shift || true
    local pool_name_suffix="${1}"; shift || true

    local test_name="delete-test"

    local workload_file="$(mktemp --suffix=.xml)"

    local secret_key="$(get_ceph_secret_key)"

    MON_IP="${MON_NODES/ *}" \
    ACCESS_KEY="${ACCESS_KEY}" \
    SECRET_KEY="${secret_key}" \
    THREADS="${threads}" \
    INTERVAL="${COSBENCH_SNAPSHOT_INTERVAL}" \
    OBJ_SIZE_IN_BYTES="$(( object_size_in_mb*1024*1024 ))" \
    TOTAL_OPS="$(( total_transmitted_mb/object_size_in_mb ))" \
    POOL_BASE_NAME="${pool_base_name}" \
    POOL_NAME_SUFFIX="${pool_name_suffix}" \
    envsubst < "${WORKLOAD_TEMPLATE_FILES_DIR}/delete.xml.tmpl" > "${workload_file}"

    local run_id=$( "${COSBENCH_CLI}" submit "${workload_file}" "${COSBENCH_CONTROLLER}:19088" | cut -d':' -f2 | awk '{$1=$1};1' )
    while true; do
        local is_run="$( "${COSBENCH_CLI}" info "${COSBENCH_CONTROLLER}:19088" | grep '^'"${run_id}"'[[:space:]]' )"
        [[ ${is_run} ]] || break
        sleep 10
    done

    find ${workload_file} -path "${workload_file}" -delete

    RUN_ID="${run_id}"
}


install_atop(){
    local host="${1}"; shift || true

    local ssh_command="apt-get install atop"

    ${SSH_CMD} ${SSH_USER}@${host} ${ssh_command}
}

start_atop(){
    local host="${1}"; shift || true

    local ssh_command="start-stop-daemon --start \
                                          --background \
                                          --quiet \
                                          --pidfile /var/run/atop.pid \
                                          --make-pidfile \
                                          --startas /usr/share/atop/atop.wrapper \
                                          -- \
                                          /usr/bin/atop /var/log/atop/daily.log \
                                          -a -w ${ATOP_LOG} 5"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

stop_atop(){
    local host="${1}"; shift || true

    local ssh_command="service atop stop || true"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

gather_atop_log(){
    local host="${1}"; shift || true
    local local_dir="${1}"; shift || true

    ${SCP_CMD} ${SSH_USER}@${host}:"${ATOP_LOG}" "${local_dir}/raw_atop_${host}"
}

delete_atop_log(){
    local host="${1}"; shift || true

    local ssh_command="rm -f ${ATOP_LOG}"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

parse_atop_log(){
    echo "TODO"
    #TODO
}

create_ceph_satus_service(){
    local host="$1"; shift || true

    tmp_script=$(mktemp)

    cat > ${tmp_script} <<__EOF__
manual

script
ceph -w >> /var/log/cosb-ceph-status.log
end script
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:"/etc/init/cosb-ceph-status.conf"

    find ${tmp_script} -path ${tmp_script} -delete
}

start_ceph_status_service(){
    local host="${1}"; shift || true

    local ssh_command="start cosb-ceph-status"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

stop_ceph_status_service(){
    local host="${1}"; shift || true

    local ssh_command="stop cosb-ceph-status || true"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

gather_ceph_status_log(){
    local host="${1}"; shift || true
    local local_dir="${1}"; shift || true

    ${SCP_CMD} ${SSH_USER}@${host}:"/var/log/cosb-ceph-status.log" "${local_dir}/ceph-status.log"
}

truncate_ceph_status_log(){
    local host="${1}"; shift || true

    local ssh_command="truncate -s0 /var/log/cosb-ceph-status.log"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

create_ceph_perf_service(){
    local host="${1}"; shift || true

    tmp_script=$(mktemp)

    cat > ${tmp_script} <<__EOF__
manual

script
log_file=/var/log/cosb-ceph-perf.log
while true; do
    echo "[\$(date)]" >> \${log_file}
    ceph osd perf >> \${log_file}
    sleep 5
done
end script
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${host}:"/etc/init/cosb-ceph-perf.conf"

    find ${tmp_script} -path ${tmp_script} -delete
}

start_ceph_perf_service(){
    local host="${1}"; shift || true

    local ssh_command="start cosb-ceph-perf"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

stop_ceph_perf_service(){
    local host="${1}"; shift || true

    local ssh_command="stop cosb-ceph-perf || true"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

gather_ceph_perf_log(){
    local host="${1}"; shift || true
    local local_dir="${1}"; shift || true

    ${SCP_CMD} ${SSH_USER}@${host}:"/var/log/cosb-ceph-perf.log" "${local_dir}/ceph-perf.log"
}

truncate_ceph_perf_log(){
    local host="${1}"; shift || true

    local ssh_command="truncate -s0 /var/log/cosb-ceph-perf.log"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

gather_ceph_logs(){
    local host="${1}"; shift || true
    local local_dir="${1}"; shift || true

    ${SCP_CMD} ${SSH_USER}@${host}:"/var/log/ceph/*.log" "${local_dir}/"
}

truncate_ceph_logs(){
    local host="${1}"; shift || true

    local ssh_command="find /var/log/ceph -type f -name \"*.log\" -exec truncate -s0 {} \\;"

    ${SSH_CMD} ${SSH_USER}@${host} "${ssh_command}"
}

create_pool(){
    local pool_name="${1}"; shift || true
    local pool_pg_num="${1}"; shift || true

    local ceph_node="${MON_NODES/ *}"

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd pool create ${pool_name} ${pool_pg_num}
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${ceph_node}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${ceph_node} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}

delete_pool(){
    local pool_name="${1}"; shift || true

    local ceph_node="${MON_NODES/ *}"

    tmp_script=$(mktemp)
    chmod u+x ${tmp_script}

    cat > ${tmp_script} <<__EOF__
ceph osd pool delete ${pool_name} ${pool_name} --yes-i-really-really-mean-it
__EOF__
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${ceph_node}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${ceph_node} ${tmp_script}

    find ${tmp_script} -path ${tmp_script} -delete
}
