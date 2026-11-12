terraform {
  # 1.7 for mock providers in terraform test, 1.10 for S3 native locking
  required_version = ">= 1.10.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.94"
    }
  }
}

# The provider reads the Cloud API key from the environment:
#   export CONFLUENT_CLOUD_API_KEY=...
#   export CONFLUENT_CLOUD_API_SECRET=...
provider "confluent" {}
