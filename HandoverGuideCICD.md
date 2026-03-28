# Prompt2Test — CI/CD & Infrastructure Handover Guide

**Repo:** `github.com/ammuvisalakshi/Prompt2TestInfrastructure`
**Stack:** AWS CDK (TypeScript) · Region: `us-east-1`
**Last Updated:** 2026-03-28

---

## Overview

This repo contains the complete infrastructure for the **Prompt2Test** platform — an AI-powered test case generation and automation tool. Everything is defined as code using AWS CDK. A single command (`./deploy.sh`) deploys the entire platform to a new AWS account.

---

## Repository Structure

```
Prompt2TestInfrastructure/
├── bin/
│   └── infrastructure.ts         # CDK entry point — reads cdk.json context
├── lib/
│   └── prompt2test-stack.ts      # ALL AWS resources defined here (single stack)
├── cdk.json                      # CDK config — fill in githubOwner + githubConnectionArn
├── deploy.sh                     # End-to-end automated deployment script
├── lambda-pipeline.yaml          # CloudFormation template for Lambda CodePipeline
├── Prompt2Test_Architecture.html          # Architecture diagram
├── Prompt2Test_ArchitectureDecisions.html # Architecture decision records (ADRs)
├── Prompt2Test_DeploymentGuide.html       # Step-by-step deployment reference
└── package.json                  # CDK + TypeScript dependencies
```

---

## Prerequisites

Install these before running anything:

| Tool | Version | Install |
|------|---------|---------|
| AWS CLI | v2 | https://aws.amazon.com/cli |
| Node.js | v18+ | https://nodejs.org |
| AWS CDK | v2 | `npm install -g aws-cdk` |

Configure AWS credentials with **AdministratorAccess**:
```bash
aws configure
```

---

## What the CDK Stack Creates

Everything is in `lib/prompt2test-stack.ts` — one file, one stack (`Prompt2TestStack`).

| # | Resource | Name / Detail |
|---|----------|---------------|
| 1 | VPC | `prompt2test-vpc` — 2 public subnets, no NAT gateway |
| 2 | Cognito User Pool | `prompt2test-users` — email login, admin-only signup |
| 2 | Cognito Identity Pool | `prompt2test_identity` — maps users to IAM role |
| 3 | Aurora Serverless v2 | `prompt2test-vectors` — PostgreSQL 16 + pgvector, auto-pauses |
| 3 | Secrets Manager | `prompt2test/aurora/credentials` — Aurora password |
| 3.5 | DynamoDB | `prompt2test-config` — service configs + test accounts per team/env |
| 4 | Custom Resource Lambda | `p2t-schema-init` — runs DB schema on first deploy |
| 5 | Lambda (×2) | `p2t-testcase-writer`, `p2t-testcase-reader` |
| 6 | ECR Repos (×2) | `prompt2test-agent`, `prompt2test-playwright-mcp` |
| 7 | ECS Fargate Cluster | `prompt2test-playwright-cluster` |
| 7 | ECS Task Definition | `prompt2test-playwright-mcp` — ARM64, 2vCPU/4GB |
| 8 | SSM Parameters | `/prompt2test/playwright/*` and `/prompt2test/aurora/*` |
| 9 | CodePipeline (×3) | `prompt2test-lambda`, `prompt2test-agent-pipeline`, `prompt2test-playwright-mcp-pipeline` |
| 10 | AgentCore IAM Role | `prompt2test-agentcore-role` — Bedrock, ECS, DynamoDB, SSM, ECR |
| 11 | Cognito Auth Role | `prompt2test-cognito-auth-role` — Lambda, DynamoDB, Bedrock, Cognito admin |
| 12 | Amplify Hosting | `Prompt2TestUI` — React app via CloudFront CDN |

---

## IAM Roles Summary

### `prompt2test-agentcore-role`
Used by the Bedrock AgentCore runtime container.

| Permission | Resource | Purpose |
|-----------|----------|---------|
| `bedrock:InvokeModel` / `InvokeModelWithResponseStream` | Anthropic Claude ARNs | Run AI agent |
| `ecs:RunTask / StopTask / DescribeTasks / ListTasks` | playwright cluster + task def | Spin up browser sessions |
| `iam:PassRole` | ECS task roles | Required for RunTask |
| `dynamodb:Query / GetItem` | `prompt2test-config` | Read service config during test generation |
| `ssm:GetParameter` | `/prompt2test/playwright/*` | Read ECS infra config |
| `secretsmanager:GetSecretValue` | `prompt2test/*` | Aurora credentials |
| `ecr:GetAuthorizationToken` + pull | `*` | Pull Docker images |
| `logs:*` | `*` | CloudWatch logging |
| `elasticloadbalancing:DescribeTargetHealth` | `*` | Check browser task health |
| `ec2:DescribeNetworkInterfaces` | `*` | Get task public IP |

Trust: `bedrock.amazonaws.com`, `bedrock-agentcore.amazonaws.com`, `ecs-tasks.amazonaws.com`

---

### `prompt2test-cognito-auth-role`
Granted to browser users after Cognito login (via Identity Pool).

| Permission | Resource | Purpose |
|-----------|----------|---------|
| `lambda:InvokeFunction` | writer + reader Lambda ARNs | Save/fetch test cases |
| `dynamodb:Query / GetItem / PutItem / DeleteItem` | `prompt2test-config` | Manage service configs + accounts |
| `bedrock:InvokeAgentRuntime` | `*` | Call AgentCore from browser |
| `cognito-idp:ListUsers / AdminCreateUser / AdminDeleteUser / AdminSetUserPassword` | User Pool | Admin user management |
| `cognito-idp:CreateGroup / DeleteGroup / ListGroups / AdminAddUserToGroup / AdminRemoveUserFromGroup / AdminListGroupsForUser` | User Pool | Team group management |

