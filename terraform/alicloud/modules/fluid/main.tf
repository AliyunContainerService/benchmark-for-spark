resource "alicloud_cs_kubernetes_node_pool" "fluid" {
  node_pool_name                          = "np-fluid-${var.suffix}"
  cluster_id                    = var.cluster_id
  vswitch_ids                   = var.vswitch_ids
  desired_size                  = var.instance_count
  instance_types                = [var.instance_type]
  image_type                    = "AliyunLinux3"
  system_disk_category          = "cloud_essd"
  system_disk_size              = 40
  system_disk_performance_level = "PL1"

  labels {
    key   = "benchmark.node.role"
    value = "fluid"
  }

  resource_group_id  = var.resource_group_id
  security_group_ids = [var.security_group_id]
}
