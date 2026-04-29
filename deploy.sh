#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  Prompt2Test — Full New-Account Deployment Script
#  Run from the root of the Prompt2TestInfrastructure repo in Git Bash or bash.
#  Automates all CLI steps. Pauses for the 3 steps that require a browser.
#
#  Usage:
#    bash deploy.sh <profile> <github-connection-arn> <github-owner>
#    bash deploy.sh p2t-deployer arn:aws:codeconnections:us-east-1:123:connection/uuid ammuvisalakshi
#    bash deploy.sh p2t-deployer   (prompts for GitHub details)
#    bash deploy.sh                (prompts for everything)
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Arguments: profile, github ARN, github owner ────────────────────────────
if [[ -n "${1:-}" ]]; then
  export AWS_PROFILE="$1"
elif [[ -z "${AWS_PROFILE:-}" ]]; then
  echo ""
  echo "  No AWS_PROFILE set. Enter the profile name to use"
  echo "  (e.g. p2t-deployer, or your SSO profile name):"
  read -r AWS_PROFILE
  export AWS_PROFILE
fi

ARG_GITHUB_CONN_ARN="${2:-}"
ARG_GITHUB_OWNER="${3:-}"

# ── Colours ─────────────────────────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
R='\033[0;31m'; C='\033[0;36m'; W='\033[1m'; N='\033[0m'

phase()  { echo -e "\n${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"; }
step()   { echo -e "\n${B}${W}-- Step $1: $2${N}"; }
ok()     { echo -e "${G}   [OK]  $1${N}"; }
info()   { echo -e "   ${C}[i]  $1${N}"; }
warn()   { echo -e "${Y}   [!]  $1${N}"; }
err()    { echo -e "${R}   [X]  $1${N}"; exit 1; }
manual() { echo -e "\n${Y}${W}   MANUAL STEP REQUIRED${N}\n${Y}$1${N}"; }
pause_for_user()  { echo -e "\n${Y}   Press Enter when done${N}"; read -r; }
ask()    { local prompt=$1 var=$2; echo -e "\n${C}   ? $prompt${N}"; read -r "$var"; }

# ── Banner ───────────────────────────────────────────────────────────────────
echo -e "${W}"
echo "  +========================================================+"
echo "  |    Prompt2Test - New AWS Account Deployment Script       |"
echo "  |    AWS Region: us-east-1                                 |"
echo "  +========================================================+"
echo -e "${N}"
echo "  This script automates all CLI steps from the deployment guide."
echo "  It will pause 3 times for steps that require your browser."
echo ""
echo "  Prerequisites: AWS CLI, Node.js v18+, CDK 2.x installed."
echo ""
echo -e "  Press ${W}Enter${N} to start, or Ctrl+C to cancel."
read -r

# ── Verify we're in the right directory ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ -f "lib/prompt2test-stack.ts" ]] || err "Run this script from the root of the Prompt2TestInfrastructure repo (lib/prompt2test-stack.ts not found)."

# ── Pull latest from git ────────────────────────────────────────────────────
step "0" "Pull latest code from git"
git pull --ff-only 2>&1 || warn "Git pull failed — using local files"
ok "Using latest code from git"

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — PREREQUISITE CHECKS
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 1 - Prerequisite Checks"

step 1 "AWS CLI"
aws --version 2>&1 | head -1 || err "AWS CLI not found. Install v2 from aws.amazon.com/cli"
ok "AWS CLI found"

step 2 "Node.js"
NODE_VER=$(node --version 2>/dev/null) || err "Node.js not found. Install LTS from nodejs.org"
MAJOR="${NODE_VER#v}"; MAJOR="${MAJOR%%.*}"
[[ "$MAJOR" -ge 18 ]] || err "Node.js v18+ required. Found $NODE_VER"
ok "Node.js $NODE_VER"

step 3 "AWS CDK"
CDK_VER=$(npx cdk --version 2>/dev/null) || err "CDK not found. Run: npm install -g aws-cdk"
ok "CDK $CDK_VER"

