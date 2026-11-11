# One service account per teams/<team>/service-accounts/<name>.yaml file,
# with a Kafka API key, and a Schema Registry API key when it uses schemas.

resource "confluent_service_account" "this" {
  for_each = local.service_accounts

  display_name = each.value.display_name
  description  = each.value.description != "" ? each.value.description : "Service account ${each.key}. Managed by Terraform."

  depends_on = [terraform_data.validation]
}

resource "confluent_api_key" "kafka" {
  for_each = local.service_accounts

  display_name = "${each.value.display_name}-kafka"
  description  = "Kafka API key of ${each.value.display_name}. Managed by Terraform."

  owner {
    id          = confluent_service_account.this[each.key].id
    api_version = confluent_service_account.this[each.key].api_version
    kind        = confluent_service_account.this[each.key].kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.this.id
    api_version = data.confluent_kafka_cluster.this.api_version
    kind        = data.confluent_kafka_cluster.this.kind

    environment {
      id = data.confluent_environment.this.id
    }
  }
}

resource "confluent_api_key" "schema_registry" {
  for_each = { for key, sa in local.service_accounts : key => sa if length(local.service_account_subjects[key]) > 0 }

  display_name = "${each.value.display_name}-schema-registry"
  description  = "Schema Registry API key of ${each.value.display_name}. Managed by Terraform."

  owner {
    id          = confluent_service_account.this[each.key].id
    api_version = confluent_service_account.this[each.key].api_version
    kind        = confluent_service_account.this[each.key].kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.this.id
    api_version = data.confluent_schema_registry_cluster.this.api_version
    kind        = data.confluent_schema_registry_cluster.this.kind

    environment {
      id = data.confluent_environment.this.id
    }
  }
}
