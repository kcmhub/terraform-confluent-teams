# Existing infrastructure, referenced by ID. This configuration never creates
# or changes environments, clusters or networks.

data "confluent_environment" "this" {
  id = var.environment_id
}

data "confluent_kafka_cluster" "this" {
  id = var.kafka_cluster_id

  environment {
    id = data.confluent_environment.this.id
  }
}

data "confluent_schema_registry_cluster" "this" {
  environment {
    id = data.confluent_environment.this.id
  }
}

locals {
  # CRN prefixes used by the role bindings in rbac.tf
  kafka_crn           = "${data.confluent_kafka_cluster.this.rbac_crn}/kafka=${data.confluent_kafka_cluster.this.id}"
  schema_registry_crn = data.confluent_schema_registry_cluster.this.resource_name
}