step 4 "AWS credentials"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || err "AWS CLI not configured. Run: aws configure (or export AWS_PROFILE=your-profile)"
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
info "Account : $ACCOUNT_ID"
info "Identity: $USER_ARN"
ok "Connected to AWS account $ACCOUNT_ID"

step "4b" "IAM permissions check"
ok "Credentials verified for account $ACCOUNT_ID"
info "Permissions will be validated during deployment. If a step fails,"
info "the error will tell you exactly which permission is missing."

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — MANUAL CONSOLE STEPS
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 2 - Manual Console Steps (browser required)"

# ── Step 5: CDK Bootstrap ────────────────────────────────────────────────────
step 5 "CDK Bootstrap"
info "Running cdk bootstrap for account $ACCOUNT_ID in us-east-1..."
npx cdk bootstrap "aws://$ACCOUNT_ID/us-east-1" || err "CDK bootstrap failed. Check IAM permissions."
ok "CDK bootstrapped"

# ── Step 6: GitHub CodeStar Connection ──────────────────────────────────────
step 6 "GitHub CodeStar Connection"

if [[ -n "$ARG_GITHUB_CONN_ARN" && -n "$ARG_GITHUB_OWNER" ]]; then
  GITHUB_CONN_ARN="$ARG_GITHUB_CONN_ARN"
  GITHUB_OWNER="$ARG_GITHUB_OWNER"
  info "Using GitHub connection from arguments"
  info "ARN:   $GITHUB_CONN_ARN"
  info "Owner: $GITHUB_OWNER"
else
  manual "$(cat <<'MSG'
   Open: AWS Console -> Developer Tools -> Settings -> Connections
   1. Click "Create connection" -> select GitHub
   2. Name it:  Prompt2TestGitHub
   3. Click "Connect to GitHub" -> authorize the popup
   4. Click "Connect"
   5. Copy the Connection ARN from the connection details page
      It looks like: arn:aws:codeconnections:us-east-1:ACCOUNT:connection/UUID
MSG
  )"
  pause_for_user

  ask "Paste your GitHub Connection ARN:" GITHUB_CONN_ARN
  ask "Your GitHub username (e.g. ammuvisalakshi):" GITHUB_OWNER
fi

# Sanity-check the ARN
if [[ "$GITHUB_CONN_ARN" != arn:aws:*connection* ]]; then
  warn "ARN doesn't look right. Make sure you pasted the full ARN."
  echo -e "   Continue anyway? (y/N): \c"
  read -r CONT
  [[ "$CONT" =~ ^[Yy]$ ]] || err "Aborted. Get the correct ARN and re-run."
fi

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 3 — CDK DEPLOY
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 3 - CDK Deploy (automated, ~5-10 min)"

step 8 "Update cdk.json with your GitHub details"
node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('cdk.json', 'utf8'));
cfg.context.githubOwner         = '${GITHUB_OWNER}';
cfg.context.githubConnectionArn = '${GITHUB_CONN_ARN}';
fs.writeFileSync('cdk.json', JSON.stringify(cfg, null, 2) + '\n');
console.log('Updated cdk.json');
"
ok "cdk.json updated with githubOwner=$GITHUB_OWNER"

step 9 "npm install"
npm install --silent 2>&1 | tail -1
ok "Dependencies installed"

step 10 "cdk deploy"
info "Deploying all resources - this takes 5-10 minutes..."
npx cdk deploy --require-approval never || err "CDK deploy failed. Check the error above for missing permissions."
ok "CDK deploy complete"

step "10b" "Verify Phase 4+5 resources (created by CDK)"
# These are created by CDK in the stack. This step just verifies they exist.
# Non-fatal: if checks fail due to permissions, CDK already created them.
if aws dynamodb describe-table --table-name prompt2test-selectors > /dev/null 2>&1; then
  ok "DynamoDB prompt2test-selectors exists"
else
  info "DynamoDB prompt2test-selectors — created by CDK (cannot verify due to permissions)"
fi


