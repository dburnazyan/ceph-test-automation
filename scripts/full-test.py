#!/usr/bin/python
import datetime
import logging
import re
import requests
import json
import jinja2
from time import sleep
import numpy
import xml.etree.ElementTree as ET
import gspread
from oauth2client.service_account import ServiceAccountCredentials
logging.basicConfig(level=logging.DEBUG)

TEMPLATE_DIR = "./workload-templates"

class Monitor(object):
    def __init__(self, node_list):
        self.node_list = node_list

    def install(self):
        pass

    def start_all(self):
        pass

    def stop_all(self):
        pass

    def collect_data_all(self):
        pass

class CosbenchController(object):
    def __init__(self, cosbench_ip):
        self.cosbench_ip = cosbench_ip

    def perform_test(self):
        pass

    def get_workload_info(self):
        pass

class CephConfigurer(object):
    def __init__(self, mon_ip):
        self.mon_ip = mon_ip

    def create_pool(self, pg_num, replica_count):
        pass

    def setConfigParam(self, param_name, param_value):
        pass

class NodeManager(object):
    def __init__(self, mon_list, osd_list):
        self.mon_list = mon_list
        self.osd_list = osd_list

    def get_mons(self):
        pass

    def get_osds(self):
        pass

    def install_os(self):
        pass

    def set_io_scheduler(self):
        pass

