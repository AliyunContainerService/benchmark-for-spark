variable "region" {
  type    = string
  default = "cn-beijing"
}

variable "zone_id" {
  type    = string
  default = "cn-beijing-i"
}

variable "profile" {
  type    = string
  default = "default"
}

variable "spark" {
  type = object({
    master = object({
      instance_count = number
      instance_type  = string
    })
    worker = object({
      instance_count = number
      instance_type  = string
    })
  })
  default = {
    master = {
      instance_count = 0
      instance_type  = "ecs.g7.2xlarge"
    }
    worker = {
      instance_count = 0
      instance_type  = "ecs.g7.8xlarge"
    }
  }
}
