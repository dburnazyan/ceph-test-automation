SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_USER="user"
SSH_PASSWORD="password"
SSH_CMD="sshpass -p ${SSH_PASSWORD} ssh ${SSH_OPTIONS}"
SCP_CMD="sshpass -p ${SSH_PASSWORD} scp ${SSH_OPTIONS}"

tmp_script=$(mktemp)
chmod u+x ${tmp_script}
cat > ${tmp_script} <<__EOF__
chmod u+x /root/cosbench/0.4.2.c3/stop-driver.sh
cd /root/cosbench/0.4.2.c3
./stop-driver.sh
./start-driver.sh 16
#cd /root
#rm -rf ./cosbench*
__EOF__

for node in $NODES; do
    ${SCP_CMD} ${tmp_script} ${SSH_USER}@${node}:${tmp_script}
    ${SSH_CMD} ${SSH_USER}@${node} ${tmp_script}
done
find ${tmp_script} -path ${tmp_script} -delete
