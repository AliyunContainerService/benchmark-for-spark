resource "alicloud_cs_kubernetes_node_pool" "spark-master" {
  node_pool_name                = "spark-master"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  instance_types                = [var.master_instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 120
  system_disk_performance_level = "PL0"

  labels {
    key   = "spark.tpcds.benchmark/role"
    value = "spark-master"
  }

  desired_size       = var.master_instance_count
  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}

resource "alicloud_cs_kubernetes_node_pool" "spark-worker" {
  node_pool_name                = "spark-worker"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  desired_size                  = var.worker_instance_count
  instance_types                = [var.worker_instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 120
  system_disk_performance_level = "PL0"

  data_disks {
    category     = "elastic_ephemeral_disk_standard"
    size         = 2048
    auto_format  = true
    file_system  = "xfs"
    mount_target = "/mnt/disk1"
  }

  data_disks {
    category     = "elastic_ephemeral_disk_standard"
    size         = 2048
    auto_format  = true
    file_system  = "xfs"
    mount_target = "/mnt/disk2"
  }

  data_disks {
    category     = "elastic_ephemeral_disk_standard"
    size         = 2048
    auto_format  = true
    file_system  = "xfs"
    mount_target = "/mnt/disk3"
  }

  data_disks {
    category     = "elastic_ephemeral_disk_standard"
    size         = 2048
    auto_format  = true
    file_system  = "xfs"
    mount_target = "/mnt/disk4"
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

  user_data = base64encode("chmod 777 /mnt/disk*")

  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}
