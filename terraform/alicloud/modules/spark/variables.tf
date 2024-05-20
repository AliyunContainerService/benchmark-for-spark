variable "suffix" {
  type        = string
  description = "The suffix of name."
}

variable "cluster_id" {
  type        = string
  description = "The id of managed kubernetes cluster."
}

variable "vswitch_ids" {
  type = list(string)
}

variable "master_instance_count" {
  type    = number
  default = 1
}

variable "master_instance_type" {
  type    = string
}

variable "worker_instance_count" {
  type    = number
  default = 1
}

variable "worker_instance_type" {
  type    = string
}

variable "resource_group_id" {
  type        = string
  description = "The id of resource group."
}

variable "security_group_id" {
  type        = string
  description = "The id of security group."
}
