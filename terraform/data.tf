data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# use whatever default vpc the account already has
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# subnet the source lands in. we read its az so the flow doesn't churn when the box is replaced
data "aws_subnet" "chosen" {
  id = data.aws_subnets.default.ids[0]
}

# ubuntu 22.04 ami from the public ssm param so this isn't pinned to one region
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

locals {
  prefix     = var.name_prefix
  account_id = data.aws_caller_identity.current.account_id
  # bucket names are global so stick the account id on the end
  player_bucket = "${var.name_prefix}-player-${data.aws_caller_identity.current.account_id}"
}
