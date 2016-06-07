#!/usr/bin/env bash
set -o errexit
set -o xtrace

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


. "${__dir}/test-functions.sh"

full_featured_write_test(){
    local threads="${1}"; shift || true
    local object_size_in_mb="${1}"; shift || true
    local total_transmitted_mb="${1}"; shift || true
    local pool_base_name="${1}"; shift || true
    local pool_name_suffix="${1}"; shift || true
    local work_dir="${1}"; shift || true
    local comment="${1}"; shift || true

    mkdir -p "${work_dir}/cosbench-data"
    mkdir -p "${work_dir}/summary"
    mkdir -p "${work_dir}/charts"

    stop_ceph_perf_service "${MON_NODES/ *}"
    stop_ceph_status_service "${MON_NODES/ *}"
    truncate_ceph_perf_log "${MON_NODES/ *}"
    truncate_ceph_status_log "${MON_NODES/ *}"
    start_ceph_status_service "${MON_NODES/ *}"
    start_ceph_perf_service "${MON_NODES/ *}"
    for node in ${MON_NODES} ${OSD_NODES}; do
        truncate_ceph_logs "${node}"
    done

    date +%Y-%d-%m_%H:%M:%S\(%:z\) > "${work_dir}/summary/timestamp"
    echo "${threads}" > "${work_dir}/summary/threads"
    echo "${object_size_in_mb}" > "${work_dir}/summary/obj_size"
    echo "${comment}" > "${work_dir}/summary/comment"

    local start_time="$(date +%s)"
    : $(( start_time-=120 ))

    write_objects "${threads}" \
                  "${object_size_in_mb}" \
                  "${total_transmitted_mb}" \
                  "${pool_base_name}" \
                  "${pool_name_suffix}"

    local end_time="$(date +%s)"
    : $(( end_time+=120 ))
    local duration=$(( end_time - start_time ))

    gather_test_results "${RUN_ID}" "${work_dir}/cosbench-data"
    cat "${work_dir}/cosbench-data/w*-write-ceph-test.csv" | tail -n1 | cut -d',' -f17 > "${work_dir}/summary/status"

    stop_ceph_perf_service "${MON_NODES/ *}"
    stop_ceph_status_service "${MON_NODES/ *}"
    gather_ceph_perf_log "${MON_NODES/ *}" "${work_dir}"
    gather_ceph_status_log "${MON_NODES/ *}" "${work_dir}"
    for node in ${MON_NODES} ${OSD_NODES}; do
        mkdir -p "${work_dir}/ceph-logs/${node}"
        gather_ceph_logs "${node}" "${work_dir}/ceph-logs/${node}"
    done

    find "${work_dir}/cosbench-data" -name 's1-*' -and -not -name '*-worker.csv' -exec sed -e '2d' {} > "${work_dir}/cosbench-data/raw_data.csv" \;
    Rscript "./parse.R" "${work_dir}/cosbench-data/raw_data.csv" "${work_dir}/summary" || true

    Rscript "./generateGraph.R" "${work_dir}/cosbench-data/raw_data.csv" "${work_dir}/charts"
    for node in ${OSD_NODES}; do
        ./exportGraphs.py --zabbix="http://${ZABBIX_SERVER}/zabbix" \
                          --user="${ZABBIX_USER}" \
                          --password="${ZABBIX_PASSWORD}" \
                          --host="${node}" \
                          --start_time="${start_time}" \
                          --duration="${duration}" \
                          --dir="${work_dir}/charts"
    done
}

main(){
    local data_dir=$(mktemp -d)
    local test_number=0
    local test_dir

    local threads="48"
    local object_size_in_mb="1"
    local total_transmitted_mb="2145728"

    local pool_name_suffix="1"


: <<__EOF__
    local comment="Dry test after redeploying cluster"



    iteration=0
    while (( iteration < 1 )); do
        #deploy_cluster
        #configure_ceph
        #install_slaves_and_setup_controller
        #create_ceph_satus_service "${MON_NODES/ *}"
        #create_ceph_perf_service "${MON_NODES/ *}"
        create_pool "${POOL_BASE_NAME}${pool_name_suffix}" "${POOL_PG_NUM}"

        #for node in ${OSD_NODES}; do
        #    setup_zabbix_agent "${node}"
        #done
        #sleep 120

        work_dir="${BASE_WWW_DIR}/$(uuidgen)"
        mkdir -p "${work_dir}"
        full_featured_write_test "${threads}" \
                                 "${object_size_in_mb}" \
                                 "${total_transmitted_mb}" \
                                 "${POOL_BASE_NAME}" \
                                 "${pool_name_suffix}" \
                                 "${work_dir}" \
                                 "${comment}"
        
        : $(( test_number+=1 ))
        : $(( iteration+=1 ))
    done
__EOF__

    local comment="Test after recreating pool without redeploying cluster"
    #deploy_cluster
    #configure_ceph
    #install_slaves_and_setup_controller
    #create_ceph_satus_service "${MON_NODES/ *}"
    #create_ceph_perf_service "${MON_NODES/ *}"
    delete_pool "${POOL_BASE_NAME}${pool_name_suffix}"

    #for node in ${OSD_NODES}; do
    #    setup_zabbix_agent "${node}"
    #done
    #sleep 120
    iteration=0
    while (( iteration < 5 )); do
        create_pool "${POOL_BASE_NAME}${pool_name_suffix}" "${POOL_PG_NUM}"

        work_dir="${BASE_WWW_DIR}/$(uuidgen)"
        mkdir -p "${work_dir}"
        full_featured_write_test "${threads}" \
                                 "${object_size_in_mb}" \
                                 "${total_transmitted_mb}" \
                                 "${POOL_BASE_NAME}" \
                                 "${pool_name_suffix}" \
                                 "${work_dir}" \
                                 "${comment}"

        delete_pool "${POOL_BASE_NAME}${pool_name_suffix}"

        : $(( test_number+=1 ))
        : $(( iteration+=1 ))
    done


}

main ${@}
