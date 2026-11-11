# Validation of the team files. Every rule produces messages that start with
# the file at fault. All problems are reported together by the precondition
# below, and the Confluent resources depend on it, so nothing is planned
# until the team files are valid.

locals {
  allowed_settings = {
    team            = ["description", "owner_email"]
    topic           = ["partitions", "config"]
    service_account = ["description", "produces", "consumes", "consumer_group_prefix"]
    schema          = ["format", "compatibility"]
  }

  file_kinds = merge(
    { for f in local.team_files : f => "team" },
    { for f in local.topic_files : f => "topic" },
    { for f in local.service_account_files : f => "service_account" },
    { for f in local.schema_files : f => "schema" },
  )

  team_names  = distinct([for f in local.known_files : split("/", f)[0]])
  topic_teams = { for name, topic in local.topics : name => topic.team }

  compatibility_levels = ["BACKWARD", "BACKWARD_TRANSITIVE", "FORWARD", "FORWARD_TRANSITIVE", "FULL", "FULL_TRANSITIVE", "NONE"]

  validation_errors = flatten([
    # Layout and syntax
    [
      for f in local.unknown_files :
      "${local.display_dir}/${f}: unexpected file. Expected <team>/team.yaml, <team>/topics/<topic>.yaml, <team>/service-accounts/<name>.yaml or <team>/schemas/<subject>.yaml."
    ],
    [
      for f, kind in local.file_kinds :
      "${local.display_dir}/${f}: not valid YAML, or not a mapping of settings."
      if !(local.decoded[f] == null || can(keys(local.decoded[f])))
    ],
    [
      for f, kind in local.file_kinds :
      "${local.display_dir}/${f}: unknown setting(s) ${join(", ", sort(setsubtract(try(keys(local.decoded[f]), []), local.allowed_settings[kind])))}. Allowed: ${join(", ", local.allowed_settings[kind])}."
      if length(setsubtract(try(keys(local.decoded[f]), []), local.allowed_settings[kind])) > 0
    ],

    # Teams
    [
      for t in local.team_names :
      "${local.display_dir}/${t}: team folder names must be lowercase letters, digits and hyphens, starting with a letter (32 characters at most)."
      if !can(regex("^[a-z][a-z0-9-]{0,31}$", t))
    ],
    [
      for t in local.team_names :
      "${local.display_dir}/${t}/team.yaml: missing. Every team folder needs a team.yaml with at least owner_email."
      if !contains(keys(local.teams), t)
    ],
    [
      for t, team in local.teams :
      "${team.file}: owner_email must be an email address, got \"${team.owner_email}\"."
      if !can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", team.owner_email))
    ],

    # Topics
    [
      for t in local.topic_list :
      "${t.file}: topic name \"${t.name}\" must start with \"${t.team}.\" followed by lowercase letters, digits, dots, underscores or hyphens (249 characters at most)."
      if !can(regex("^${t.team}\\.[a-z0-9][a-z0-9._-]*$", t.name)) || length(t.name) > 249
    ],
    [
      for t in local.topic_list :
      "${t.file}: partitions must be a whole number of at least 1."
      if !(t.raw_partitions == null || try(tonumber(t.raw_partitions) >= 1 && floor(tonumber(t.raw_partitions)) == tonumber(t.raw_partitions), false))
    ],
    [
      for t in local.topic_list :
      "${t.file}: config must be a mapping of topic settings to values, for example cleanup.policy: delete."
      if !t.config_valid
    ],
    [
      for name, list in local.topics_by_name :
      "topic \"${name}\" is defined more than once: ${join(", ", list[*].file)}."
      if length(list) > 1
    ],

    # Service accounts and the access they declare
    [
      for s in local.service_account_list :
      "${s.file}: service account file names must be lowercase letters, digits and hyphens, starting with a letter."
      if !can(regex("^[a-z][a-z0-9-]*$", s.name))
    ],
    [
      for s in local.service_account_list :
      "${s.file}: produces and consumes must be lists of topic names."
      if !s.produces_valid || !s.consumes_valid
    ],
    flatten([
      for s in local.service_account_list : [
        for t in s.produces :
        "${s.file}: produces to topic \"${t}\", which is not defined in any <team>/topics/ folder."
        if !contains(keys(local.topics), t)
      ]
    ]),
    flatten([
      for s in local.service_account_list : [
        for t in s.produces :
        "${s.file}: produces to topic \"${t}\" of team \"${local.topic_teams[t]}\". A team only produces to its own topics."
        if contains(keys(local.topics), t) && try(local.topic_teams[t], s.team) != s.team
      ]
    ]),
    flatten([
      for s in local.service_account_list : [
        for t in s.consumes :
        "${s.file}: consumes from topic \"${t}\", which is not defined in any <team>/topics/ folder."
        if !contains(keys(local.topics), t)
      ]
    ]),
    [
      for s in local.service_account_list :
      "${s.file}: consumer_group_prefix must start with \"${s.team}.\", got \"${s.consumer_group_prefix}\"."
      if !startswith(s.consumer_group_prefix, "${s.team}.")
    ],
    [
      for name, list in local.service_accounts_by_name :
      "service account display name \"${name}\" is used by more than one file: ${join(", ", list[*].file)}."
      if length(list) > 1
    ],

    # Schemas
    [
      for s in local.schema_list :
      "${s.file}: subject \"${s.subject}\" must be named <topic>-value or <topic>-key."
      if s.topic == ""
    ],
    [
      for s in local.schema_list :
      "${s.file}: subject \"${s.subject}\" refers to topic \"${s.topic}\", which is not defined in ${local.display_dir}/${s.team}/topics/."
      if s.topic != "" && try(local.topic_teams[s.topic], "") != s.team
    ],
    [
      for s in local.schema_list :
      "${s.file}: format must be AVRO or JSON, got \"${s.format}\"."
      if !contains(["AVRO", "JSON"], s.format)
    ],
    [
      for s in local.schema_list :
      "${s.file}: compatibility must be one of ${join(", ", local.compatibility_levels)}, got \"${s.compatibility}\"."
      if !contains(local.compatibility_levels, s.compatibility)
    ],
    [
      for s in local.schema_list :
      "${s.file}: schema file ${local.display_dir}/${s.schema_file} is missing or is not valid JSON."
      if contains(["AVRO", "JSON"], s.format) && !can(jsondecode(file("${var.teams_dir}/${s.schema_file}")))
    ],
  ])
}

resource "terraform_data" "validation" {
  lifecycle {
    precondition {
      condition     = length(local.validation_errors) == 0
      error_message = "The team files have ${length(local.validation_errors)} problem(s):\n- ${join("\n- ", local.validation_errors)}"
    }
  }
}
