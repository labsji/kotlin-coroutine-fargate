#!/bin/bash
set -e
CPU="${1:-512}"
MEMORY="${2:-1024}"
REGION="${AWS_REGION:-ap-south-1}"
CLUSTER="coroutine-lab"
SERVICE="coroutine-lab-svc"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/coroutine-lab"

echo "=== Deploying to Fargate: ${CPU} CPU / ${MEMORY} MB ==="

# Build and push to ECR
aws ecr create-repository --repository-name coroutine-lab --region "$REGION" 2>/dev/null || true
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPO_URI"
./gradlew shadowJar -q
docker build -t coroutine-lab .
docker tag coroutine-lab:latest "$REPO_URI:latest"
docker push "$REPO_URI:latest"

# Create cluster
aws ecs create-cluster --cluster-name "$CLUSTER" --region "$REGION" 2>/dev/null || true

# Task definition
TASK_DEF=$(cat << EOF
{
  "family": "coroutine-lab",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "$CPU",
  "memory": "$MEMORY",
  "executionRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "app",
    "image": "${REPO_URI}:latest",
    "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {"awslogs-group": "/ecs/coroutine-lab", "awslogs-region": "$REGION", "awslogs-stream-prefix": "app"}
    }
  }]
}
EOF
)
aws logs create-log-group --log-group-name /ecs/coroutine-lab --region "$REGION" 2>/dev/null || true
aws ecs register-task-definition --cli-input-json "$TASK_DEF" --region "$REGION" > /dev/null

echo "Task registered: ${CPU} CPU / ${MEMORY} MB"

# Auto-discover default VPC networking
SUBNET=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=default-for-az,Values=true" --query 'Subnets[0].SubnetId' --output text)
VPC_ID=$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "$SUBNET" --query 'Subnets[0].VpcId' --output text)
SG=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)

# Open port 8080
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$REGION" 2>/dev/null || true

# Create or update service
if aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
  aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --task-definition coroutine-lab --force-new-deployment --region "$REGION" > /dev/null
else
  aws ecs create-service --cluster "$CLUSTER" --service-name "$SERVICE" --task-definition coroutine-lab \
    --desired-count 1 --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=ENABLED}" \
    --region "$REGION" > /dev/null
fi

echo "Waiting for task to start..."
sleep 30

# Get public IP
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --region "$REGION" --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

echo ""
echo "=== Fargate deployed: ${CPU} CPU / ${MEMORY} MB ==="
echo ""
echo "  URL: http://${PUBLIC_IP}:8080"
echo "  Test: curl http://${PUBLIC_IP}:8080/lab/1"
echo "  Metrics: curl http://${PUBLIC_IP}:8080/metrics"
