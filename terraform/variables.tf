variable "environment_id" {
  description = "ID of the existing Confluent Cloud environment (env-...)."
  type        = string

  validation {
    condition     = can(regex("^env-[a-z0-9]+$", var.environment_id))
    error_message = "environment_id must look like env-abc123."
  }
}

variable "kafka_cluster_id" {
  description = "ID of the existing Kafka cluster (lkc-...)."
  type        = string

  validation {
    condition     = can(regex("^lkc-[a-z0-9]+$", var.kafka_cluster_id))
    error_message = "kafka_cluster_id must look like lkc-abc123."
  }
}

variable "environment_name" {
  description = "Short environment name, used as a prefix of service account display names because service accounts are organization wide."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.environment_name))
    error_message = "environment_name must be 2 to 16 lowercase letters or digits, starting with a letter (for example dev or prod)."
  }
}

variable "teams_dir" {
  description = "Directory that holds the team folders, relative to this terraform directory."
  type        = string
  default     = "../teams"
}

variable "default_partitions" {
  description = "Partitions of a topic whose file does not set partitions."
  type        = number
  default     = 3

  validation {
    condition     = var.default_partitions >= 1 && floor(var.default_partitions) == var.default_partitions
    error_message = "default_partitions must be a whole number of at least 1."
  }
}

variable "owner" {
  description = "When true, write the team name and its owner_email (from team.yaml) as owner metadata (Stream Catalog owner and ownerEmail) on every topic. Requires Stream Governance."
  type        = bool
  default     = false
}

# Existing admin credentials. Terraform uses them to manage topics, schemas
# and catalog metadata; this configuration never creates them. Pass them as
# environment variables (TF_VAR_kafka_api_key, ...), not in a tfvars file.

variable "kafka_api_key" {
  description = "Existing Kafka API key allowed to manage topics on the cluster, for example owned by a service account with CloudClusterAdmin."
  type        = string
  sensitive   = true
}

variable "kafka_api_secret" {
  description = "Secret of kafka_api_key."
  type        = string
  sensitive   = true
}

variable "schema_registry_api_key" {
  description = "Existing Schema Registry API key allowed to manage subjects, and catalog metadata when owner is true."
  type        = string
  sensitive   = true
}

variable "schema_registry_api_secret" {
  description = "Secret of schema_registry_api_key."
  type        = string
  sensitive   = true
}
