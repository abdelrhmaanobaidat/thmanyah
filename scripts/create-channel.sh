#!/usr/bin/env bash
# brings the whole stack up, starts the stream, prints the url.
# safe to run again, it just resumes a stopped stream.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
REGION="${TF_VAR_region:-${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-1}}}"
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

echo "==> region: $REGION"
if ! aws medialive list-input-security-groups >/dev/null 2>&1; then
  echo "ERROR: MediaLive not reachable in '$REGION'. Use an AWS Elemental + MediaPackage v2 region" >&2
  echo "       (e.g. eu-west-1, us-east-1, us-west-2) and valid AWS credentials." >&2
  exit 1
fi

cd "$TF_DIR"
echo "==> terraform init"
terraform init -input=false >/dev/null
echo "==> terraform apply  (first run blocks ~15-20 min on CloudFront deployment)"
terraform apply -auto-approve

CHANNEL_ID="$(terraform output -raw channel_id)"
FLOW_ARN="$(terraform output -raw flow_arn)"
INSTANCE_ID="$(terraform output -raw instance_id)"
PLAYER_URL="$(terraform output -raw player_url)"

echo "==> ensuring source EC2 is running ($INSTANCE_ID)"
STATE="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text)"
if [ "$STATE" != "running" ]; then
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
fi
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "    waiting for the source encoder to settle..."
sleep 25

echo "==> starting MediaConnect flow"
if [ "$(aws mediaconnect describe-flow --flow-arn "$FLOW_ARN" --query 'Flow.Status' --output text)" = "STANDBY" ]; then
  aws mediaconnect start-flow --flow-arn "$FLOW_ARN" >/dev/null
fi
for _ in $(seq 1 30); do
  [ "$(aws mediaconnect describe-flow --flow-arn "$FLOW_ARN" --query 'Flow.Status' --output text)" = "ACTIVE" ] && break
  sleep 4
done

echo "==> starting MediaLive channel"
if [ "$(aws medialive describe-channel --channel-id "$CHANNEL_ID" --query 'State' --output text)" = "IDLE" ]; then
  aws medialive start-channel --channel-id "$CHANNEL_ID" >/dev/null
fi

echo ""
echo "    ▶ open this:  $PLAYER_URL"
echo "    give it 30-60s after the channel is RUNNING, then refresh if it's still blank."
echo "    pause cost:  ./scripts/stop-channel.sh      tear down: ./scripts/destroy-channel.sh"
