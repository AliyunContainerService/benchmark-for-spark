resource "alicloud_resource_manager_resource_group" "default" {
  resource_group_name = "rg-${var.suffix}"
  display_name        = "rg-${var.suffix}"
}
