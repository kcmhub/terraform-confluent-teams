# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- S3 backend with native locking, one state file per environment, and `terraform/example.s3.tfbackend`.
- GitHub Actions workflow `terraform.yml`: plan `dev` and `prod` on pull requests, apply `dev` then `prod` after an approval on merge to `main`. Settings come from GitHub variables and secrets, AWS access uses OpenID Connect.

### Changed

- Terraform 1.10 or later is required, for S3 native locking.

## [0.1.0] - 2026-11-11

### Added

- Team folders with one YAML file per resource: `team.yaml`, `topics/<topic>.yaml`, `service-accounts/<name>.yaml` (with the access the application needs) and `schemas/<subject>.yaml` next to the schema file.
- Terraform configuration in `terraform/` that loads the team folders and creates topics, service accounts with Kafka and Schema Registry API keys, RBAC role bindings and schemas with their compatibility level, on an existing Confluent Cloud cluster.
- Validation of the team files before anything is planned, with messages naming the file at fault: layout, YAML syntax, unknown settings, naming conventions, unique names, references to topics that do not exist, producers writing to another team's topics, consumer group prefixes, schema formats, compatibility levels and schema files.
- Optional `owner` flag that writes each team and its `owner_email` as Stream Catalog owner metadata on its topics.
- Example teams `payments` and `orders`.
- Offline `terraform test` suite for the validation, with a mocked provider.
- CI: fmt, init, validate, test and tflint.
