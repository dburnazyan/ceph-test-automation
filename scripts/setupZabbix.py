#!/usr/bin/python
from argparse import ArgumentParser
import json
from zabbix.api import ZabbixAPI


def update_zabbix_host(zapi, host, host_id):
    #request = {}
    #request['hostid'] = str(host_id)
    #interface = {}
    #interface['type'] = 1
    #interface['main'] = 1
    #interface['useip'] = 0
    #interface['ip'] = ''
    #interface['dns'] = host
    #interface['port'] = '10050'
    #request['interfaces'] = interface
    #zapi.do_request(method="hostinterface.replacehostinterfaces",
    #                params=request)
    
    request = {}
    request['hostid'] = str(host_id)
    request['groups'] = [{'groupid': '2'}]
    request['templates'] = []
    request['templates'].append({'templateid': '10107'})
    request['templates'].append({'templateid': '10118'})

    zapi.do_request(method='host.update',
                    params=request)


def create_zabbix_host(zapi, host):
    request = {}
    request['host'] = host
    interface = {}
    interface['type'] = 1
    interface['main'] = 1
    interface['useip'] = 0
    interface['ip'] = ''
    interface['dns'] = host
    interface['port'] = '10050'
    request['interfaces'] = [interface]
    request['groups'] = [{'groupid': '2'}]
    request['templates'] = []
    request['templates'].append({'templateid': '10107'})
    request['templates'].append({'templateid': '10118'})
    zapi.do_request(method='host.create',
                    params=request)


def main(zabbix, user, password, host):
    zapi = ZabbixAPI(url=zabbix,
                     user=user, password=password)

    host_id = zapi.get_id(item_type='host', item=host)
    if host_id is None:
        create_zabbix_host(zapi=zapi, host=host)
    else:
        update_zabbix_host(zapi=zapi, host=host, host_id=host_id)


if __name__ == '__main__':
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
    parser.add_argument("-H", "--host",
                        help="Host name",
                        required=True)
    args = parser.parse_args()
    main(zabbix=args.zabbix, user=args.user, password=args.password,
         host=args.host)
