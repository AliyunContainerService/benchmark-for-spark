resource "alicloud_vpc" "default" {
  vpc_name          = "vpc-${var.suffix}"
  cidr_block        = "192.168.0.0/16"
  resource_group_id = var.resource_group_id
}

resource "alicloud_vswitch" "default" {
  vswitch_name = "vsw-${var.suffix}"
  cidr_block   = "192.168.0.0/24"
  vpc_id       = alicloud_vpc.default.id
  zone_id      = var.zone_id
}
