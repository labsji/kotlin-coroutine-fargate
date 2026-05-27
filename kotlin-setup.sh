#!/bin/bash
# kotlin-setup.sh — Run once in student's CloudShell.
# After this, student lands in Kiro every time they open CloudShell.
set -euo pipefail
export AWS_PAGER=""

REGION="${AWS_REGION:-ap-south-1}"
USERNAME=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F/ '{print $NF}')
REPO_URL="https://git-codecommit.${REGION}.amazonaws.com/v1/repos/kotlin-coroutine-${USERNAME}"

echo "✓ Setting up Kotlin Coroutine Lab for: $USERNAME"

# Git credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Clone
if [ ! -d ~/kotlin-coroutine-fargate ]; then
  echo "  Cloning lab content..."
  git clone -q "$REPO_URL" ~/kotlin-coroutine-fargate
fi

# Install Kiro CLI
if ! command -v kiro-cli &>/dev/null; then
  echo "  Installing Kiro..."
  curl -fsSL https://kiro.dev/install.sh | bash
fi

# Configure Kiro (login)
echo "  Configuring Kiro — follow the login prompt:"
kiro-cli login

# Auto-launch hook
sed -i '/# kotlin-coroutine-autostart/,/^fi$/d' ~/.bashrc 2>/dev/null
cat >> ~/.bashrc << 'EOF'

# kotlin-coroutine-autostart
if [ -d ~/kotlin-coroutine-fargate ] && [ -t 0 ]; then
  cd ~/kotlin-coroutine-fargate
  git checkout -q tutor-main 2>/dev/null
  bash start.sh
fi
EOF

echo "✓ Done. Close this window. Next time you open CloudShell, Kiro starts automatically."
