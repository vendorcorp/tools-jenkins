variable "aws_region" {
  description = "AWS Region that our deployment is targetting"
  type        = string
  default     = "us-east-2"
}

variable "default_resource_tags" {
  description = "List of tags to apply to all resources created in AWS"
  type        = map(string)
  default = {
    environment : "development"
    purpose : "vendorcorp"
    owner : "phorton@sonatype.com"
    sonatype-group : "se"
    vendorcorp-purpose : "iday"
  }
}

# See https://docs.sonatype.com/display/OPS/Shared+Infrastructure+Initiative
variable "environment" {
  description = "Used as part of Sonatype's Shared AWS Infrastructure"
  type        = string
  default     = "production"
}

# Jenkins Operator Chart Version
variable "jeknins_operator_version" {
  description = "Version of the Jenkins Operator to deploy"
  type        = string
  default     = "v0.8.1"
}