variable "suffix" {
  type        = string
  description = "The suffix of name."
}

variable "vpc_id" {
  type        = string
  description = "The id of the vpc."
}

variable "resource_group_id" {
  type        = string
  description = "The id of the resource group."
}

variable "security_group_type" {
  type        = string
  description = "The type of the security group."
  default     = "normal"
}
