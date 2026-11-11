# Loads the team folders. One file per resource:
#
#   teams/<team>/team.yaml                       team description and owner_email
#   teams/<team>/topics/<topic>.yaml             one topic, the file name is the topic name
#   teams/<team>/service-accounts/<name>.yaml    one application and the access it needs
#   teams/<team>/schemas/<subject>.yaml          one subject, schema in <subject>.avsc or .json
#
# Every value is read defensively (try) so that a broken file never stops the
# loading: problems are reported all at once by validation.tf.

locals {
  # Paths shown in error messages, relative to the repository root by default
  display_dir = trimsuffix(trimprefix(var.teams_dir, "../"), "/")

  team_files            = fileset(var.teams_dir, "*/team.yaml")
  topic_files           = fileset(var.teams_dir, "*/topics/*.yaml")
  service_account_files = fileset(var.teams_dir, "*/service-accounts/*.yaml")
  schema_files          = fileset(var.teams_dir, "*/schemas/*.yaml")

  known_files   = setunion(local.team_files, local.topic_files, local.service_account_files, local.schema_files)
  unknown_files = setsubtract(fileset(var.teams_dir, "**/*.{yaml,yml}"), local.known_files)

  # Decoded content of each file. An empty file decodes to null, a file that
  # is not valid YAML to the string "invalid".
  decoded = {
    for f in local.known_files : f => try(yamldecode(file("${var.teams_dir}/${f}")), "invalid")
  }

  teams = {
    for f in local.team_files : split("/", f)[0] => {
      file        = "${local.display_dir}/${f}"
      description = try(tostring(local.decoded[f].description), "")
      owner_email = try(tostring(local.decoded[f].owner_email), "")
    }
  }

  topic_list = [
    for f in local.topic_files : {
      file           = "${local.display_dir}/${f}"
      team           = split("/", f)[0]
      name           = trimsuffix(basename(f), ".yaml")
      raw_partitions = try(local.decoded[f].partitions, null)
      partitions     = coalesce(try(tonumber(local.decoded[f].partitions), null), var.default_partitions)
      config_valid   = can({ for k, v in local.decoded[f].config : k => tostring(v) }) || try(local.decoded[f].config, null) == null
      config         = try({ for k, v in local.decoded[f].config : k => tostring(v) }, {})
    }
  ]

  service_account_list = [
    for f in local.service_account_files : {
      file                  = "${local.display_dir}/${f}"
      team                  = split("/", f)[0]
      name                  = trimsuffix(basename(f), ".yaml")
      key                   = "${split("/", f)[0]}.${trimsuffix(basename(f), ".yaml")}"
      display_name          = "${var.environment_name}-${split("/", f)[0]}-${trimsuffix(basename(f), ".yaml")}"
      description           = try(tostring(local.decoded[f].description), "")
      produces_valid        = can([for t in local.decoded[f].produces : tostring(t)]) || try(local.decoded[f].produces, null) == null
      consumes_valid        = can([for t in local.decoded[f].consumes : tostring(t)]) || try(local.decoded[f].consumes, null) == null
      produces              = distinct(try([for t in local.decoded[f].produces : tostring(t)], []))
      consumes              = distinct(try([for t in local.decoded[f].consumes : tostring(t)], []))
      consumer_group_prefix = try(tostring(local.decoded[f].consumer_group_prefix), "${split("/", f)[0]}.${trimsuffix(basename(f), ".yaml")}")
    }
  ]

  schema_list = [
    for f in local.schema_files : {
      file          = "${local.display_dir}/${f}"
      team          = split("/", f)[0]
      subject       = trimsuffix(basename(f), ".yaml")
      topic         = try(regex("^(.+)-(?:key|value)$", trimsuffix(basename(f), ".yaml"))[0], "")
      format        = upper(try(tostring(local.decoded[f].format), ""))
      compatibility = try(tostring(local.decoded[f].compatibility), "BACKWARD")
      schema_file   = "${split("/", f)[0]}/schemas/${trimsuffix(basename(f), ".yaml")}.${upper(try(tostring(local.decoded[f].format), "")) == "JSON" ? "json" : "avsc"}"
    }
  ]

  # Resources are keyed by name. Duplicates are grouped (and reported by
  # validation.tf) instead of failing with a duplicate key error.
  topics_by_name           = { for t in local.topic_list : t.name => t... }
  service_accounts_by_key  = { for s in local.service_account_list : s.key => s... }
  service_accounts_by_name = { for s in local.service_account_list : s.display_name => s... }
  schemas_by_subject       = { for s in local.schema_list : s.subject => s... }

  topics           = { for name, list in local.topics_by_name : name => list[0] }
  service_accounts = { for key, list in local.service_accounts_by_key : key => list[0] }
  schemas          = { for subject, list in local.schemas_by_subject : subject => list[0] }

  # Subjects a service account can read: the schemas of the topics it
  # produces to or consumes from.
  service_account_subjects = {
    for key, sa in local.service_accounts : key => [
      for subject, schema in local.schemas : subject
      if contains(concat(sa.produces, sa.consumes), schema.topic)
    ]
  }
}