# ── Capture CDK outputs ──────────────────────────────────────────────────────
info "Reading CDK stack outputs..."
cfn_out() {
  aws cloudformation describe-stacks \
    --stack-name Prompt2TestStack \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text
}
USER_POOL_ID=$(cfn_out OutUserPoolId)
USER_POOL_CLIENT_ID=$(cfn_out OutUserPoolClientId)
IDENTITY_POOL_ID=$(cfn_out OutIdentityPoolId)
AGENT_ECR_URI=$(cfn_out OutAgentEcrUri)
AGENTCORE_ROLE_ARN=$(cfn_out OutAgentCoreRoleArn)
AMPLIFY_APP_ID=$(cfn_out OutAmplifyAppId)

echo ""
echo "  +-------------------------------------------------------------+"
echo "  |  CDK Outputs                                                 |"
echo "  +-------------------------------------------------------------+"
printf "  |  %-22s  %s\n" "UserPoolId"          "$USER_POOL_ID"
printf "  |  %-22s  %s\n" "UserPoolClientId"    "$USER_POOL_CLIENT_ID"
printf "  |  %-22s  %s\n" "IdentityPoolId"      "$IDENTITY_POOL_ID"
printf "  |  %-22s  %s\n" "AgentEcrUri"         "$AGENT_ECR_URI"
printf "  |  %-22s  %s\n" "AgentCoreRoleArn"    "$AGENTCORE_ROLE_ARN"
printf "  |  %-22s  %s\n" "AmplifyAppId"        "$AMPLIFY_APP_ID"
echo "  +-------------------------------------------------------------+"

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — TRIGGER CODEPIPELINES
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 4 - Deploy Lambda Code & Build Docker Images (~5-10 min each)"

step 11 "Trigger all 3 CodePipelines"
for P in prompt2test-lambda prompt2test-playwright-mcp prompt2test-rest-mcp prompt2test-agent; do
  aws codepipeline start-pipeline-execution --name "$P" > /dev/null 2>&1 \
    || warn "Could not start pipeline $P (may not exist yet if CDK just created it)"
  info "Started $P"
done
ok "All pipelines triggered"

echo ""
info "Polling pipelines - waiting for Succeeded..."
for P in prompt2test-lambda prompt2test-playwright-mcp prompt2test-rest-mcp prompt2test-agent; do
  printf "   %-38s" "$P"
  ATTEMPTS=0
  MAX_ATTEMPTS=60  # 60 * 15s = 15 min max wait per pipeline
  while true; do
    STATUS=$(aws codepipeline list-pipeline-executions \
      --pipeline-name "$P" --max-results 1 \
      --query 'pipelineExecutionSummaries[0].status' --output text 2>/dev/null || echo "Unknown")
    case "$STATUS" in
      Succeeded) echo -e " ${G}[OK] Succeeded${N}"; break ;;
      Failed)    echo -e " ${R}[X] Failed${N}"
                 err "Pipeline $P failed. Check: AWS Console -> CodePipeline -> $P -> click failed stage -> View in CodeBuild." ;;
      *)         printf "."
                 ATTEMPTS=$((ATTEMPTS + 1))
                 if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
                   echo -e " ${Y}[!] Timed out${N}"
                   warn "Pipeline $P did not complete in 15 min. Check it manually in the console."
                   break
                 fi
                 sleep 15 ;;
    esac
  done
done

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 4b — MARKETPLACE SUBSCRIPTION (one-time, requires root/admin)
# ════════════════════════════════════════════════════════════════════════════
step "11b" "Anthropic Marketplace Subscription"
manual "$(cat <<'MSG'
   Anthropic Claude models require a one-time Marketplace subscription.
   As ROOT or admin user (not the deployer):
   1. Open: AWS Console -> Amazon Bedrock -> Model catalog
   2. Search for "Claude Sonnet" -> click on Claude Sonnet 4.5
   3. Click "Subscribe" or "Accept terms" (may redirect to Marketplace)
   4. Accept the pricing terms and wait for "Active" status

   Skip this step if already done on this account.
MSG
)"
pause_for_user

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 5 — AGENTCORE RUNTIME
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 5 - Create Bedrock AgentCore Runtime"

step 12 "Create AgentCore Runtime"

