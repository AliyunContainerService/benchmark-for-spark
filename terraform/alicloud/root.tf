# Create resource group
module "resouce_manager" {
  source = "./modules/resource-manager"
  suffix = random_string.suffix.id
}

# Create VPC and vswitch
module "vpc" {
  source            = "./modules/vpc"
  suffix            = random_string.suffix.id
  zone_id           = var.zone_id
  resource_group_id = module.resouce_manager.resource_group_id
}

# Create security group
module "ecs" {
  source            = "./modules/ecs"
  suffix            = random_string.suffix.id
  vpc_id            = module.vpc.vpc_id
  resource_group_id = module.resouce_manager.resource_group_id
}

# module "oss" {
#   source = "./modules/oss"
#   suffix = random_string.suffix.id
# }

# Create ACK
module "cs" {
  source             = "./modules/cs"
  suffix             = random_string.suffix.id
  worker_vswitch_ids = [module.vpc.vswitch_id]
  pod_vswitch_ids    = [module.vpc.vswitch_id]
  resource_group_id  = module.resouce_manager.resource_group_id
  security_group_id  = module.ecs.security_group_id
}

# Create node pool for spark
module "spark" {
  source                = "./modules/spark"
  suffix                = random_string.suffix.id
  cluster_id            = module.cs.cluster_id
  vswitch_ids           = [module.vpc.vswitch_id]
  master_instance_count = var.spark_master_instance_count
  master_instance_type  = var.spark_master_instance_type
  worker_instance_count = var.spark_worker_instance_count
  worker_instance_type  = var.spark_worker_instance_type
  resource_group_id     = module.resouce_manager.resource_group_id
  security_group_id     = module.ecs.security_group_id
}

# Create node pool for fluid
module "fluid" {
  source            = "./modules/fluid"
  suffix            = random_string.suffix.id
  cluster_id        = module.cs.cluster_id
  vswitch_ids       = [module.vpc.vswitch_id]
  instance_count    = var.fluid_instance_count
  instance_type     = var.fluid_instance_type
  resource_group_id = module.resouce_manager.resource_group_id
  security_group_id = module.ecs.security_group_id
}

# Create node pool for celeborn
module "celeborn" {
  source            = "./modules/celeborn"
  suffix            = random_string.suffix.id
  cluster_id        = module.cs.cluster_id
  vswitch_ids       = [module.vpc.vswitch_id]
  instance_count    = var.celeborn_instance_count
  instance_type     = var.celeborn_instance_type
  resource_group_id = module.resouce_manager.resource_group_id
  security_group_id = module.ecs.security_group_id
}

# Install ack-virtual-node addon
module "eci" {
  source     = "./modules/eci"
  cluster_id = module.cs.cluster_id
}
