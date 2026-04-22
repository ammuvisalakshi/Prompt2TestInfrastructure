#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  Prompt2Test — Full Teardown Script
#  Removes ALL resources created by deploy.sh from the AWS account.
#
#  Usage:
#    bash teardown.sh <profile>
#    bash teardown.sh p2t-deployer
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── AWS Profile ──────────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  export AWS_PROFILE="$1"
elif [[ -z "${AWS_PROFILE:-}" ]]; then
  echo "  No AWS_PROFILE set. Enter the profile name:"
  read -r AWS_PROFILE
  export AWS_PROFILE
fi

# ── Colours ──────────────────────────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'
C='\033[0;36m'; W='\033[1m'; N='\033[0m'

ok()   { echo -e "${G}   [OK]  $1${N}"; }
info() { echo -e "   ${C}[i]  $1${N}"; }
warn() { echo -e "${Y}   [!]  $1${N}"; }
err()  { echo -e "${R}   [X]  $1${N}"; }
step() { echo -e "\n${W}-- $1${N}"; }

# ── Confirm ──────────────────────────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || { err "AWS CLI not configured"; exit 1; }

echo -e "${W}"
echo "  +========================================================+"
echo "  |    Prompt2Test - TEARDOWN                                |"
echo "  |    Account: $ACCOUNT_ID                          |"
echo "  +========================================================+"
echo -e "${N}"
echo -e "  ${R}This will DELETE all Prompt2Test resources from this account.${N}"
echo ""
echo -e "  Type ${W}DELETE${N} to confirm:"
read -r CONFIRM
[[ "$CONFIRM" == "DELETE" ]] || { echo "  Aborted."; exit 0; }

# ═══════════════════════════════════════════════════════════════════════════
#  Step 1: Delete AgentCore Runtime
# ═══════════════════════════════════════════════════════════════════════════
step "1. AgentCore Runtime"
RUNTIME_ID=$(aws bedrock-agentcore-control list-agent-runtimes \
  --query "agentRuntimes[?agentRuntimeName=='Prompt2TestAgent'].agentRuntimeId" \
  --output text 2>/dev/null || echo "")
if [[ -n "$RUNTIME_ID" && "$RUNTIME_ID" != "None" ]]; then
  aws bedrock-agentcore-control delete-agent-runtime --agent-runtime-id "$RUNTIME_ID" > /dev/null 2>&1
  ok "Deleted AgentCore runtime: $RUNTIME_ID"
  sleep 10
else
  info "No AgentCore runtime found (already deleted)"
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Step 2: Delete CloudFormation Stack
# ═══════════════════════════════════════════════════════════════════════════
step "2. CloudFormation Stack"
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name Prompt2TestStack \
  --query "Stacks[0].StackStatus" --output text 2>&1 || echo "DOES_NOT_EXIST")
if echo "$STACK_EXISTS" | grep -q "does not exist\|DOES_NOT_EXIST"; then
  info "Stack already deleted"
else
  aws cloudformation delete-stack --stack-name Prompt2TestStack
  info "Stack deletion initiated - waiting (Aurora takes ~5 min)..."
  while true; do
    STATUS=$(aws cloudformation describe-stacks --stack-name Prompt2TestStack \
      --query "Stacks[0].StackStatus" --output text 2>&1)
    if echo "$STATUS" | grep -q "does not exist"; then
      ok "Stack deleted"
      break
    elif echo "$STATUS" | grep -q "FAILED"; then
      warn "Stack delete failed: $STATUS"
      break
    else
      printf "."
      sleep 30
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Step 3: Clean up retained resources (CDK RETAIN policy)
# ═══════════════════════════════════════════════════════════════════════════
step "3. Retained Resources (ECR, DynamoDB, Cognito)"

# ECR repos
for REPO in prompt2test-agent prompt2test-playwright-mcp; do
  aws ecr delete-repository --repository-name "$REPO" --force > /dev/null 2>&1 \
    && ok "Deleted ECR: $REPO" \
    || info "ECR $REPO already deleted"
done

# DynamoDB
aws dynamodb delete-table --table-name prompt2test-config > /dev/null 2>&1 \
  && ok "Deleted DynamoDB: prompt2test-config" \
  || info "DynamoDB already deleted"

# Cognito user pools
for POOL_ID in $(aws cognito-idp list-user-pools --max-results 20 \
  --query "UserPools[?Name=='prompt2test-users'].Id" --output text 2>/dev/null); do
  aws cognito-idp delete-user-pool --user-pool-id "$POOL_ID" 2>/dev/null \
    && ok "Deleted Cognito pool: $POOL_ID"
done

# CloudWatch log groups
for LG in $(MSYS_NO_PATHCONV=1 aws logs describe-log-groups \
  --query "logGroups[?contains(logGroupName,'prompt2test') || contains(logGroupName,'p2t-')].logGroupName" \
  --output text 2>/dev/null || echo ""); do
  if [[ -n "$LG" ]]; then
    MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name "$LG" 2>/dev/null \
      && ok "Deleted log group: $LG"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════
#  Step 4: Delete CDK Bootstrap (optional)
# ═══════════════════════════════════════════════════════════════════════════
step "4. CDK Bootstrap"
CDK_EXISTS=$(aws cloudformation describe-stacks --stack-name CDKToolkit \
  --query "Stacks[0].StackStatus" --output text 2>&1 || echo "DOES_NOT_EXIST")
if echo "$CDK_EXISTS" | grep -q "does not exist\|DOES_NOT_EXIST"; then
  info "CDK Bootstrap already deleted"
else
  # Empty the S3 bucket first
  BUCKET=$(aws cloudformation describe-stack-resources --stack-name CDKToolkit \
    --query "StackResources[?LogicalResourceId=='StagingBucket'].PhysicalResourceId" \
    --output text 2>/dev/null || echo "")
  if [[ -n "$BUCKET" ]]; then
    info "Emptying CDK bucket: $BUCKET"
    aws s3 rm "s3://$BUCKET" --recursive > /dev/null 2>&1 || true
    # Also delete versioned objects
    aws s3api list-object-versions --bucket "$BUCKET" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null | \
      aws s3api delete-objects --bucket "$BUCKET" --delete file:///dev/stdin > /dev/null 2>&1 || true
  fi
  aws cloudformation delete-stack --stack-name CDKToolkit
  info "Waiting for CDK Bootstrap deletion..."
  while true; do
    STATUS=$(aws cloudformation describe-stacks --stack-name CDKToolkit \
      --query "Stacks[0].StackStatus" --output text 2>&1)
    if echo "$STATUS" | grep -q "does not exist"; then
      ok "CDK Bootstrap deleted"
      break
    elif echo "$STATUS" | grep -q "FAILED"; then
      warn "CDK Bootstrap delete failed. Delete manually in console."
      break
    else
      printf "."
      sleep 15
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Done
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${G}${W}"
echo "  +========================================================+"
echo "  |   Teardown Complete!                                     |"
echo "  +========================================================+"
echo -e "${N}"
echo "  All Prompt2Test resources have been removed from account $ACCOUNT_ID."
echo "  To redeploy: bash deploy.sh $AWS_PROFILE"
echo ""