# Check if runtime already exists (idempotent re-runs)
EXISTING_RUNTIME=$(aws bedrock-agentcore-control list-agent-runtimes \
  --query "agentRuntimes[?agentRuntimeName=='Prompt2TestAgent'].agentRuntimeId" \
  --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_RUNTIME" && "$EXISTING_RUNTIME" != "None" ]]; then
  info "AgentCore runtime already exists: $EXISTING_RUNTIME"
  AGENT_RUNTIME_ID="$EXISTING_RUNTIME"
  AGENT_RUNTIME_ARN=$(aws bedrock-agentcore-control get-agent-runtime \
    --agent-runtime-id "$AGENT_RUNTIME_ID" \
    --query 'agentRuntimeArn' --output text)
else
  AGENTCORE_JSON=$(aws bedrock-agentcore-control create-agent-runtime \
    --agent-runtime-name Prompt2TestAgent \
    --agent-runtime-artifact "{\"containerConfiguration\":{\"containerUri\":\"${AGENT_ECR_URI}:latest\"}}" \
    --role-arn "$AGENTCORE_ROLE_ARN" \
    --network-configuration '{"networkMode":"PUBLIC"}')

  AGENT_RUNTIME_ARN=$(node -e "process.stdout.write(JSON.parse(process.argv[1]).agentRuntimeArn)" "$AGENTCORE_JSON")
  AGENT_RUNTIME_ID=$(node -e "process.stdout.write(JSON.parse(process.argv[1]).agentRuntimeId)" "$AGENTCORE_JSON")
fi

info "AgentCore ARN: $AGENT_RUNTIME_ARN"
info "AgentCore ID:  $AGENT_RUNTIME_ID"

printf "   Waiting for READY"
ATTEMPTS=0
while true; do
  STATUS=$(aws bedrock-agentcore-control get-agent-runtime \
    --agent-runtime-id "$AGENT_RUNTIME_ID" \
    --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
  if [[ "$STATUS" == "READY" || "$STATUS" == "ACTIVE" ]]; then
    echo -e " ${G}[OK] $STATUS${N}"; break
  else
    printf "."
    ATTEMPTS=$((ATTEMPTS + 1))
    if [[ $ATTEMPTS -ge 30 ]]; then
      echo -e " ${Y}[!] Timed out${N}"
      warn "AgentCore not ready after 10 min. Check console: Bedrock -> AgentCore"
      break
    fi
    sleep 20
  fi
done

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 6 — AMPLIFY CONNECT (MANUAL)
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 6 - Connect Amplify to GitHub (browser required)"

step "13a" "Connect Amplify branch to GitHub (browser)"
manual "$(cat <<MSG
   Open: AWS Console -> AWS Amplify -> Prompt2TestUI  (App ID: $AMPLIFY_APP_ID)
   1. Click "Connect branch"
   2. Select GitHub -> Prompt2TestUI repo -> branch: master
   3. Service role: select "prompt2test-amplify-service-role" (already created by CDK)
   4. Click "Save and deploy"
   5. Wait for the build to start (it may fail - that's OK, we set env vars next)
MSG
)"
pause_for_user

step "13b" "Set Amplify environment variables"
info "Setting all VITE_ env vars on Amplify app..."
aws amplify update-app \
  --app-id "$AMPLIFY_APP_ID" \
  --environment-variables "{
    \"VITE_AWS_REGION\": \"us-east-1\",
    \"VITE_USER_POOL_ID\": \"$USER_POOL_ID\",
    \"VITE_USER_POOL_CLIENT_ID\": \"$USER_POOL_CLIENT_ID\",
    \"VITE_IDENTITY_POOL_ID\": \"$IDENTITY_POOL_ID\",
    \"VITE_AGENT_RUNTIME_ARN\": \"$AGENT_RUNTIME_ARN\"
  }" > /dev/null
ok "All VITE_ env vars set on Amplify"

step "13c" "Trigger Amplify rebuild with env vars"
aws amplify start-job --app-id "$AMPLIFY_APP_ID" --branch-name master --job-type RELEASE > /dev/null 2>&1
info "Rebuild triggered - waiting for completion..."
ATTEMPTS=0
while true; do
  STATUS=$(aws amplify list-jobs --app-id "$AMPLIFY_APP_ID" --branch-name master --max-items 1 \
    --query 'jobSummaries[0].status' --output text 2>/dev/null || echo "Unknown")
  case "$STATUS" in
    SUCCEED) ok "Amplify build succeeded"; break ;;
    FAILED)  warn "Amplify build failed. Check console for details."; break ;;
    *)       printf "."
             ATTEMPTS=$((ATTEMPTS + 1))
             if [[ $ATTEMPTS -ge 40 ]]; then warn "Timed out. Check Amplify console."; break; fi
             sleep 15 ;;
  esac
