resource "alicloud_cs_managed_kubernetes" "default" {
  name     = "ack-${var.suffix}"
  timezone = "Asia/Shanghai"
  version  = "1.28.9-aliyun.1"

  worker_vswitch_ids = var.worker_vswitch_ids
  pod_vswitch_ids    = var.pod_vswitch_ids
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
  resource_group_id    = var.resource_group_id
  security_group_id    = var.security_group_id
}
