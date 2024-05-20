resource "alicloud_cs_kubernetes_node_pool" "spark-master" {
  name                          = "np-spark-master-${var.suffix}"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  instance_types                = [var.master_instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 40
  system_disk_performance_level = "PL1"
  labels {
    key   = "benchmark.node.role"
    value = "spark-master"
  }
  desired_size       = var.master_instance_count
  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}

resource "alicloud_cs_kubernetes_node_pool" "spark-worker" {
  name                          = "np-spark-worker-${var.suffix}"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  desired_size                  = var.worker_instance_count
  instance_types                = [var.worker_instance_type]
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
    key   = "benchmark.node.role"
    value = "spark-worker"
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

  user_data = base64encode(file("${path.module}/user_data.sh"))

  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}