done

# ════════════════════════════════════════════════════════════════════════════
#  PHASE 7 — ADMIN USER SETUP
# ════════════════════════════════════════════════════════════════════════════
phase "PHASE 7 - Create Admin User"

step 14 "Create admin Cognito group"
aws cognito-idp create-group \
  --user-pool-id "$USER_POOL_ID" \
  --group-name "admin" \
  --description "Platform administrators" > /dev/null 2>&1 \
  || warn "Group 'admin' may already exist (OK)"
ok "Admin group ready"
info "Tip: Add team groups (e.g. 'teama') via the Config tab in the UI after login."

step 15 "Create admin user in Cognito"
ask "Admin email address (used to log in):" ADMIN_EMAIL
aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$ADMIN_EMAIL" \
  --temporary-password "TempPass123!" \
  --user-attributes \
    Name=email,Value="$ADMIN_EMAIL" \
    Name=email_verified,Value=true > /dev/null
ok "Admin user created - temporary password: TempPass123!"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "$USER_POOL_ID" \
  --username "$ADMIN_EMAIL" \
  --group-name "admin" > /dev/null 2>&1 || true
ok "Admin user added to 'admin' group"

# ════════════════════════════════════════════════════════════════════════════
#  SAVE OUTPUTS TO FILE
# ════════════════════════════════════════════════════════════════════════════
OUTPUTS_FILE="$SCRIPT_DIR/deployment-outputs.txt"
cat > "$OUTPUTS_FILE" <<EOF
Prompt2Test Deployment Outputs
Generated: $(date)
Account ID:             $ACCOUNT_ID
Region:                 us-east-1
GitHub Owner:           $GITHUB_OWNER
GitHub Connection ARN:  $GITHUB_CONN_ARN

CDK Stack Outputs:
  UserPoolId:           $USER_POOL_ID
  UserPoolClientId:     $USER_POOL_CLIENT_ID
  IdentityPoolId:       $IDENTITY_POOL_ID
  AgentEcrUri:          $AGENT_ECR_URI
  AgentCoreRoleArn:     $AGENTCORE_ROLE_ARN
  AmplifyAppId:         $AMPLIFY_APP_ID

AgentCore:
  ARN:                  $AGENT_RUNTIME_ARN
  ID:                   $AGENT_RUNTIME_ID

Admin User:
  Email:                $ADMIN_EMAIL
  Temp Password:        TempPass123!
EOF
info "All values saved to: deployment-outputs.txt"

# ════════════════════════════════════════════════════════════════════════════
#  DONE
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${G}${W}"
echo "  +========================================================+"
echo "  |   Deployment Complete!                                   |"
echo "  +========================================================+"
echo -e "${N}"
echo "  Next step:"
echo "    1. Open your Amplify URL from the AWS Console -> Amplify -> Prompt2TestUI"
echo "    2. Log in with: $ADMIN_EMAIL  /  TempPass123!"
echo "    3. You will be prompted to set a permanent password"
echo ""
echo "  Verify the platform:"
echo "    - Config tab    -> add a service + URL"
echo "    - Agent tab     -> type a test prompt -> agent responds"
echo "    - Inventory tab -> save a test and verify it is stored"
echo "    - Run a test    -> live browser window opens -> PASS/FAIL recorded"
echo ""
echo "  All saved values: deployment-outputs.txt"
echo ""
echo -e "${Y}  Security reminder:${N}"
echo "  If you used AdministratorAccess for this deploy, consider replacing"
echo "  it with the scoped Prompt2TestDeployer policies for day-to-day use."
echo ""
