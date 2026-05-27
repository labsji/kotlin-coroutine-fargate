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
echo "Create/update service with:"
echo "  aws ecs create-service --cluster $CLUSTER --service-name $SERVICE --task-definition coroutine-lab --desired-count 1 --launch-type FARGATE --network-configuration 'awsvpcConfiguration={subnets=[<subnet>],securityGroups=[<sg>],assignPublicIp=ENABLED}' --region $REGION"
