resource "alicloud_security_group" "default" {
  security_group_name = "sg-${var.suffix}"
  vpc_id              = var.vpc_id
  resource_group_id   = var.resource_group_id
  security_group_type = var.security_group_type
}

resource "alicloud_security_group_rule" "default" {
  type              = "ingress"
  ip_protocol       = "all"
  port_range        = "-1/-1"
  cidr_ip           = "192.168.0.0/16"
  security_group_id = alicloud_security_group.default.id
  priority          = 1
}

resource "alicloud_security_group_rule" "icmp" {
  type              = "ingress"
  ip_protocol       = "icmp"
  port_range        = "-1/-1"
  cidr_ip           = "0.0.0.0/0"
  security_group_id = alicloud_security_group.default.id
  priority          = 1
}