class CosbenchTester(object):
    def __init__(self, mon_ip, cosbench_ip, pool_base_name, pool_name_suffix,
                 pool_total_size, access_key, secret_key, max_bandwidth):
        self.mon_ip = mon_ip
        self.pool_base_name = pool_base_name
        self.pool_name_suffix = pool_name_suffix
        self.pool_total_size = pool_total_size
        self.access_key = access_key
        self.secret_key = secret_key
        with requests.Session() as s:
            s.get("http://"+cosbench_ip+":19088/controller/index.html",
                timeout=None)
            data = {"j_username":"anonymous", "j_password":"cosbench"}
            url = "http://"+cosbench_ip+":19088/controller/j_security_check"
            r = s.post(url, data=data, timeout=None)
            self.cosb_cookies = requests.utils.dict_from_cookiejar(s.cookies)
        self.cosbench_ip = cosbench_ip
        self.mon_ip = mon_ip
        templateLoader = jinja2.FileSystemLoader( searchpath=TEMPLATE_DIR )
        templateEnv = jinja2.Environment( loader=templateLoader )
        self.read_test_template = templateEnv.get_template("read.j2.xml")
        self.write_test_template = templateEnv.get_template("write.j2.xml")
        self.rewrite_test_template = templateEnv.get_template("rewrite.j2.xml")
        self.read_write_test_template = templateEnv.get_template("read-write.j2.xml")
        self.prepare_template = templateEnv.get_template("prepare.j2.xml")
        self.cleanup_template = templateEnv.get_template("cleanup.j2.xml")
        scope = ['https://spreadsheets.google.com/feeds']
        self.g_cred = ServiceAccountCredentials.from_json_keyfile_name(
            'cred.json', scope)
        gc = gspread.authorize(self.g_cred)
        self.gclient = gc
        self.max_bandwidth = max_bandwidth

    def parse_obj_size(self, obj_size_with_dim):
        m = re.search("(\d+)([km])", obj_size_with_dim)
        if m is not None:
            obj_size = int(m.group(1))
            obj_size_dim = m.group(2)
        else:
            raise ValueError("Object size str format error")

        while obj_size >= 1024:
            if obj_size_dim == "m":
                break
            elif obj_size_dim == "k":
                obj_size_dim = "m"
            obj_size = int(obj_size / 1024)

        if obj_size_dim == "k":
            obj_size_in_b = obj_size * 1024
            obj_size_in_k = obj_size
        elif obj_size_dim == "m":
            obj_size_in_b = obj_size * 1024 * 1024
            obj_size_in_k = obj_size * 1024
        else:
            raise ValueError("Unknown object size dimension error")

        return {"in_b": obj_size_in_b,
                "in_k": obj_size_in_k,
                "dim": obj_size_dim,
                "size": obj_size}

    def perform_test(self, workload_xml):
        logging.debug("Trying to submit workload:\n{}".format(workload_xml))
        with requests.Session() as s:
            url = "http://"+self.cosbench_ip+":19088/controller/submit-workload.do"
            files = {"config": ("workload.xml", workload_xml, "text/xml")}
            cookies = requests.utils.cookiejar_from_dict(self.cosb_cookies)
            res = s.post(url, cookies=cookies, files=files, timeout=None)
            logging.debug(res.text)
        for line in res.text.split("\n"):
            m = re.search(".*id=(w\d+).*", line)
            if m is not None:
                workload_id = m.group(1)
                break
        logging.info("Workload {} was submitted".format(
            workload_id
        ))
        url = "http://"+self.cosbench_ip+":19088/controller/workload.html?id="+workload_id

        while True:
            with requests.Session() as s:
                cookies = requests.utils.cookiejar_from_dict(self.cosb_cookies)
                res = s.get(url, cookies=cookies, timeout=None)
            for line in res.text.split("\n"):
                m = re.search(".*<span class=\"workload-state-[a-z]+ state\">([a-zA-Z]+)</span>.*", line)
                if m is not None:
                    cur_status = m.group(1)
                    logging.debug("Current status is "+ cur_status)
                    if cur_status == "finished" or cur_status == "cancelled" or cur_status == "terminated":
                        return workload_id
            sleep(60)

        return workload_id

    def fill_pool(self, obj_size_with_dim):
        obj_size = self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024
        obj_max_num = int(pool_size_in_k / obj_size["in_k"])

        obj_prefix = "{obj_size}{obj_size_dim}-obj-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        workload_xml = self.prepare_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                obj_prefix=obj_prefix,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_size_in_b=obj_size["in_b"],
                                obj_max_num=obj_max_num
        )
        workload_id = self.perform_test(workload_xml)

    def rm_objects_from_pool(self, obj_size_with_dim):
        obj_size = self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024
        obj_max_num = int(pool_size_in_k / obj_size["in_k"])

        obj_prefix = "{obj_size}{obj_size_dim}-obj-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        workload_xml = self.cleanup_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                obj_prefix=obj_prefix,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_max_num=obj_max_num
        )
        workload_id = self.perform_test(workload_xml)

    def read_test(self, obj_size_with_dim, thread_list):
        obj_size = self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024
        obj_max_num = int(pool_size_in_k / obj_size["in_k"])

        obj_prefix = "{obj_size}{obj_size_dim}-obj-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        stages = []
        for threads in thread_list:
            stage = {}
            stage["name"] = "o{obj_size}{obj_size_dim}-t{threads}".format(
                obj_size=obj_size["size"],
                obj_size_dim=obj_size["dim"],
                threads=threads
            )
            stage["threads"] = threads
            stages.append(stage)

        workload_xml = self.read_test_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_prefix=obj_prefix,
                                obj_max_num=obj_max_num,
                                stages=stages
        )
        workload_id = self.perform_test(workload_xml)

        self.process_result_data(workload_id=workload_id,
                            test_type="read",
                            obj_size=obj_size["in_k"])

        return workload_id


    def write_test(self, obj_size_with_dim, thread_list):
        obj_size = self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024
        obj_max_num = int(pool_size_in_k / obj_size["in_k"])

        obj_prefix = "{obj_size}{obj_size_dim}-obj-write-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        stages = []
        for threads in thread_list:
            stage = {}
            stage["name"] ="o{obj_size}{obj_size_dim}-t{threads}".format(
                obj_size=obj_size["size"],
                obj_size_dim=obj_size["dim"],
                threads=threads
                )
            stage["threads"] = threads
            stages.append(stage)

        workload_xml = self.write_test_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                obj_prefix=obj_prefix,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_size_in_b=obj_size["in_b"],
                                obj_max_num=obj_max_num,
                                stages=stages
        )
        workload_id = self.perform_test(workload_xml)

        self.process_result_data(workload_id=workload_id,
                            test_type="write",
                            obj_size=obj_size)

        return workload_id

    def rewrite_test(self, obj_size_with_dim, thread_list):
        obj_size = self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024

        obj_max_num = int(pool_size_in_k / obj_size["in_k"])
        obj_prefix = "{obj_size}{obj_size_dim}-obj-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        stages = []
        for threads in thread_list:
            stage = {}
            stage["name"] ="o{obj_size}{obj_size_dim}-t{threads}".format(
                obj_size=obj_size["size"],
                obj_size_dim=obj_size["dim"],
                threads=threads
                )
            stage["threads"] = threads
            stages.append(stage)

        workload_xml = self.rewrite_test_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                obj_prefix=obj_prefix,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_size_in_b=obj_size["in_b"],
                                obj_max_num=obj_max_num,
                                stages=stages
        )
        workload_id = self.perform_test(workload_xml)

        self.process_result_data(workload_id=workload_id,
                                 test_type="write",
                                 obj_size=obj_size)

        return workload_id

    def read_write_test(self, obj_size_with_dim, thread_list, read_ratio_list):
        obj_size= self.parse_obj_size(obj_size_with_dim)

        pool_size_in_k = self.pool_total_size * 1024 * 1024

        obj_max_num = int(pool_size_in_k / obj_size["in_k"])
        read_obj_prefix = "{obj_size}{obj_size_dim}-obj-".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        write_obj_prefix = "{obj_size}{obj_size_dim}-obj-write".format(
            obj_size=obj_size["size"],
            obj_size_dim=obj_size["dim"]
        )

        stages = []
        for threads in thread_list:
            for read_ratio in read_ratio_list:
                write_ratio = 100 - read_ratio
                stage = {}
                stage["name"] = ("o{obj_size}{obj_size_dim}-t{threads}-"
                                "r{read_ratio}/{write_ratio}").format(
                    obj_size=obj_size["size"],
                    obj_size_dim=obj_size["dim"],
                    threads=threads,
                    read_ratio=read_ratio,
                    write_ratio=write_ratio
                    )
                stage["threads"] = threads
                stage["read_ratio"] = read_ratio
                stage["write_ratio"] = write_ratio
                stages.append(stage)

        workload_xml = self.read_write_test_template.render(
                                mon_ip=self.mon_ip,
                                access_key=self.access_key,
                                secret_key=self.secret_key,
                                pool_base_name=self.pool_base_name,
                                pool_name_suffix=self.pool_name_suffix,
                                read_obj_prefix=read_obj_prefix,
                                write_obj_prefix=write_obj_prefix,
                                read_obj_max_num=obj_max_num,
                                write_obj_max_num=obj_max_num,
                                obj_size=obj_size["size"],
                                obj_size_dim=obj_size["dim"],
                                obj_size_in_b=obj_size["in_b"],
                                stages=stages
        )
        workload_id = self.perform_test(workload_xml)

        self.process_result_data(workload_id=workload_id,
                                 test_type="read-write",
                                 obj_size=obj_size)

        return workload_id

    def parse_workload_info(self, workload_id):
        url = "http://"+self.cosbench_ip+":19088/controller/download-config.do?id="+workload_id
        with requests.Session() as s:
            cookies = requests.utils.cookiejar_from_dict(self.cosb_cookies)
            res = s.get(url, cookies=cookies,timeout=None)
        workload_xml = res.text
        logging.debug(workload_xml)
        root = ET.fromstring(workload_xml)

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
                                      "threads": el3.attrib["workers"]}
                                operations=[]
                                for el4 in el3:
                                    if el4.tag == "operation":
                                        total_ops += 1
                                        operations.append({"type":el4.attrib["type"],
                                                           "id":int(el4.attrib["id"][2:]),
                                                           "ratio":el4.attrib["ratio"],
                                                           "config":el4.attrib["config"],
                                                           "data":[]})
                                work["operations"]=operations
                                works.append(work)
                        if len(works) != 0:
                            workstage={"name":el2.attrib["name"],
                                       "id": workstage_counter,
                                       "total_ops": total_ops}
                            workstage_counter+=1
                            workstage["works"]=works
                            workstages.append(workstage)
        workload={"id": workload_id, "name": root.attrib["name"], "workstages":workstages}

        for stage in workload["workstages"]:
            url = "http://{}:19088/controller/timeline.csv?wid={}&sid=s{}-{}".format(self.cosbench_ip,
                workload_id,
                stage["id"],
                stage["name"]
            )
            with requests.Session() as s:
                cookies = requests.utils.cookiejar_from_dict(self.cosb_cookies)
                res = s.get(url, cookies=cookies, timeout=None)
            logging.debug("Timeline csv workload {} stage {}:\n{}".format(
                workload_id,
                stage["id"],
                res.text
            ))
            content = res.text.split("\n")
            for line in content[2:]:
                if not line:
                    continue
                for work in stage["works"]:
                    for operation in work["operations"]:
                        data = line.split(",")
                        dt = datetime.datetime.strptime(data[0],'%Y-%m-%d %H:%M:%S-0400')
                        timestamp = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
                        througput = float(data[4*stage["total_ops"] + operation["id"]])
                        bandwidth = float(data[5*stage["total_ops"] + operation["id"]])
                        operation["data"].append({"timestamp": timestamp,
                                                  "througput": througput,
                                                  "bandwidth": bandwidth})

        return workload

    def process_result_data(self, workload_id, test_type, obj_size):
        workload = self.parse_workload_info(workload_id)
        rows = self.generate_computed_rows(workload=workload,
            obj_size=obj_size)

        g_cli = gspread.authorize(self.g_cred)
        wks = g_cli.open("Test results").worksheet(test_type)
        for row in rows:
            logging.debug("Inserting into gdocs row:{}".format(row))
            wks.append_row(row.split(','))

    def generate_computed_rows(self, workload, obj_size):
        rows = []
        for stage in workload["workstages"]:
            if stage["name"].endswith("-prepare"):
                continue
            for work in stage["works"]:
                for operation in work["operations"]:
                    if operation["type"] not in ["read", "write"]:
                        logging.info(("Workload {} operation {} is't "
                                        "target, skip").format(
                            workload_id,
                            operation["id"]
                        ))
                        continue
                    if len(operation["data"]) < 72:
                        logging.info(("Too few snapshots in worload {} "
                                        "operation {}, skip").format(
                            workload_id,
                            operation["id"]
                        ))
                        continue
                    bandwidth_set = []
                    througput_set = []
                    for point in operation["data"][12:73]:
                        bandwidth_set.append(point["bandwidth"])
                        througput_set.append(point["througput"])

                    row = self.compute_row(bandwidth_set=bandwidth_set,
                                            througput_set=througput_set)
                    rows.append(("{workload_id},{stage_id},{operation_id},"
                        "{operation_type},{threads},{obj_size},{row}").format(
                            workload_id=workload["id"],
                            stage_id=stage["id"],
                            operation_id=operation["id"],
                            operation_type=operation["type"],
                            threads=work["threads"],
                            obj_size=obj_size,
                            row=row))
        return rows

    def compute_row(self, bandwidth_set, througput_set):
        througput = {
            "stdev": float(numpy.std(a=througput_set, ddof=1)),
            "mean": float(numpy.mean(a=througput_set)),
            "perc50": float(numpy.percentile(a=througput_set, q=50)),
            "perc10": float(numpy.percentile(a=througput_set, q=10)),
            "min": float(numpy.min(a=througput_set)),
            "max": float(numpy.max(a=througput_set))
        }

        bandwidth = {
            "stdev": float(numpy.std(a=bandwidth_set, ddof=1)),
            "mean": float(numpy.mean(a=bandwidth_set)),
            "perc50": float(numpy.percentile(a=bandwidth_set, q=50)),
            "perc10": float(numpy.percentile(a=bandwidth_set, q=10)),
            "min": float(numpy.min(a=bandwidth_set)),
            "max": float(numpy.max(a=bandwidth_set))
        }

        row = "{},{},{},{},{},{},{},{},{},{},{},{}".format(
               "{0:.3f}".format(througput["mean"]),
               "{0:.3f}".format(througput["perc50"]),
               "{0:.3f}".format(througput["perc10"]),
               "{0:.3f}".format(througput["stdev"]),
               "{0:.3f}".format(througput["min"]),
               "{0:.3f}".format(througput["max"]),
               "{0:.3f}".format(bandwidth["mean"] / (1024 * 1024)),
               "{0:.3f}".format(bandwidth["perc50"] / (1024 * 1024)),
               "{0:.3f}".format(bandwidth["perc10"] / (1024 * 1024)),
               "{0:.3f}".format(bandwidth["stdev"] / (1024 * 1024)),
               "{0:.3f}".format(bandwidth["min"] / (1024 * 1024)),
               "{0:.3f}".format(bandwidth["max"] / (1024 * 1024))
            )
        return row

    def write_data_to_influx(self, workload, test_type):
        client = InfluxDBClient('172.16.44.2', 8086, 'root', 'root','cosbench')
        for stage in workload_config["workstages"]:
            if stage["op_type"] is test_type:
                client.write_points(stage["points"])

