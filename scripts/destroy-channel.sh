#!/usr/bin/env bash
# stop the stream, wait for it to settle, then tear the whole thing down
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
REGION="${TF_VAR_region:-${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-1}}}"
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

cd "$TF_DIR"
CHANNEL_ID="$(terraform output -raw channel_id 2>/dev/null || echo '')"
FLOW_ARN="$(terraform output -raw flow_arn 2>/dev/null || echo '')"

if [ -n "$CHANNEL_ID" ]; then
  echo "==> stopping MediaLive channel and waiting for IDLE (required before delete)"
  CSTATE="$(aws medialive describe-channel --channel-id "$CHANNEL_ID" --query 'State' --output text 2>/dev/null || echo NONE)"
  if [ "$CSTATE" = "RUNNING" ] || [ "$CSTATE" = "STARTING" ]; then
    aws medialive stop-channel --channel-id "$CHANNEL_ID" >/dev/null || true
  fi
  for _ in $(seq 1 60); do
    S="$(aws medialive describe-channel --channel-id "$CHANNEL_ID" --query 'State' --output text 2>/dev/null || echo IDLE)"
    [ "$S" = "IDLE" ] && break
    sleep 5
  done
fi

if [ -n "$FLOW_ARN" ]; then
  echo "==> stopping MediaConnect flow and waiting for STANDBY"
  FSTATE="$(aws mediaconnect describe-flow --flow-arn "$FLOW_ARN" --query 'Flow.Status' --output text 2>/dev/null || echo NONE)"
  if [ "$FSTATE" = "ACTIVE" ] || [ "$FSTATE" = "STARTING" ]; then
    aws mediaconnect stop-flow --flow-arn "$FLOW_ARN" >/dev/null || true
  fi
  for _ in $(seq 1 60); do
    S="$(aws mediaconnect describe-flow --flow-arn "$FLOW_ARN" --query 'Flow.Status' --output text 2>/dev/null || echo STANDBY)"
    [ "$S" = "STANDBY" ] && break
    sleep 4
  done
fi

echo "==> terraform destroy"
terraform destroy -auto-approve
echo "done. everything removed."