---

## Deploying to a New AWS Account

### Step 1 — Prerequisites
```bash
aws --version       # must be v2
node --version      # must be v18+
cdk --version       # must be v2.x
aws sts get-caller-identity   # confirm credentials are working
```

### Step 2 — Enable Bedrock Models (browser)
AWS Console → Amazon Bedrock → Model access → Manage model access
Enable both:
- **Claude Sonnet 4.5** (Anthropic — cross-region inference profile)
- **Titan Embed Text v2** (Amazon)

### Step 3 — Create GitHub CodeStar Connection (browser)
AWS Console → Developer Tools → Settings → Connections
1. Create connection → GitHub → name it `Prompt2TestGitHub`
2. Authorize → Connect
3. Copy the Connection ARN

### Step 4 — Configure cdk.json
```json
{
  "context": {
    "githubOwner": "your-github-username",
    "githubConnectionArn": "arn:aws:codeconnections:us-east-1:ACCOUNT:connection/UUID"
  }
}
```

### Step 5 — Deploy
```bash
npm install
cdk bootstrap aws://<ACCOUNT_ID>/us-east-1
./deploy.sh
```

`deploy.sh` is fully automated and handles:
- CDK deploy (all AWS resources)
- Triggering all 3 CodePipelines
- Creating the Bedrock AgentCore runtime
- Setting `VITE_AGENT_RUNTIME_ARN` on Amplify
- Creating the admin Cognito user + group

It pauses **3 times** for steps that require a browser (Bedrock, CodeStar, Amplify branch connect).
All output values (ARNs, IDs) are saved to `deployment-outputs.txt` at the end.

---

## GitHub Repositories

| Repo | Purpose | Pipeline |
|------|---------|---------|
| `Prompt2TestUI` | React frontend (Amplify auto-deploys on push to master) | Amplify |
| `Prompt2TestInfrastructure` | CDK stack + deploy script (this repo) | Manual |
| `Prompt2TestAgent` | Bedrock AgentCore Python container | `prompt2test-agent-pipeline` |
| `Prompt2TestPlaywrightMCP` | Playwright + noVNC Docker container | `prompt2test-playwright-mcp-pipeline` |
| `Prompt2TestLambda` | Python Lambda functions | `prompt2test-lambda` |

---

## CI/CD Pipelines

### How each pipeline works:

**`prompt2test-agent-pipeline`**
Push to `Prompt2TestAgent` → CodeBuild → Docker build → push to `prompt2test-agent` ECR
AgentCore runtime picks up the new image on next invocation.

**`prompt2test-playwright-mcp-pipeline`**
Push to `Prompt2TestPlaywrightMCP` → CodeBuild → Docker build → push to `prompt2test-playwright-mcp` ECR
ECS tasks pull the latest image on each test run.

**`prompt2test-lambda`**
Push to `Prompt2TestLambda` → CodeBuild → zip → `aws lambda update-function-code`
Updates both `p2t-testcase-writer` and `p2t-testcase-reader` simultaneously.

**Amplify (UI)**
Push to `master` branch of `Prompt2TestUI` → Amplify auto-detects → rebuild + redeploy → live in ~2 min.

### Manually trigger a pipeline:
```bash
aws codepipeline start-pipeline-execution --name prompt2test-agent-pipeline --region us-east-1
aws codepipeline start-pipeline-execution --name prompt2test-playwright-mcp-pipeline --region us-east-1
aws codepipeline start-pipeline-execution --name prompt2test-lambda --region us-east-1
```

---

## Post-Deploy: Adding Teams & Services

After first login as admin, all configuration is done through the **UI** — no CLI needed:

1. **Create team groups** — Config tab → Teams → Create group (e.g. `teama`)
2. **Add users to groups** — Config tab → Users → assign to group
3. **Add services** — Config tab → Services → add service name + URL per environment
4. **Add test accounts** — Config tab → Accounts → add account credentials per environment

All config is stored in DynamoDB (`prompt2test-config` table).

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Config storage | DynamoDB (not SSM) | Browser can call DynamoDB directly via Cognito IAM; SSM requires server-side proxy |
| Team membership | Cognito Groups | JWT `cognito:groups` claim — no extra DB lookup needed |
| Browser sessions | ECS Fargate on-demand | One task per test run, stopped after completion — zero idle cost |
| Agent runtime | Bedrock AgentCore | Managed container runtime, no server to maintain |
| DB for test cases | Aurora Serverless v2 + pgvector | Semantic search via vector embeddings |

Full decision log: `Prompt2Test_ArchitectureDecisions.html`

---

## Useful Commands

```bash
# Check stack outputs
aws cloudformation describe-stacks --stack-name Prompt2TestStack --query "Stacks[0].Outputs" --region us-east-1

# Check pipeline status
aws codepipeline list-pipeline-executions --pipeline-name prompt2test-agent-pipeline --max-results 1

# Check AgentCore runtime status
aws bedrock-agentcore-control list-agent-runtimes --region us-east-1

# Check ECS cluster
aws ecs list-tasks --cluster prompt2test-playwright-cluster --region us-east-1

# View Lambda logs
aws logs tail /aws/lambda/p2t-testcase-reader --follow --region us-east-1
```

---

## Support

For questions about the platform architecture, see:
- `Prompt2Test_Architecture.html` — full architecture diagram
- `Prompt2Test_DeploymentGuide.html` — detailed step-by-step deployment reference
- `Prompt2Test_ArchitectureDecisions.html` — why each technology was chosen
