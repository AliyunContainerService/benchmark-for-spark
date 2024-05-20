data "alicloud_cs_kubernetes_addons" "default" {
  cluster_id = module.cs.cluster_id
}

data "alicloud_cs_cluster_credential" "default" {
  cluster_id  = module.cs.cluster_id
  output_file = "~/.kube/config"
}
