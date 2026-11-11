output "topics" {
  description = "Topics with their team and partitions."
  value = {
    for name, topic in confluent_kafka_topic.this : name => {
      team       = local.topics[name].team
      partitions = topic.partitions_count
    }
  }
}

output "service_accounts" {
  description = "Service accounts by <team>.<name>, with their display name, ID and principal."
  value = {
    for key, sa in confluent_service_account.this : key => {
      display_name = sa.display_name
      id           = sa.id
      principal    = "User:${sa.id}"
    }
  }
}

output "role_bindings" {
  description = "Role bindings by service account: role and CRN pattern."
  value = {
    for key in keys(local.service_accounts) : key => [
      for binding_key, binding in confluent_role_binding.this : "${binding.role_name} ${binding.crn_pattern}"
      if local.role_bindings[binding_key].service_account == key
    ]
  }
}

output "schemas" {
  description = "Registered subjects with their version and schema ID."
  value = {
    for subject, schema in confluent_schema.this : subject => {
      version   = schema.version
      schema_id = schema.schema_identifier
    }
  }
}

output "connection" {
  description = "Endpoints the applications connect to."
  value = {
    bootstrap_servers   = data.confluent_kafka_cluster.this.bootstrap_endpoint
    schema_registry_url = data.confluent_schema_registry_cluster.this.rest_endpoint
  }
}

output "client_credentials" {
  description = "API keys by service account. Read them with: terraform output -json client_credentials"
  sensitive   = true
  value = {
    for key in keys(local.service_accounts) : key => {
      kafka_api_key              = confluent_api_key.kafka[key].id
      kafka_api_secret           = confluent_api_key.kafka[key].secret
      schema_registry_api_key    = try(confluent_api_key.schema_registry[key].id, null)
      schema_registry_api_secret = try(confluent_api_key.schema_registry[key].secret, null)
    }
  }
}
