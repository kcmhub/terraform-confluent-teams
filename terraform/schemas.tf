# One subject per teams/<team>/schemas/<subject>.yaml file. The schema is
# read from <subject>.avsc (AVRO) or <subject>.json (JSON) next to it.

# The compatibility level is set before the first registration so that every
# version of the schema, including the first one, is checked against it.
resource "confluent_subject_config" "this" {
  for_each = local.schemas

  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.this.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.this.rest_endpoint

  subject_name        = each.key
  compatibility_level = each.value.compatibility

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }

  depends_on = [terraform_data.validation]
}

resource "confluent_schema" "this" {
  for_each = local.schemas

  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.this.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.this.rest_endpoint

  subject_name = confluent_subject_config.this[each.key].subject_name
  format       = each.value.format
  schema       = file("${var.teams_dir}/${each.value.schema_file}")

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }
}