def main():
    mon_ip ="10.40.0.30"
    cosbench_ip = "1.2.3.4"
    access_key = "admin"
    secret_key = ""
    pool_base_name = "testpool_"
    pool_name_suffix = "1"
    thread_list = [1,2,4,8,16,32,64,128,256]
    obj_size_list = ["512k","1m"]
    read_write_ratio_list = [90, 80, 70, 60, 50, 40, 30, 20, 10]
    pool_total_size = 4096

    tester = CosbenchTester(
        cosbench_ip = cosbench_ip,
        mon_ip = mon_ip,
        access_key = access_key,
        secret_key = secret_key,
        pool_total_size = pool_total_size,
        pool_base_name = pool_base_name,
        pool_name_suffix = pool_name_suffix,
        max_bandwidth = 3
    )

    is_first = True
    monitor = Monitor([])
    for obj_size in obj_size_list:
        if not is_first:
            tester.fill_pool(obj_size)

            monitor.start_all()
            workload_id = tester.read_test(obj_size, thread_list)
            monitor.stop_all()
            monitor.collect_data_all()
        else:
            tester.process_result_data(workload_id="w107",
                                test_type="read",
                                obj_size=512)
        monitor.start_all()
        workload_id = tester.write_test(obj_size, thread_list)
        monitor.stop_all()
        monitor.collect_data_all()

        monitor.start_all()
        workload_id = tester.rewrite_test(obj_size, thread_list)
        monitor.stop_all()
        monitor.collect_data_all()

        monitor.start_all()
        workload_id = tester.read_write_test(obj_size, thread_list,
            read_ratio_list)
        monitor.stop_all()
        monitor.collect_data_all()

        tester.rm_objects_from_pool(obj_size)


if __name__ == "__main__":
    main()
