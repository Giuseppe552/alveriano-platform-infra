provider "aws" {
  region = "eu-west-2"

  # These tags will automatically be applied to almost every AWS resource.
  default_tags {
    tags = {
      Project = "AlverianoPlatform"
      Owner   = "Giuseppe"
      Managed = "Terraform"
    }
  }
}

# Used to package the alveriano-platform-api build output into a ZIP file
# that Lambda can run.
provider "archive" {}
