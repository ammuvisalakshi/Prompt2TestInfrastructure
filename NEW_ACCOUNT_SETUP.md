# Prompt2Test — New AWS Account Setup Guide

## Overview

This guide walks you through deploying Prompt2Test on a **new AWS account** (including corporate accounts with SSO). One script does everything — you just need the right IAM permissions.

## Prerequisites

On your laptop:
- **AWS CLI v2** — [Install](https://aws.amazon.com/cli/)
- **Node.js v18+** — [Install](https://nodejs.org/)
- **AWS CDK** — `npm install -g aws-cdk`
- **Git** — with access to the Prompt2Test repos

## Step 1: Request IAM Permissions

Send this to your IT/Cloud team:

> I need an IAM role (or SSO permission set) to deploy a CDK-based application. I've attached the policy document — it's scoped to `prompt2test-*` resources only. No admin access needed.
>
> Attachment: `iam-deployer-policy.json`

The policy file is in this repo. It covers exactly what CDK needs to create:
- VPC + networking
- Cognito (user auth)
- Aurora Serverless v2 (PostgreSQL)
- Lambda functions
- ECR + ECS Fargate
- CodePipeline + CodeBuild (CI/CD)
- Amplify (UI hosting)
- Bedrock + AgentCore
- SSM, DynamoDB, Secrets Manager, CloudWatch

**Also request:**
- **Bedrock model access** — Ask your admin to enable these in the Bedrock console:
  - Claude Sonnet 4.5 (Anthropic) — cross-region inference profile
  - Titan Embed Text v2 (Amazon)

## Step 2: Configure AWS CLI

### For SSO accounts:

```bash
aws configure sso
# Profile name: prompt2test
# SSO start URL: https://your-org.awsapps.com/start
# SSO region: us-east-1
# Account: (select your account)
# Role: (select the role with the deployer policy)
# CLI default region: us-east-1
# Output format: json

# Login
aws sso login --profile prompt2test

# Set as default for this session
export AWS_PROFILE=prompt2test
```

### For IAM user accounts:

```bash
aws configure
# Access Key ID: (your key)
# Secret Access Key: (your secret)
# Region: us-east-1
# Output: json
```

### Verify:

```bash
aws sts get-caller-identity
# Should show your account ID and role/user
```

## Step 3: Clone and Deploy

```bash
# Clone the infrastructure repo
git clone https://github.com/YOUR_GITHUB_USERNAME/Prompt2TestInfrastructure.git
cd Prompt2TestInfrastructure

# Run the deployment script
bash deploy.sh
```

The script will:

| Phase | What happens | Manual? |
|---|---|---|
| 1 | Check prerequisites (CLI, Node, CDK, credentials) | Auto |
| 2 | Enable Bedrock models | **Browser** — follow the prompt |
| 3 | CDK bootstrap + create GitHub connection | **Browser** — authorize GitHub |
| 4 | `cdk deploy` — creates all AWS resources (~5-10 min) | Auto |
| 5 | Trigger 3 CodePipelines (Lambda, Playwright MCP, Agent) | Auto |
| 6 | Create Bedrock AgentCore runtime | Auto |
| 7 | Connect Amplify to GitHub | **Browser** — connect branch |
| 8 | Create admin Cognito user | Auto (asks for email) |

**Total time: ~20-30 minutes** (most of it automated)

## Step 4: Verify

After deployment completes:

1. Open the Amplify URL from **AWS Console → Amplify → Prompt2TestUI**
2. Log in with the email + temporary password shown by the script
3. Set a permanent password
4. Try these:
   - **Config tab** → Add a service + URL
   - **Agent tab** → Type a test prompt → agent responds
   - **Run a test** → Live browser window opens → PASS/FAIL

## What gets created

| Resource | Service | Monthly idle cost |
|---|---|---|
| VPC (2 subnets, no NAT) | EC2 | $0 |
| Cognito user pool | Cognito | $0 (free tier) |
| Aurora Serverless v2 (auto-pause) | RDS | ~$0.35/day when idle |
| 2 Lambda functions | Lambda | $0 (free tier) |
| DynamoDB table (pay-per-request) | DynamoDB | $0 |
| 2 ECR repositories | ECR | ~$0.50/mo (image storage) |
| ECS cluster (no running tasks) | ECS | $0 |
| 3 CodePipelines | CodePipeline | ~$3/mo |
| Amplify app | Amplify | ~$0 (free tier) |
| AgentCore runtime | Bedrock | ~$0.14/day |
| Secrets Manager (1 secret) | Secrets Manager | ~$0.40/mo |
| KMS key | KMS | ~$1/mo |
| CloudWatch logs | CloudWatch | ~$0.01/mo |
| **Total idle** | | **~$5-6/month** |

Per-test costs are on-demand:
- Claude Sonnet 4.5: ~$0.10-1.50 per test (depends on page complexity)
- ECS Fargate: ~$0.01-0.04 per test (~1-5 min runtime)

## Troubleshooting

### "Access Denied" during cdk deploy
Your IAM role is missing a permission. Check the error message for which service/action failed, and ask IT to add it to your policy.

### "Bedrock model access not granted"
Go to AWS Console → Bedrock → Model access → Enable Claude Sonnet 4.5 and Titan Embed v2.

### Pipeline fails at Build stage
Check CodeBuild logs: AWS Console → CodeBuild → prompt2test-*-build → click the failed build → View logs.

### Amplify build fails
Verify the Amplify environment variables are set (especially `VITE_AGENT_RUNTIME_ARN`). The deploy script sets this automatically.

### SSO token expired
```bash
aws sso login --profile prompt2test
```

## Files in this repo

| File | Purpose |
|---|---|
| `lib/prompt2test-stack.ts` | CDK stack — all AWS resources |
| `deploy.sh` | Automated deployment script |
| `iam-deployer-policy.json` | Minimum IAM policy to request |
| `deployment-outputs.txt` | Generated after deploy — all resource IDs |
