#!/usr/bin/env bash
# stops the stream (channel, flow, source box) but leaves everything provisioned.
# medialive is where the money goes so this is enough to stop the bleeding. resume with create-channel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
REGION="${TF_VAR_region:-${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-1}}}"
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

cd "$TF_DIR"
CHANNEL_ID="$(terraform output -raw channel_id)"
FLOW_ARN="$(terraform output -raw flow_arn)"
INSTANCE_ID="$(terraform output -raw instance_id)"

echo "==> stopping MediaLive channel"
CSTATE="$(aws medialive describe-channel --channel-id "$CHANNEL_ID" --query 'State' --output text 2>/dev/null || echo NONE)"
if [ "$CSTATE" = "RUNNING" ] || [ "$CSTATE" = "STARTING" ]; then
  aws medialive stop-channel --channel-id "$CHANNEL_ID" >/dev/null
fi

echo "==> stopping MediaConnect flow"
FSTATE="$(aws mediaconnect describe-flow --flow-arn "$FLOW_ARN" --query 'Flow.Status' --output text 2>/dev/null || echo NONE)"
if [ "$FSTATE" = "ACTIVE" ] || [ "$FSTATE" = "STARTING" ]; then
  aws mediaconnect stop-flow --flow-arn "$FLOW_ARN" >/dev/null
fi

echo "==> stopping source EC2"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" >/dev/null || true

echo "stream stopped. infra remains (note: the Elastic IP still bills ~\$0.005/hr)."
echo "resume: ./scripts/create-channel.sh   |   remove everything: ./scripts/destroy-channel.sh"
