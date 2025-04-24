terraform {
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.223.2"
    }
  }

  required_version = ">= 1.8.0"
}

resource "random_string" "suffix" {
  length  = 16
  lower   = true
  upper   = false
  special = false
}

resource "alicloud_resource_manager_resource_group" "default" {
  resource_group_name = "rg-${random_string.suffix.result}"
  display_name        = "rg-${random_string.suffix.result}"
}

resource "alicloud_vpc" "default" {
  vpc_name          = "vpc-${random_string.suffix.result}"
  cidr_block        = "192.168.0.0/16"
  resource_group_id = alicloud_resource_manager_resource_group.default.id
}

resource "alicloud_vswitch" "default" {
  vswitch_name = "vsw-${random_string.suffix.result}"
  cidr_block   = "192.168.0.0/24"
  vpc_id       = alicloud_vpc.default.id
  zone_id      = var.zone_id
}

resource "alicloud_security_group" "default" {
  name                = "sg-${random_string.suffix.result}"
  vpc_id              = alicloud_vpc.default.id
  resource_group_id   = alicloud_resource_manager_resource_group.default.id
  security_group_type = "normal"
}

resource "alicloud_security_group_rule" "default" {
  type              = "ingress"
  ip_protocol       = "all"
  port_range        = "-1/-1"
  cidr_ip           = "192.168.0.0/16"
  security_group_id = alicloud_security_group.default.id
  priority          = 1
}

resource "alicloud_security_group_rule" "icmp" {
  type              = "ingress"
  ip_protocol       = "icmp"
  port_range        = "-1/-1"
  cidr_ip           = "0.0.0.0/0"
  security_group_id = alicloud_security_group.default.id
  priority          = 1
}

resource "alicloud_cs_managed_kubernetes" "default" {
  name     = "ack-${random_string.suffix.result}"
  timezone = "Asia/Shanghai"
  version  = "1.32.1-aliyun.1"

  worker_vswitch_ids = [alicloud_vswitch.default.id]
  pod_vswitch_ids    = [alicloud_vswitch.default.id]
  service_cidr       = "172.16.0.0/16"

  addons {
    name = "terway-eniip"
  }

  proxy_mode           = "ipvs"
  cluster_domain       = "cluster.local"
  deletion_protection  = false
  cluster_spec         = "ack.pro.small"
  load_balancer_spec   = "slb.s1.small"
  new_nat_gateway      = true
  slb_internet_enabled = true
  resource_group_id    = alicloud_resource_manager_resource_group.default.id
  security_group_id    = alicloud_security_group.default.id
}

resource "alicloud_cs_kubernetes_node_pool" "spark-master" {
  node_pool_name                = "spark-master"
  cluster_id                    = alicloud_cs_managed_kubernetes.default.id
  vswitch_ids                   = [alicloud_vswitch.default.id]
  desired_size                  = var.spark.master.instance_count
  instance_types                = [var.spark.master.instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 40
  system_disk_performance_level = "PL1"

  labels {
    key   = "spark.tpcds.benchmark/role"
    value = "spark-master"
  }

  resource_group_id  = alicloud_resource_manager_resource_group.default.id
  security_group_ids = [alicloud_security_group.default.id]
}

resource "alicloud_cs_kubernetes_node_pool" "spark-worker" {
  node_pool_name                = "spark-worker"
  cluster_id                    = alicloud_cs_managed_kubernetes.default.id
  vswitch_ids                   = [alicloud_vswitch.default.id]
  desired_size                  = var.spark.worker.instance_count
  instance_types                = [var.spark.worker.instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 40
  system_disk_performance_level = "PL1"
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vdb"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vdc"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vdd"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vde"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vdf"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 300
    performance_level = "PL1"
    device            = "/dev/vdg"
  }
  data_disks {
    category          = "cloud_essd"
    size              = 40
    performance_level = "PL1"
    device            = "/dev/vdh"
  }

  labels {
    key   = "spark.tpcds.benchmark/role"
    value = "spark-worker"
  }

  taints {
    key    = "spark.tpcds.benchmark/role"
    value  = "spark-worker"
    effect = "NoSchedule"
  }

  kubelet_configuration {
    eviction_hard = {
      "imagefs.available" = "5%"
      "memory.available"  = "100Mi"
      "nodefs.available"  = "5%"
      "nodefs.inodesFree" = "5%"
    }
    system_reserved = {
      cpu    = "300m"
      memory = "600Mi"
      pid    = "1000"
    }
    kube_reserved = {
      cpu    = "300m"
      memory = "600Mi"
      pid    = "1000"
    }
  }

  user_data = base64encode(file("user_data.sh"))

  resource_group_id  = alicloud_resource_manager_resource_group.default.id
  security_group_ids = [alicloud_security_group.default.id]
}
