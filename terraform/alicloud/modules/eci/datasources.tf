data "alicloud_cs_kubernetes_addon_metadata" "ack-virtual-node" {
  cluster_id = var.cluster_id
  name       = "ack-virtual-node"
  version    = "v2.9.7"
}
