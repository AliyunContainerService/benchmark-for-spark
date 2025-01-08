variable "suffix" {
  type        = string
  description = "The suffix of name."
}

variable "cluster_id" {
  type        = string
  description = "The id of managed Kubernetes cluster."
}

variable "vswitch_ids" {
  type        = list(string)
  description = "The list of vswitch id."
}

variable "master_instance_count" {
  type = number
  description = "Instance count of Celeborn master node pool."
}

variable "master_instance_type" {
  type = string
  description = "Instance type of Celeborn worker node pool"
  default = "ecs.g7.2xlarge"
}

variable "worker_instance_count" {
  type = number
  description = "Instance count of Celeborn worker node pool."
}

variable "worker_instance_type" {
  type = string
  description = "Instance type of Celeborn worker node pool."
  default = "ecs.i4.8xlarge"
}

variable "resource_group_id" {
  type        = string
  description = "The id of resource group."
}

variable "security_group_id" {
  type        = string
  description = "The id of security group."
}
