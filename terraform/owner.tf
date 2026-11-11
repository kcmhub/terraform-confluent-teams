# Optional owner metadata (owner = true).
#
# Sets the built in "owner" (team name) and "ownerEmail" (owner_email of
# team.yaml) attributes of each topic in the Stream Catalog, where Confluent
# Cloud shows them and makes them searchable. Requires Stream Governance on
# the environment, and the Schema Registry API key must be allowed to edit
# catalog metadata (for example DataSteward on the environment).

resource "confluent_catalog_entity_attributes" "topic_owner" {
  for_each = { for name, topic in local.topics : name => topic.team if var.owner }

  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.this.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.this.rest_endpoint

  entity_name = "${data.confluent_kafka_cluster.this.id}:${confluent_kafka_topic.this[each.key].topic_name}"
  entity_type = "kafka_topic"
  attributes = {
    "owner"      = each.value
    "ownerEmail" = local.teams[each.value].owner_email
  }

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }
}
