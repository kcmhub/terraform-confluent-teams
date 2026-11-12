# terraform-confluent-teams

[![ci](https://github.com/kcmhub/terraform-confluent-teams/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kcmhub/terraform-confluent-teams/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/kcmhub/terraform-confluent-teams)](LICENSE)

Manage the Kafka resources of several teams on an **existing** Confluent Cloud cluster from small YAML files, one file per resource, with the official [`confluentinc/confluent`](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs) Terraform provider.

Each team owns a folder. Adding a topic, an application or a schema is a pull request that adds one file, and the files are validated before Terraform plans anything.

```
teams/
  payments/
    team.yaml                                       description, owner_email
    topics/
      payments.payment.authorized.yaml              one topic: the file name is the topic name
      payments.payment.settled.yaml
    service-accounts/
      payments-api.yaml                             one application and the access it needs
      payments-settlement.yaml
    schemas/
      payments.payment.authorized-value.yaml        one subject: format and compatibility
      payments.payment.authorized-value.avsc        the schema itself
      payments.payment.settled-value.yaml
      payments.payment.settled-value.json
  orders/
    ...
terraform/                                          the Terraform configuration that reads teams/
```

Environments, clusters, networks and Schema Registry are not managed here: they are read with data sources from their IDs.

## The files

`teams/<team>/team.yaml`

```yaml
description: Payment authorization and settlement
owner_email: payments-team@example.com   # required, used by owner = true
```

`teams/<team>/topics/<topic>.yaml`: the topic name must start with `<team>.`

```yaml
partitions: 6            # optional, default_partitions otherwise
config:                  # optional, any topic setting
  cleanup.policy: delete
  retention.ms: 604800000
```

`teams/<team>/service-accounts/<name>.yaml`: the application declares its own access, so every permission has an owner and a reason in git.

```yaml
description: Authorizes payments for new orders
produces:                        # topics of this team
  - payments.payment.authorized
consumes:                        # topics of any team
  - orders.order.created
consumer_group_prefix: payments.api   # optional, default <team>.<name>
```

It becomes the service account `<environment_name>-<team>-<name>` with:

- a Kafka API key, `DeveloperWrite` on each produced topic, `DeveloperRead` on each consumed topic and on the consumer group prefix,
- a Schema Registry API key and `DeveloperRead` on the subjects of those topics, when they have a schema.

`teams/<team>/schemas/<subject>.yaml`: the subject is `<topic>-value` or `<topic>-key` for a topic of the team, and the schema is in `<subject>.avsc` (Avro) or `<subject>.json` (JSON Schema) next to it.

```yaml
format: AVRO             # AVRO or JSON
compatibility: BACKWARD  # optional, BACKWARD by default
```

## Validation

Before planning any Confluent resource, Terraform checks every team file and reports all problems at once, each one prefixed with the file at fault:

```
Error: Resource precondition failed
The team files have 2 problem(s):
- teams/orders/topics/orders.order.created.yaml: unknown setting(s) partition. Allowed: partitions, config.
- teams/orders/service-accounts/orders-api.yaml: consumes from topic "payments.payment.setled", which is not defined in any <team>/topics/ folder.
```

The rules:

- layout: only the four kinds of files above, valid YAML, no unknown setting (typos are errors, not silently ignored);
- naming: team folders, topic names starting with `<team>.`, service account names, subjects named `<topic>-value` or `<topic>-key`;
- uniqueness: topic names and service account display names;
- references: produced and consumed topics must exist, a team only produces to its own topics, a schema must belong to a topic of its team, consumer group prefixes start with `<team>.`;
- values: `owner_email` is an email address, partitions is a whole number of at least 1, `config` is a mapping, schema format and compatibility level are known values, the schema file exists and is valid JSON.

Validation runs offline and is covered by `terraform test` with a mocked provider (`terraform/tests`).

## Usage

Prerequisites:

- Terraform 1.7 or later.
- A Confluent Cloud environment with Stream Governance (Schema Registry) and a Kafka cluster that supports RBAC on topics (Standard, Enterprise or Dedicated, not Basic).
- A **Cloud API key** allowed to create service accounts, API keys and role bindings, for example owned by a service account with `OrganizationAdmin`.
- An existing **admin Kafka API key** and **admin Schema Registry API key** that Terraform uses to manage topics and schemas, for example owned by a `terraform-admin` service account with `CloudClusterAdmin` on the cluster and `ResourceOwner` on all subjects:

```bash
confluent iam service-account create terraform-admin --description "Manages topics and schemas with Terraform"
confluent iam rbac role-binding create --principal User:<sa-id> --role CloudClusterAdmin --environment <env-id> --cloud-cluster <lkc-id>
confluent iam rbac role-binding create --principal User:<sa-id> --role ResourceOwner --environment <env-id> --schema-registry-cluster <lsrc-id> --resource "Subject:*"
confluent api-key create --service-account <sa-id> --resource <lkc-id>
confluent api-key create --service-account <sa-id> --resource <lsrc-id>
```

Then:

```bash
cd terraform

export CONFLUENT_CLOUD_API_KEY="<cloud api key>"
export CONFLUENT_CLOUD_API_SECRET="<cloud api secret>"
export TF_VAR_kafka_api_key="<kafka api key>"
export TF_VAR_kafka_api_secret="<kafka api secret>"
export TF_VAR_schema_registry_api_key="<schema registry api key>"
export TF_VAR_schema_registry_api_secret="<schema registry api secret>"

cp example.tfvars dev.tfvars   # then replace env-replaceme and lkc-replaceme
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars

terraform output -json client_credentials   # API keys of each application
```

Things to know:

- **Removing a topic file deletes the topic and its data.** Renaming a topic file does the same and creates a new, empty topic. Always read the plan before applying and look for `destroy` on `confluent_kafka_topic`. If you prefer the plan to fail instead, add `lifecycle { prevent_destroy = true }` to the topic resource in `terraform/topics.tf`.
- Renaming a service account file creates a new service account and new API keys.
- The admin keys are passed in rather than created by Terraform, so the configuration has no bootstrap step and the same keys can be rotated outside of it.

## State

The state holds the secrets of every API key Terraform creates. Never commit it (`.gitignore` excludes it), keep it in a remote backend with encryption and restricted access, and use **one state per environment**.

No backend is configured, so out of the box Terraform writes a local `terraform/terraform.tfstate`. To use a remote backend, declare its type in `terraform/backend.tf` and keep its settings in one file per environment. For example with S3:

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {}
}
```

```hcl
# terraform/dev.s3.tfbackend
bucket       = "my-terraform-states"
key          = "confluent/teams/dev.tfstate"
region       = "eu-west-1"
encrypt      = true
use_lockfile = true # Terraform 1.10 or later
```

```bash
terraform init -reconfigure -backend-config=dev.s3.tfbackend
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

The same pattern works with the `azurerm` and `gcs` backends: only the settings change.

**Switching environment means switching state.** Run `terraform init -reconfigure -backend-config=<env>.s3.tfbackend` before using `<env>.tfvars`. Applying `prod.tfvars` with the dev state would replace the dev resources with the prod ones, deleting the dev topics and their data.

## Owner metadata (`owner = true`)

With `owner = true`, every topic gets the Stream Catalog attributes `owner` (the team folder name) and `ownerEmail` (from `team.yaml`), set with [`confluent_catalog_entity_attributes`](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_catalog_entity_attributes). These are the built in owner fields of a topic in Confluent Cloud: they are shown with the topic metadata in the Cloud Console and can be searched in the Stream Catalog.

Limits:

- Topics only. Service accounts and API keys have no owner field, only a description. Schemas are catalog entities too, but they are addressed by their numeric schema ID and owner attributes on them are not covered here.
- Stream Governance must be enabled on the environment, and the Schema Registry API key must be allowed to edit catalog metadata (for example `DataSteward` on the environment).
- A new topic can take a little time to appear in the catalog. If the first apply fails on `confluent_catalog_entity_attributes`, run apply again.
- Switching `owner` back to `false` removes the resources from Terraform; check in the Console that the attributes were cleared.

## See these resources in KCM

Once applied, the topics, service accounts, role bindings and schemas are ordinary Confluent Cloud resources. [KCM](https://kcmhub.io) shows them team by team, lets you check with its RBAC analyzer that the access in the cluster matches what the service account files declare, and helps operate them day to day while the team folders stay the source of truth.

## License

[Apache License 2.0](LICENSE).
