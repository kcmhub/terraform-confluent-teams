# Access declared in each service account file, as Confluent Cloud RBAC role
# bindings on literal resources:
#   produces              DeveloperWrite on each topic
#   consumes              DeveloperRead on each topic, and on the consumer group prefix
#   schemas of the topics DeveloperRead on each subject

locals {
  role_bindings = merge([
    for key, sa in local.service_accounts : merge(
      {
        for topic in sa.produces : "${key}/DeveloperWrite/topic=${topic}" => {
          service_account = key
          role_name       = "DeveloperWrite"
          crn_pattern     = "${local.kafka_crn}/topic=${topic}"
        }
      },
      {
        for topic in sa.consumes : "${key}/DeveloperRead/topic=${topic}" => {
          service_account = key
          role_name       = "DeveloperRead"
          crn_pattern     = "${local.kafka_crn}/topic=${topic}"
        }
      },
      {
        for prefix in(length(sa.consumes) > 0 ? [sa.consumer_group_prefix] : []) : "${key}/DeveloperRead/group=${prefix}*" => {
          service_account = key
          role_name       = "DeveloperRead"
          crn_pattern     = "${local.kafka_crn}/group=${prefix}*"
        }
      },
      {
        for subject in local.service_account_subjects[key] : "${key}/DeveloperRead/subject=${subject}" => {
          service_account = key
          role_name       = "DeveloperRead"
          crn_pattern     = "${local.schema_registry_crn}/subject=${subject}"
        }
      },
    )
  ]...)
}

resource "confluent_role_binding" "this" {
  for_each = local.role_bindings

  principal   = "User:${confluent_service_account.this[each.value.service_account].id}"
  role_name   = each.value.role_name
  crn_pattern = each.value.crn_pattern
}
