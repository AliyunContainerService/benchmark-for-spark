output "id" {
  value       = alicloud_oss_bucket.default.id
  description = "The name of the bucket."
}

output "extranet_endpoint" {
  value       = alicloud_oss_bucket.default.extranet_endpoint
  description = "The extranet access endpoint of the bucket"
}

output "intranet_endpoint" {
  value       = alicloud_oss_bucket.default.intranet_endpoint
  description = "The intranet access endpoint of the bucket."
}

output "location" {
  value       = alicloud_oss_bucket.default.location
  description = "The location of the bucket."
}
