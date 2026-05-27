#!/bin/bash
set -e
REGION="${AWS_REGION:-ap-south-1}"
APP_NAME="coroutine-lab"

echo "=== Cleaning up Kotlin Coroutine Lab ==="

# Beanstalk
aws elasticbeanstalk terminate-environment --environment-name coroutine-lab-env --region "$REGION" 2>/dev/null && echo "Terminating Beanstalk env" || true
sleep 5
aws elasticbeanstalk delete-application --application-name "$APP_NAME" --terminate-env-by-force --region "$REGION" 2>/dev/null && echo "Deleted Beanstalk app" || true

# Fargate
aws ecs delete-service --cluster coroutine-lab --service coroutine-lab-svc --force --region "$REGION" 2>/dev/null && echo "Deleted Fargate service" || true
aws ecs delete-cluster --cluster coroutine-lab --region "$REGION" 2>/dev/null && echo "Deleted ECS cluster" || true

# ECR
aws ecr delete-repository --repository-name coroutine-lab --force --region "$REGION" 2>/dev/null && echo "Deleted ECR repo" || true

# S3
aws s3 rb "s3://${APP_NAME}-deploy-${REGION}" --force --region "$REGION" 2>/dev/null && echo "Deleted deploy bucket" || true

# Logs
aws logs delete-log-group --log-group-name /ecs/coroutine-lab --region "$REGION" 2>/dev/null || true

echo "=== Cleanup Complete ==="
