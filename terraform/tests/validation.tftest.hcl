# Offline tests of the team file loading and validation. The Confluent
# provider is mocked: no credentials, no call to Confluent Cloud.
#
# Each folder under tests/fixtures is valid except for the problem its name
# describes, and must be rejected by terraform_data.validation.

mock_provider "confluent" {
  mock_resource "confluent_service_account" {
    # The provider validates the owner of API keys
    defaults = {
      id          = "sa-mock01"
      api_version = "iam/v2"
      kind        = "ServiceAccount"
    }
  }

  mock_data "confluent_kafka_cluster" {
    defaults = {
      id            = "lkc-mock01"
      api_version   = "cmk/v2"
      kind          = "Cluster"
      rest_endpoint = "https://pkc-mock.region.provider.confluent.cloud:443"
      rbac_crn      = "crn://confluent.cloud/organization=00000000-0000-0000-0000-000000000000/environment=env-mock01/cloud-cluster=lkc-mock01"
    }
  }

  mock_data "confluent_schema_registry_cluster" {
    defaults = {
      id            = "lsrc-mock01"
      api_version   = "srcm/v3"
      kind          = "Cluster"
      rest_endpoint = "https://psrc-mock.region.provider.confluent.cloud"
      resource_name = "crn://confluent.cloud/organization=00000000-0000-0000-0000-000000000000/environment=env-mock01/schema-registry=lsrc-mock01"
    }
  }
}

variables {
  environment_id             = "env-mock01"
  kafka_cluster_id           = "lkc-mock01"
  kafka_api_key              = "mock"
  kafka_api_secret           = "mock"
  schema_registry_api_key    = "mock"
  schema_registry_api_secret = "mock"
}

run "example_teams_are_valid" {
  command = plan

  variables {
    owner = true
  }

  assert {
    condition     = length(local.validation_errors) == 0
    error_message = "The example team files should be valid: ${join("; ", local.validation_errors)}"
  }

  assert {
    condition     = length(confluent_kafka_topic.this) == 4 && length(confluent_service_account.this) == 4 && length(confluent_schema.this) == 4
    error_message = "Expected 4 topics, 4 service accounts and 4 schemas."
  }

  assert {
    condition     = length(confluent_role_binding.this) == 20 && length(confluent_api_key.schema_registry) == 4
    error_message = "Expected 20 role bindings and 4 Schema Registry API keys."
  }

  assert {
    condition     = confluent_kafka_topic.this["payments.payment.settled"].partitions_count == 3 && confluent_kafka_topic.this["payments.payment.authorized"].config["retention.ms"] == "604800000"
    error_message = "Default partitions or topic config not applied."
  }

  assert {
    condition     = confluent_service_account.this["payments.payments-api"].display_name == "dev-payments-payments-api"
    error_message = "Unexpected service account display name."
  }

  assert {
    condition     = local.role_bindings["payments.payments-settlement/DeveloperRead/group=payments.settlement*"].role_name == "DeveloperRead"
    error_message = "Missing consumer group role binding."
  }

  assert {
    condition     = toset(local.service_account_subjects["orders.orders-api"]) == toset(["orders.order.created-value", "orders.order.status-value", "payments.payment.settled-value"])
    error_message = "Unexpected subjects for orders-api."
  }

  assert {
    condition     = confluent_catalog_entity_attributes.topic_owner["orders.order.status"].attributes["ownerEmail"] == "orders-team@example.com"
    error_message = "Owner metadata not set from team.yaml."
  }
}

run "owner_is_off_by_default" {
  command = plan

  assert {
    condition     = length(confluent_catalog_entity_attributes.topic_owner) == 0
    error_message = "No owner metadata expected when owner is false."
  }
}

run "missing_team_file" {
  command = plan
  variables { teams_dir = "tests/fixtures/missing-team-file" }
  expect_failures = [terraform_data.validation]
}

run "unexpected_file" {
  command = plan
  variables { teams_dir = "tests/fixtures/unexpected-file" }
  expect_failures = [terraform_data.validation]
}

run "invalid_owner_email" {
  command = plan
  variables { teams_dir = "tests/fixtures/invalid-owner-email" }
  expect_failures = [terraform_data.validation]
}

run "bad_topic_name" {
  command = plan
  variables { teams_dir = "tests/fixtures/bad-topic-name" }
  expect_failures = [terraform_data.validation]
}

run "bad_partitions" {
  command = plan
  variables { teams_dir = "tests/fixtures/bad-partitions" }
  expect_failures = [terraform_data.validation]
}

run "unknown_setting" {
  command = plan
  variables { teams_dir = "tests/fixtures/unknown-setting" }
  expect_failures = [terraform_data.validation]
}

run "unknown_topic" {
  command = plan
  variables { teams_dir = "tests/fixtures/unknown-topic" }
  expect_failures = [terraform_data.validation]
}

run "foreign_producer" {
  command = plan
  variables { teams_dir = "tests/fixtures/foreign-producer" }
  expect_failures = [terraform_data.validation]
}

run "bad_group_prefix" {
  command = plan
  variables { teams_dir = "tests/fixtures/bad-group-prefix" }
  expect_failures = [terraform_data.validation]
}

run "duplicate_display_name" {
  command = plan
  variables { teams_dir = "tests/fixtures/duplicate-display-name" }
  expect_failures = [terraform_data.validation]
}

run "schema_unknown_topic" {
  command = plan
  variables { teams_dir = "tests/fixtures/schema-unknown-topic" }
  expect_failures = [terraform_data.validation]
}

run "missing_schema_file" {
  command = plan
  variables { teams_dir = "tests/fixtures/missing-schema-file" }
  expect_failures = [terraform_data.validation]
}

run "bad_compatibility" {
  command = plan
  variables { teams_dir = "tests/fixtures/bad-compatibility" }
  expect_failures = [terraform_data.validation]
}
