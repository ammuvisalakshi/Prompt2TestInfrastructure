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
step() { echo -e "\n${W}-- $1${N}"; }

# ── Confirm ──────────────────────────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || { echo "AWS CLI not configured"; exit 1; }

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
  info "No AgentCore runtime found"
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
  ATTEMPTS=0
  while true; do
    STATUS=$(aws cloudformation describe-stacks --stack-name Prompt2TestStack \
      --query "Stacks[0].StackStatus" --output text 2>&1)
    if echo "$STATUS" | grep -q "does not exist"; then
      echo ""
      ok "Stack deleted"
      break
    elif echo "$STATUS" | grep -q "FAILED"; then
      echo ""
      warn "Stack delete failed: $STATUS"
      break
    else
      printf "."
      ATTEMPTS=$((ATTEMPTS + 1))
      if [[ $ATTEMPTS -ge 40 ]]; then
        echo ""
        warn "Timed out waiting for stack deletion. Continuing with cleanup..."
        break
      fi
      sleep 15
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Step 3: Clean up retained resources (CDK RETAIN policy)
# ═══════════════════════════════════════════════════════════════════════════
step "3. Retained Resources (ECR, DynamoDB, Cognito, Logs)"

# ECR repos
for REPO in prompt2test-agent prompt2test-playwright-mcp; do
  aws ecr delete-repository --repository-name "$REPO" --force > /dev/null 2>&1 \
    && ok "Deleted ECR: $REPO" \
    || info "ECR $REPO already deleted"
done

# DynamoDB
aws dynamodb delete-table --table-name prompt2test-config > /dev/null 2>&1 \
  && ok "Deleted DynamoDB: prompt2test-config" \
  || info "DynamoDB prompt2test-config already deleted"

aws dynamodb delete-table --table-name prompt2test-selectors > /dev/null 2>&1 \
  && ok "Deleted DynamoDB: prompt2test-selectors" \
  || info "DynamoDB prompt2test-selectors already deleted"


# Cognito user pools
POOL_IDS=$(aws cognito-idp list-user-pools --max-results 20 \
  --query "UserPools[?Name=='prompt2test-users'].Id" --output text 2>/dev/null || echo "")
if [[ -n "$POOL_IDS" ]]; then
  for POOL_ID in $POOL_IDS; do
    aws cognito-idp delete-user-pool --user-pool-id "$POOL_ID" 2>/dev/null \
      && ok "Deleted Cognito pool: $POOL_ID"
  done
else
  info "No Cognito pools to delete"
fi

# CloudWatch log groups
LOG_GROUPS=$(MSYS_NO_PATHCONV=1 aws logs describe-log-groups \
  --query "logGroups[?contains(logGroupName,'prompt2test') || contains(logGroupName,'p2t-')].logGroupName" \
  --output text 2>/dev/null || echo "")
if [[ -n "$LOG_GROUPS" ]]; then
  for LG in $LOG_GROUPS; do
    MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name "$LG" 2>/dev/null \
      && ok "Deleted log group: $LG"
  done
else
  info "No log groups to delete"
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Step 4: Delete CDK Bootstrap
# ═══════════════════════════════════════════════════════════════════════════
step "4. CDK Bootstrap"
CDK_EXISTS=$(aws cloudformation describe-stacks --stack-name CDKToolkit \
  --query "Stacks[0].StackStatus" --output text 2>&1 || echo "DOES_NOT_EXIST")
if echo "$CDK_EXISTS" | grep -q "does not exist\|DOES_NOT_EXIST"; then
  info "CDK Bootstrap already deleted"
