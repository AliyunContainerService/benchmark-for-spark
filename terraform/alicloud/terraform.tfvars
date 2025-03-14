# Alicloud
profile = "default"
zone_id = "cn-beijing-i"

# Spark node pool
spark_master_instance_count = 1
spark_master_instance_type  = "ecs.g7.2xlarge"
spark_worker_instance_count = 6
spark_worker_instance_type  = "ecs.g7.8xlarge"

# Celeborn master node pool
celeborn_master_instance_count = 0
celeborn_master_instance_type  = "ecs.g8i.2xlarge"
celeborn_worker_instance_count = 0
celeborn_worker_instance_type  = "ecs.i4.8xlarge"

# Fluid node pool
fluid_instance_count = 0
fluid_instance_type  = "ecs.i3.2xlarge"
