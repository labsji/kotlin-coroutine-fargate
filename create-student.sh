#!/bin/bash
# create-student.sh — Creates student account + CodeCommit repo for Kotlin coroutine lab.
# Usage: bash create-student.sh <username> "<Full Name>"
# Run from the kotlin-coroutine-fargate source repo (tutor's copy).
set -euo pipefail
export AWS_PAGER=""

USERNAME="${1:?Usage: bash create-student.sh <username> \"<Full Name>\"}"
STUDENT_NAME="${2:-$USERNAME}"
REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_NAME="kotlin-coroutine-${USERNAME}"
REPO_URL="https://git-codecommit.${REGION}.amazonaws.com/v1/repos/${REPO_NAME}"
PASSWORD="Coroutine@2026!"
DEPLOY_ROLE="KotlinLabDeployRole"

echo "Creating student: $USERNAME ($STUDENT_NAME)"

# === IAM User ===
aws iam create-user --user-name "$USERNAME" 2>/dev/null || true
aws iam create-login-profile --user-name "$USERNAME" \
  --password "$PASSWORD" --password-reset-required 2>/dev/null || \
  aws iam update-login-profile --user-name "$USERNAME" --password "$PASSWORD"

# === Student Policy (base + AssumeRole + CloudWatch read) ===
aws iam put-user-policy --user-name "$USERNAME" --policy-name KotlinCoroutineLab \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[
    {\"Effect\":\"Allow\",\"Action\":\"cloudshell:*\",\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":\"codecommit:*\",\"Resource\":\"arn:aws:codecommit:${REGION}:${ACCOUNT_ID}:${REPO_NAME}\"},
    {\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:ListBucket\"],\"Resource\":[\"arn:aws:s3:::ikuku-releases\",\"arn:aws:s3:::ikuku-releases/*\"]},
    {\"Effect\":\"Allow\",\"Action\":\"iam:ChangePassword\",\"Resource\":\"arn:aws:iam::${ACCOUNT_ID}:user/${USERNAME}\"},
    {\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Resource\":\"arn:aws:iam::${ACCOUNT_ID}:role/${DEPLOY_ROLE}\"},
    {\"Effect\":\"Allow\",\"Action\":[\"cloudwatch:GetMetricData\",\"cloudwatch:GetMetricStatistics\",\"cloudwatch:ListMetrics\",\"cloudwatch:GetDashboard\",\"cloudwatch:ListDashboards\",\"cloudwatch:DescribeAlarms\"],\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":[\"ec2:DescribeInstances\",\"elasticbeanstalk:Describe*\",\"ecs:Describe*\",\"ecs:List*\"],\"Resource\":\"*\"}
  ]
}"

# === Deploy Role (create once, shared across students) ===
aws iam create-role --role-name "$DEPLOY_ROLE" \
  --assume-role-policy-document "{
    \"Version\":\"2012-10-17\",
    \"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::${ACCOUNT_ID}:root\"},\"Action\":\"sts:AssumeRole\"}]
  }" --description "Deploy role for Kotlin coroutine lab (Beanstalk + Fargate)" 2>/dev/null || true

aws iam put-role-policy --role-name "$DEPLOY_ROLE" --policy-name KotlinLabDeploy \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[
    {\"Effect\":\"Allow\",\"Action\":[\"elasticbeanstalk:*\"],\"Resource\":\"*\",\"Condition\":{\"StringEquals\":{\"aws:RequestedRegion\":\"${REGION}\"}}},
    {\"Effect\":\"Allow\",\"Action\":[\"ec2:*\",\"autoscaling:*\",\"cloudformation:*\"],\"Resource\":\"*\",\"Condition\":{\"StringEquals\":{\"aws:RequestedRegion\":\"${REGION}\"}}},
    {\"Effect\":\"Allow\",\"Action\":[\"ecs:*\"],\"Resource\":\"*\",\"Condition\":{\"StringEquals\":{\"aws:RequestedRegion\":\"${REGION}\"}}},
    {\"Effect\":\"Allow\",\"Action\":[\"ecr:*\"],\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":[\"s3:*\"],\"Resource\":[\"arn:aws:s3:::coroutine-lab-*\",\"arn:aws:s3:::coroutine-lab-*/*\",\"arn:aws:s3:::elasticbeanstalk-*\",\"arn:aws:s3:::elasticbeanstalk-*/*\"]},
    {\"Effect\":\"Allow\",\"Action\":[\"logs:*\"],\"Resource\":\"arn:aws:logs:${REGION}:${ACCOUNT_ID}:*\"},
    {\"Effect\":\"Allow\",\"Action\":[\"cloudwatch:GetMetricData\",\"cloudwatch:GetMetricStatistics\",\"cloudwatch:ListMetrics\"],\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":[\"iam:PassRole\",\"iam:CreateServiceLinkedRole\"],\"Resource\":\"*\"}
  ]
}" 2>/dev/null || true

# === ECS Task Execution Role (create once) ===
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document "{
    \"Version\":\"2012-10-17\",
    \"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ecs-tasks.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]
  }" 2>/dev/null || true
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true

# === CodeCommit Repo ===
aws codecommit create-repository --repository-name "$REPO_NAME" \
  --repository-description "Kotlin coroutine lab for $STUDENT_NAME" \
  --region "$REGION" 2>/dev/null || true

# Push content
echo "Pushing content to student repo..."
git remote remove "$USERNAME" 2>/dev/null || true
git remote add "$USERNAME" "$REPO_URL"
CURRENT_BRANCH=$(git branch --show-current)
for BRANCH in main tutor-main express-tutor; do
  git push -q "$USERNAME" "$BRANCH" 2>/dev/null || true
done

# Set default branch
aws codecommit update-default-branch \
  --repository-name "$REPO_NAME" \
  --default-branch-name express-tutor \
  --region "$REGION"

echo ""
echo "════════════════════════════════════════════════"
echo "  STUDENT CREATED: $STUDENT_NAME"
echo "════════════════════════════════════════════════"
echo ""
echo "  Console: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "  CloudShell: https://${REGION}.console.aws.amazon.com/cloudshell/home?region=${REGION}"
echo "  User:    $USERNAME"
echo "  Pass:    $PASSWORD"
echo ""
echo "  SETUP (run in student's CloudShell):"
echo ""
echo "  aws s3 cp s3://ikuku-releases/kotlin-setup.sh /tmp/setup.sh && cat /tmp/setup.sh && bash /tmp/setup.sh"
echo ""
echo "════════════════════════════════════════════════"
