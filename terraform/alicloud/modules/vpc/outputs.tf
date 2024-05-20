output "vpc_id" {
  value = alicloud_vpc.default.id
}

output "vswitch_id" {
  value = alicloud_vswitch.default.id
}
