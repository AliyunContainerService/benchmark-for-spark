variable "suffix" {
  type        = string
  description = "The suffix of name."
}

variable "worker_vswitch_ids" {
  type        = list(string)
  description = "The id list of worker vswitch."
}

variable "pod_vswitch_ids" {
  type        = list(string)
  description = "The id list of pod vswitch."
}

variable "resource_group_id" {
  type        = string
  description = "The id of resource group."
}

variable "security_group_id" {
  type        = string
  description = "The id of security group."
}
