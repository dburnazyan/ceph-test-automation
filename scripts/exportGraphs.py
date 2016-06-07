#!/usr/bin/python
from argparse import ArgumentParser
from zabbix.api import ZabbixAPI
import requests
import shutil

GRAPH_NAMES = ["CPU load",
               "CPU utilization",
               "Memory usage",
               "Disk sdc - Overview",
               "Disk sdd - Overview",
               "Disk sde - Overview",
               "Disk sdf - Overview",
               "Disk sdg - Overview",
               "Disk sdh - Overview",
               "Disk sdi - Overview",
               "Disk sdj - Overview",
               "Disk sdk - Overview",
               "Disk sdl - Overview",
               "Disk sdm - Overview",
               "Disk sdn - Overview",
               "Disk sdo - Overview",
               "Disk sdp - Overview",
               "Disk sdq - Overview",
               "Disk sdr - Overview",
               "Disk sds - Overview",
               "Disk sdt - Overview",
               "Disk sdu - Overview",
               "Disk sdv - Overview",
               "Disk sdw - Overview",
               "Disk sdx - Overview",
               "Disk sdy - Overview",
               "Disk sdz - Overview",
               "Network traffic on eth2.150",
               "Network traffic on eth3.1021"]


def main():
    parser = ArgumentParser()
    parser.add_argument("-z", "--zabbix",
                        help="Zabbox URL",
                        required=True)
    parser.add_argument("-u", "--user",
                        help="Zabbix user name",
                        required=True)
    parser.add_argument("-p", "--password",
                        help="Zabbix user password",
                        required=True)
    parser.add_argument("-D", "--dir",
                        help="Directory where charts will be saved",
                        required=True)
    parser.add_argument("-s", "--start_time",
                        help="Chart data start time",
                        required=True)
    parser.add_argument("-d", "--duration",
                        help="Chart data duration",
                        required=True)
    parser.add_argument("-H", "--host",
                        help="Host name",
                        required=True)
    args = parser.parse_args()
    zabbix = args.zabbix
    user = args.user
    password = args.password
    host = args.host
    start_time = args.start_time
    duration = int(args.duration)
    chart_dir = args.dir

    if duration < 60:
        duration = 60

    zapi = ZabbixAPI(url=zabbix,
                     user=user, password=password)

    host_id = zapi.get_id(item_type='host', item=host)

    zapi = ZabbixAPI(url=zabbix,
                     user=user, password=password)
    graphs = zapi.do_request(method="graph.get",
                             params={"hostids": host_id})['result']

    graph_ids = {}
    for graph in graphs:
        if graph['name'] in GRAPH_NAMES:
            graph_ids[graph['graphid']] = graph['name']

    s = requests.Session()
    payload = {'name': user,
               'password': password,
               'enter': 'Sign in',
               'autologin': '1',
               'request': ''}
    url = "{0}/index.php?login=1".format(zabbix)
    s.post(url, data=payload)
    for graph_id, graph_name in graph_ids.iteritems():
        url = ("{0}/chart2.php?"
               "graphid={1}&stime={2}&period={3}".format(zabbix,
                                                         graph_id,
                                                         start_time,
                                                         duration))
        response = s.get(url, stream=True)
        file_name = "{0}/{1}-{2}.png".format(chart_dir,
                                             host,
                                             graph_name.replace(" ", "_"))
        with open(file_name, 'wb') as f:
            shutil.copyfileobj(response.raw, f)


if __name__ == "__main__":
    main()
