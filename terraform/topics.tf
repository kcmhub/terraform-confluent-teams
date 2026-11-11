# One topic per teams/<team>/topics/<topic>.yaml file.

resource "confluent_kafka_topic" "this" {
  for_each = local.topics

  kafka_cluster {
    id = data.confluent_kafka_cluster.this.id
  }
  rest_endpoint = data.confluent_kafka_cluster.this.rest_endpoint

  topic_name       = each.key
  partitions_count = each.value.partitions
  config           = each.value.config

  credentials {
    key    = var.kafka_api_key
    secret = var.kafka_api_secret
  }

  lifecycle {
    # Removing a topic file must not delete the topic and its data by
    # accident: the plan fails instead. See the README to delete on purpose.
    prevent_destroy = true
  }

  depends_on = [terraform_data.validation]
}