else
  # Empty the S3 bucket (including versioned objects)
  BUCKET="cdk-hnb659fds-assets-${ACCOUNT_ID}-us-east-1"
  info "Emptying CDK bucket: $BUCKET"
  aws s3 rm "s3://$BUCKET" --recursive > /dev/null 2>&1 || true

  # Delete all object versions
  VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo '{"Objects":null}')
  if echo "$VERSIONS" | grep -q '"Key"'; then
    aws s3api delete-objects --bucket "$BUCKET" --delete "$VERSIONS" > /dev/null 2>&1 || true
  fi

  # Delete all delete markers
  MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo '{"Objects":null}')
  if echo "$MARKERS" | grep -q '"Key"'; then
    aws s3api delete-objects --bucket "$BUCKET" --delete "$MARKERS" > /dev/null 2>&1 || true
  fi

  # Delete bucket
  aws s3 rb "s3://$BUCKET" 2>/dev/null && ok "Deleted CDK bucket" || true

  # Delete CDK ECR repo
  aws ecr delete-repository --repository-name "cdk-hnb659fds-container-assets-${ACCOUNT_ID}-us-east-1" --force > /dev/null 2>&1 || true

  # Delete the stack
  aws cloudformation delete-stack --stack-name CDKToolkit
  info "Waiting for CDK Bootstrap deletion..."
  ATTEMPTS=0
  while true; do
    STATUS=$(aws cloudformation describe-stacks --stack-name CDKToolkit \
      --query "Stacks[0].StackStatus" --output text 2>&1)
    if echo "$STATUS" | grep -q "does not exist"; then
      echo ""
      ok "CDK Bootstrap deleted"
      break
    elif echo "$STATUS" | grep -q "FAILED"; then
      echo ""
      warn "CDK Bootstrap delete failed. May need manual cleanup in console."
      break
    else
      printf "."
      ATTEMPTS=$((ATTEMPTS + 1))
      if [[ $ATTEMPTS -ge 20 ]]; then
        echo ""
        warn "Timed out. CDK Bootstrap may still be deleting."
        break
      fi
      sleep 15
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Step 5: Final Verification
# ═══════════════════════════════════════════════════════════════════════════
step "5. Final Verification"
CLEAN=true

aws cloudformation describe-stacks --stack-name Prompt2TestStack > /dev/null 2>&1 && { warn "Stack still exists"; CLEAN=false; } || ok "Stack: gone"
aws cloudformation describe-stacks --stack-name CDKToolkit > /dev/null 2>&1 && { warn "CDKToolkit still exists"; CLEAN=false; } || ok "CDKToolkit: gone"
aws ecr describe-repositories --repository-names prompt2test-agent > /dev/null 2>&1 && { warn "ECR agent still exists"; CLEAN=false; } || ok "ECR: gone"
aws dynamodb describe-table --table-name prompt2test-config > /dev/null 2>&1 && { warn "DynamoDB config still exists"; CLEAN=false; } || ok "DynamoDB config: gone"
aws dynamodb describe-table --table-name prompt2test-selectors > /dev/null 2>&1 && { warn "DynamoDB selectors still exists"; CLEAN=false; } || ok "DynamoDB selectors: gone"

POOLS=$(aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?Name=='prompt2test-users'].Id" --output text 2>/dev/null)
[[ -n "$POOLS" ]] && { warn "Cognito pool still exists: $POOLS"; CLEAN=false; } || ok "Cognito: gone"

RUNTIMES=$(aws bedrock-agentcore-control list-agent-runtimes --query "agentRuntimes[*].agentRuntimeName" --output text 2>/dev/null)
[[ -n "$RUNTIMES" ]] && { warn "AgentCore still exists: $RUNTIMES"; CLEAN=false; } || ok "AgentCore: gone"

aws s3api head-bucket --bucket "cdk-hnb659fds-assets-${ACCOUNT_ID}-us-east-1" > /dev/null 2>&1 && { warn "CDK S3 bucket still exists"; CLEAN=false; } || ok "CDK S3: gone"

# ═══════════════════════════════════════════════════════════════════════════
#  Done
# ═══════════════════════════════════════════════════════════════════════════
echo ""
if $CLEAN; then
  echo -e "${G}${W}"
  echo "  +========================================================+"
  echo "  |   Teardown Complete - Account is clean!                  |"
  echo "  +========================================================+"
  echo -e "${N}"
else
  echo -e "${Y}${W}"
  echo "  +========================================================+"
  echo "  |   Teardown finished with warnings - check above         |"
  echo "  +========================================================+"
  echo -e "${N}"
fi
echo "  Account: $ACCOUNT_ID"
echo "  To redeploy: bash deploy.sh $AWS_PROFILE"
echo ""
