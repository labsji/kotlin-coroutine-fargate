#!/bin/bash
# teardown-multi.sh — Remove all multi-config Fargate services
set -e
REGION="${AWS_REGION:-ap-south-1}"
CLUSTER="coroutine-lab"

echo "=== Tearing down multi-config deployment ==="
for SVC in $(aws ecs list-services --cluster "$CLUSTER" --region "$REGION" --query 'serviceArns[*]' --output text 2>/dev/null); do
  SVC_NAME=$(basename "$SVC")
  aws ecs update-service --cluster "$CLUSTER" --service "$SVC_NAME" --desired-count 0 --region "$REGION" > /dev/null 2>&1
  aws ecs delete-service --cluster "$CLUSTER" --service "$SVC_NAME" --force --region "$REGION" > /dev/null 2>&1
  echo "  Deleted: $SVC_NAME"
done
echo "=== Done. Services deleted, tasks draining. ==="
