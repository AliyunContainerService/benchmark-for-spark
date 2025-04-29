# Alicloud
profile = "default"
zone_id = "cn-beijing-i"

# Spark master node pool
spark_master_instance_count = 1
spark_master_instance_type  = "ecs.g8i.4xlarge"

# Spark worker node pool
spark_worker_instance_count = 2
spark_worker_instance_type  = "ecs.ebmg8ise.48xlarge"

# Celeborn master node pool
celeborn_master_instance_count = 0
celeborn_master_instance_type  = "ecs.g8i.2xlarge"

# Celeborn worker node pool
celeborn_worker_instance_count = 0
celeborn_worker_instance_type  = "ecs.i4.8xlarge"

# Fluid node pool
fluid_instance_count = 0
fluid_instance_type  = "ecs.i3.2xlarge"
