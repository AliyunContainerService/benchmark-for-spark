resource "alicloud_cs_kubernetes_node_pool" "celeborn-master" {
  node_pool_name                = "celeborn-master"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  desired_size                  = var.master_instance_count
  instance_types                = [var.master_instance_type]
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
    size              = 40
    performance_level = "PL1"
    device            = "/dev/vdc"
  }

  labels {
    key   = "celeborn.apache.org/role"
    value = "master"
  }

  taints {
    key    = "celeborn.apache.org/role"
    value  = "master"
    effect = "NoSchedule"
  }

  user_data = base64encode(file("${path.module}/master_user_data.sh"))

  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}

resource "alicloud_cs_kubernetes_node_pool" "celeborn-worker" {
  node_pool_name                = "celeborn-worker"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  desired_size                  = var.worker_instance_count
  instance_types                = [var.worker_instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 40
  system_disk_performance_level = "PL1"

  labels {
    key   = "celeborn.apache.org/role"
    value = "worker"
  }

  taints {
    key    = "celeborn.apache.org/role"
    value  = "worker"
    effect = "NoSchedule"
  }

  user_data = base64encode(file("${path.module}/worker_user_data.sh"))

  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}
