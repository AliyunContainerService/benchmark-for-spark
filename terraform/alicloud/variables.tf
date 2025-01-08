variable "profile" {
  type    = string
  default = "default"
}

variable "region" {
  type    = string
  default = "cn-beijing"
}

variable "zone_id" {
  type    = string
  default = "cn-beijing-i"
}

variable "bucket_name" {
  type        = string
  description = "The name of bucket."
  default     = "ack-spark-benchmark"
}

# Spark
variable "spark_master_instance_count" {
  type = number
}

variable "spark_master_instance_type" {
  type = string
}

variable "spark_worker_instance_count" {
  type = number
}

variable "spark_worker_instance_type" {
  type = string
}

# Celeborn
variable "celeborn_master_instance_count" {
  type = number
  description = "Instance count of Celeborn master node pool."
}

variable "celeborn_master_instance_type" {
  type = string
  description = "Instance type of Celeborn worker node pool"
  default = ""
}

variable "celeborn_worker_instance_count" {
  type = number
  description = "Instance count of Celeborn worker node pool."
}

variable "celeborn_worker_instance_type" {
  type = string
  description = "Instance type of Celeborn worker node pool."
}

# Fluid
variable "fluid_instance_count" {
  type = number
}

variable "fluid_instance_type" {
  type = string
}
