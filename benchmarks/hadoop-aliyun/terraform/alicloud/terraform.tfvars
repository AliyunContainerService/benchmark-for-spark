region = "cn-beijing"

zone_id = "cn-beijing-i"

profile = "default"

spark = {
  master = {
    instance_count = 1
    instance_type  = "ecs.g7.2xlarge"
  }
  worker = {
    instance_count = 6
    instance_type  = "ecs.g7.8xlarge"
  }
}
