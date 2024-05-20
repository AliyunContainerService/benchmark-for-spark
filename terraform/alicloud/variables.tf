variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
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

# Fluid
variable "fluid_instance_count" {
  type = number
}

variable "fluid_instance_type" {
  type = string
}

# Celeborn
variable "celeborn_instance_count" {
  type = number
}

variable "celeborn_instance_type" {
  type = string
}
