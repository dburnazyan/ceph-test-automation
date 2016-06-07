#!/usr/bin/python
import os
import json
import uuid
import requests
import datetime
from influxdb import InfluxDBClient
import xml.etree.ElementTree as ET

def main(test_id, base_dir):
    for sub_dir in os.listdir(base_dir):
        if sub_dir.startswith("w{}-".format(test_id)):
            workload_dir = "{}/{}".format(base_dir, sub_dir)

    if workload_dir is None:
        return 1

    tree = ET.parse('{}/workload-config.xml'.format(workload_dir))
    root = tree.getroot()

    workstages=[]
    workstage_counter=1
    for el in root:
        if el.tag == "workflow":
            for el2 in el:
                if el2.tag == "workstage":
                    total_ops = 0
                    works=[]
                    for el3 in el2:
                        if el3.tag == "work":
                            work={"name":el3.attrib["name"],
                                  "workers": el3.attrib["workers"]}
                            operations=[]
                            for el4 in el3:
                                if el4.tag == "operation":
                                    total_ops += 1
                                    operations.append({"type":el4.attrib["type"],
                                                       "id":int(el4.attrib["id"][2:]),
                                                       "ratio":el4.attrib["ratio"],
                                                       "config":el4.attrib["config"]})
                            work["operations"]=operations
                            works.append(work)
                    if len(works) != 0:
                        workstage={"name":el2.attrib["name"],
                                   "id": workstage_counter,
                                   "total_ops": total_ops}
                        workstage_counter+=1
                        workstage["works"]=works
                        workstages.append(workstage)
    workflow={"name": root.attrib["name"], "workstages":workstages}

    client = InfluxDBClient('1.2.3.4', 8086, 'root', 'root', 'cosbench')
    points=[]
    for stage in workflow["workstages"]:
        with open("{}/s{}-{}.csv".format(workload_dir, stage["id"], stage["name"]), "r") as f:
            content = f.readlines()
        for line in content[2:]:
            for work in stage["works"]:
                for operation in work["operations"]:
                    data = line.split(",")
                    dt = datetime.datetime.strptime(data[0],'%Y-%m-%d %H:%M:%S%z')
                    point = {"measurement": "test_result"}
                    point["time"] = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
                    point["tags"] = {
                                     "clients": work["workers"],
                                     "op_type": operation["type"],
                                     "test_id": "",
                                     "stage_id": operation["id"],
                                     "config": operation["config"]
                                    }
                    througput = float(data[4*stage["total_ops"] + operation["id"]])
                    bandwidth = float(data[5*stage["total_ops"] + operation["id"]])
                    point["fields"] = {"througput": througput, "badwidth": bandwidth}
                    points.append(point)
    client.write_points(points)

if __main__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument('-w', action='store', dest='test_id',
                    help='Test run id')
    parser.add_argument('-d', action='store', dest='base_dir',
                    help='Base archive dir')

    results = parser.parse_args()
    main(test_id=results.test_id, base_dir=results.base_dir)
