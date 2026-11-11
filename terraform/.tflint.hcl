# TFLint configuration, used locally and in CI:
#   tflint --init
#   tflint   (from the terraform directory)
config {
  format = "compact"
}

plugin "terraform" {
  enabled = true
  version = "0.17.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"

  # "all" enables every rule of the ruleset, including documented variables
  # and outputs, typed variables, naming conventions and the standard module
  # structure (main.tf, variables.tf, outputs.tf).
  preset = "all"
}
