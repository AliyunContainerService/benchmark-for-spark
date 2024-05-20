resource "alicloud_cs_kubernetes_addon" "virtual-node" {
  cluster_id = var.cluster_id
  name       = "ack-virtual-node"
  version    = "v2.10.4"
}
