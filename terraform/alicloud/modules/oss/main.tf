resource "alicloud_oss_bucket" "default" {
  bucket = "bucket-${var.suffix}"
  acl = "private"
  storage_class = "Standard"
  redundancy_type = "LRS"
}
