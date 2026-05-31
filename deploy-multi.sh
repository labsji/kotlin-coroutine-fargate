#!/bin/bash
# deploy-multi.sh — Deploy coroutine-lab to multiple Fargate configs in parallel + viz UI
set -e
REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER="coroutine-lab"
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/coroutine-lab"
CONFIGS=("256:512" "512:1024" "1024:2048")

echo "=== Deploying Multi-Config Coroutine Lab ==="

# Build and push once
export GRADLE_USER_HOME=/tmp/.gradle
./gradlew shadowJar --no-daemon -q
aws ecr create-repository --repository-name coroutine-lab --region "$REGION" 2>/dev/null || true
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPO_URI" 2>/dev/null
docker build -t coroutine-lab . 2>/dev/null
docker tag coroutine-lab:latest "$REPO_URI:latest"
docker push "$REPO_URI:latest" 2>/dev/null

# Network setup
SUBNET=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=default-for-az,Values=true" --query 'Subnets[0].SubnetId' --output text)
VPC_ID=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET" --query 'Subnets[0].VpcId' --output text)
SG=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$REGION" 2>/dev/null || true

# Cluster
aws ecs create-cluster --cluster-name "$CLUSTER" --region "$REGION" 2>/dev/null || true
aws logs create-log-group --log-group-name /ecs/coroutine-lab --region "$REGION" 2>/dev/null || true

# Deploy each config as a separate service
INSTANCES=()
for CFG in "${CONFIGS[@]}"; do
  CPU="${CFG%%:*}"
  MEM="${CFG##*:}"
  SVC_NAME="coroutine-lab-${CPU}"

  # Register task def with unique family per CPU
  aws ecs register-task-definition --family "coroutine-lab-${CPU}" \
    --network-mode awsvpc --requires-compatibilities FARGATE \
    --cpu "$CPU" --memory "$MEM" \
    --execution-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole" \
    --container-definitions "[{\"name\":\"app\",\"image\":\"${REPO_URI}:latest\",\"portMappings\":[{\"containerPort\":8080}],\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"/ecs/coroutine-lab\",\"awslogs-region\":\"${REGION}\",\"awslogs-stream-prefix\":\"${CPU}\"}}}]" \
    --region "$REGION" > /dev/null

  # Create or update service
  if aws ecs describe-services --cluster "$CLUSTER" --services "$SVC_NAME" --region "$REGION" --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
    aws ecs update-service --cluster "$CLUSTER" --service "$SVC_NAME" --task-definition "coroutine-lab-${CPU}" --force-new-deployment --region "$REGION" > /dev/null
  else
    aws ecs create-service --cluster "$CLUSTER" --service-name "$SVC_NAME" --task-definition "coroutine-lab-${CPU}" \
      --desired-count 1 --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=ENABLED}" \
      --region "$REGION" > /dev/null
  fi
  echo "  Deployed: ${CPU} CPU / ${MEM} MB (service: $SVC_NAME)"
done

echo ""
echo "Waiting 60s for tasks to start..."
sleep 60

# Collect IPs
echo ""
echo "=== Instance IPs ==="
for CFG in "${CONFIGS[@]}"; do
  CPU="${CFG%%:*}"
  MEM="${CFG##*:}"
  SVC_NAME="coroutine-lab-${CPU}"
  TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SVC_NAME" --region "$REGION" --query 'taskArns[0]' --output text 2>/dev/null)
  if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null)
    IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null)
    echo "  ${CPU} CPU: http://${IP}:8080"
    INSTANCES+=("${CPU}:${IP}")
  else
    echo "  ${CPU} CPU: (still starting...)"
  fi
done

# Generate viz config
VIZ_JSON="["
for INST in "${INSTANCES[@]}"; do
  CPU="${INST%%:*}"
  IP="${INST##*:}"
  VIZ_JSON+="{\"label\":\"Fargate ${CPU} CPU\",\"url\":\"http://${IP}:8080\",\"cost\":$(echo "scale=3; $CPU * 0.000012" | bc)},"
done
VIZ_JSON="${VIZ_JSON%,}]"
echo "$VIZ_JSON" > viz-instances.json

echo ""
echo "=== Ready ==="
# Build viz URL with all IPs
IP_LIST=$(printf "%s," "${INSTANCES[@]}" | sed 's/[0-9]*://g' | sed 's/,$//')
FIRST_IP="${INSTANCES[0]##*:}"
echo ""
echo "  Open this URL in your browser:"
echo ""
echo "  http://${FIRST_IP}:8080/viz?i=${IP_LIST}"
echo ""
echo "  Teardown when done: ./teardown-multi.sh"
