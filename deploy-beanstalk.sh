#!/bin/bash
set -e
INSTANCE_TYPE="${1:-t3.small}"
REGION="${AWS_REGION:-ap-south-1}"
APP_NAME="coroutine-lab"
ENV_NAME="coroutine-lab-env"

echo "=== Deploying Kotlin Coroutine Lab to Beanstalk ==="
echo "Instance: $INSTANCE_TYPE | Region: $REGION"

# Build
./gradlew shadowJar -q

# Package — Corretto stack runs JAR directly via Procfile
mkdir -p .ebdeploy
cp build/libs/*-all.jar .ebdeploy/app.jar
echo "web: java -jar app.jar" > .ebdeploy/Procfile
cd .ebdeploy && zip -q ../deploy.zip app.jar Procfile && cd ..

# Deploy
aws elasticbeanstalk create-application --application-name "$APP_NAME" --region "$REGION" 2>/dev/null || true
aws s3 mb "s3://${APP_NAME}-deploy-${REGION}" --region "$REGION" 2>/dev/null || true
aws s3 cp deploy.zip "s3://${APP_NAME}-deploy-${REGION}/deploy.zip" --region "$REGION" --quiet

VERSION="v$(date +%s)"
aws elasticbeanstalk create-application-version --application-name "$APP_NAME" \
  --version-label "$VERSION" \
  --source-bundle S3Bucket="${APP_NAME}-deploy-${REGION}",S3Key="deploy.zip" \
  --region "$REGION" > /dev/null

if aws elasticbeanstalk describe-environments --application-name "$APP_NAME" --environment-names "$ENV_NAME" --region "$REGION" --query 'Environments[0].Status' --output text 2>/dev/null | grep -qE "Ready|Launching|Updating"; then
  echo "Updating existing environment..."
  aws elasticbeanstalk update-environment --environment-name "$ENV_NAME" --version-label "$VERSION" --region "$REGION" > /dev/null
else
  echo "Creating new environment..."
  aws elasticbeanstalk create-environment --application-name "$APP_NAME" \
    --environment-name "$ENV_NAME" --version-label "$VERSION" \
    --solution-stack-name "64bit Amazon Linux 2023 v4.12.0 running Corretto 21" \
    --option-settings \
      "Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=${INSTANCE_TYPE}" \
      "Namespace=aws:elasticbeanstalk:environment,OptionName=EnvironmentType,Value=SingleInstance" \
    --region "$REGION" > /dev/null
fi

rm -rf .ebdeploy deploy.zip

echo ""
echo "Deploying... takes ~3-5 minutes."
echo "Check status:"
echo "  aws elasticbeanstalk describe-environments --environment-names $ENV_NAME --region $REGION --query 'Environments[0].{Status:Status,URL:CNAME}'"
echo ""
echo "Once ready, test:"
echo "  curl http://\$(aws elasticbeanstalk describe-environments --environment-names $ENV_NAME --region $REGION --query 'Environments[0].CNAME' --output text)/lab/1"
