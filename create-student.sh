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

echo "Creating student: $USERNAME ($STUDENT_NAME)"

# IAM user
aws iam create-user --user-name "$USERNAME" 2>/dev/null || true
aws iam create-login-profile --user-name "$USERNAME" \
  --password "$PASSWORD" --password-reset-required 2>/dev/null || \
  aws iam update-login-profile --user-name "$USERNAME" --password "$PASSWORD"

# Policy
aws iam put-user-policy --user-name "$USERNAME" --policy-name KotlinCoroutineLab \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[
    {\"Effect\":\"Allow\",\"Action\":\"cloudshell:*\",\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":\"codecommit:*\",\"Resource\":\"arn:aws:codecommit:${REGION}:${ACCOUNT_ID}:${REPO_NAME}\"},
    {\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:ListBucket\"],\"Resource\":[\"arn:aws:s3:::ikuku-releases\",\"arn:aws:s3:::ikuku-releases/*\"]},
    {\"Effect\":\"Allow\",\"Action\":\"iam:ChangePassword\",\"Resource\":\"arn:aws:iam::${ACCOUNT_ID}:user/${USERNAME}\"}
  ]
}"

# CodeCommit repo
aws codecommit create-repository --repository-name "$REPO_NAME" \
  --repository-description "Kotlin coroutine lab for $STUDENT_NAME" \
  --region "$REGION" 2>/dev/null || true

# Push content to student's repo
echo "Pushing content to student repo..."
git remote remove "$USERNAME" 2>/dev/null || true
git remote add "$USERNAME" "$REPO_URL"
for BRANCH in main tutor-main; do
  git push -q "$USERNAME" "$BRANCH" 2>/dev/null || true
done

# Set default branch
aws codecommit update-default-branch \
  --repository-name "$REPO_NAME" \
  --default-branch-name tutor-main \
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
