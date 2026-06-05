# GitHub Actions → EKS CI/CD — Playbook

End-to-end guide: OIDC trust setup → GitHub Actions workflow → live deployment on EKS triggered by a Git push.

| Phase | What | Key concepts |
|-------|------|--------------|
| **Phase 1** | OIDC + basic build → push → deploy | No stored keys, audit trail per commit |
| **Phase 2** | Multi-environment promotion | Dev → staging → prod gates |
| **Phase 3** | Image updater + ArgoCD hand-off | Decouple build from deploy |
| **Phase 4** | Dependency patching pipeline | Automated CVE closure |
| **Phase 5** | Matrix builds + cache | Pipeline speed optimization |

---

## PHASE 1 — OIDC Setup + Basic Deploy Pipeline

**What you build:** A GitHub Actions workflow that builds a Docker image, pushes to ECR, and deploys to EKS — triggered by every push to `main`. AWS credentials come from OIDC, not stored secrets.

**Time:** ~20 minutes (cluster prereq ~15 min, AWS setup ~5 min, first deploy ~3 min)

---

### STEP 1 — Verify Tools and AWS Connectivity
Confirm CLI tools and AWS session before creating any infrastructure.

```bash
aws --version
eksctl version
kubectl version --client --short
gh --version    # GitHub CLI — needed to set repo variables

aws sts get-caller-identity

# OUTPUT
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:session",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:assumed-role/..."
}
```

---

### STEP 2 — Create the EKS Cluster
Standard managed node group cluster — shared with other tutorials.

```bash
./tutorials/cluster-managed-node-group/create.sh

# Skip this step if cluster is already running
kubectl get nodes
```

---

### STEP 3 — Explore Phase 1 Structure
Understand what the setup script creates and what the workflow does.

```bash
tree cicd-and-pipelines/github-actions-eks/phase1-basic/

# OUTPUT
phase1-basic/
├── setup.sh           ← creates OIDC provider, IAM role, ECR repo in AWS
├── teardown.sh        ← removes all AWS prereqs
├── workflow/
│   └── deploy.yml     ← GitHub Actions workflow (copy to .github/workflows/)
├── app/
│   ├── app.py         ← simple Flask app (returns hostname + version)
│   ├── requirements.txt
│   └── Dockerfile
└── k8s/
    ├── namespace.yaml
    ├── deployment.yaml    ← ${ECR_REGISTRY}/hello-eks:${IMAGE_TAG}
    └── service.yaml
```

---

### STEP 4 — Create AWS Prerequisites
`setup.sh` creates the OIDC provider, IAM role, ECR repository, and prints the GitHub repo variables you need to set.

```bash
# Set your GitHub org/repo
export GITHUB_ORG=suvmaha
export GITHUB_REPO=amazon-eks-tutorials

./cicd-and-pipelines/github-actions-eks/phase1-basic/setup.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  EKS cluster ml-serving-cluster is ACTIVE
  ✅  kubectl connected — 2 node(s) reachable

╔══════════════════════════════════════════════════════════════════════╗
║         GitHub Actions → EKS — Phase 1: OIDC + Deploy              ║
╠══════════════════════════════════════════════════════════════════════╣
║  GitHub repo   : suvmaha/amazon-eks-tutorials                       ║
║  AWS account   : 123456789012                                       ║
║  Region        : us-east-1                                          ║
║  IAM role      : github-actions-eks-deploy                          ║
║  ECR repo      : hello-eks                                          ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Create OIDC provider ────────────────────────────────────────────
  Created: arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com

── STEP 2: Create IAM role with trust policy ───────────────────────────────
  Role ARN: arn:aws:iam::123456789012:role/github-actions-eks-deploy
  Trusted:  repo:suvmaha/amazon-eks-tutorials:ref:refs/heads/main

── STEP 3: Attach policies ─────────────────────────────────────────────────
  AmazonEC2ContainerRegistryPowerUser attached.
  Custom EKS deploy policy attached.

── STEP 4: Create ECR repository ───────────────────────────────────────────
  Created: 123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-eks

── STEP 5: Set GitHub repo variables ───────────────────────────────────────
  Set: AWS_ROLE_ARN
  Set: AWS_REGION
  Set: EKS_CLUSTER_NAME
  Set: ECR_REGISTRY

── STEP 6: Install workflow ─────────────────────────────────────────────────
  Copied: workflow/deploy.yml → .github/workflows/eks-deploy.yml

Setup complete. Trigger a deploy:
  git add .github/workflows/eks-deploy.yml && git commit -m "ci: add EKS deploy workflow" && git push
```

---

### STEP 5 — Review the Workflow
Understand what the GitHub Actions workflow does before it runs.

```bash
cat cicd-and-pipelines/github-actions-eks/phase1-basic/workflow/deploy.yml
```

Key sections:
```
permissions:
  id-token: write    ← required for OIDC — allows the job to request an OIDC token
  contents: read

steps:
  configure-aws-credentials   ← exchanges OIDC token for temporary AWS creds (15 min TTL)
  amazon-ecr-login            ← authenticates Docker to ECR using those creds
  docker build + push         ← image tagged with git SHA (not "latest")
  aws eks update-kubeconfig   ← pulls kubeconfig for the cluster
  envsubst | kubectl apply    ← injects ECR_REGISTRY + IMAGE_TAG, applies manifests
  kubectl rollout status      ← waits for pods to be Ready before job succeeds
```

---

### STEP 6 — Trigger the First Deploy
Push a commit to main. Watch the workflow run.

```bash
# Push the workflow file (setup.sh already copied it)
git add .github/workflows/eks-deploy.yml
git commit -m "ci: add EKS deploy workflow — Phase 1"
git push origin main

# Watch the workflow in GitHub Actions UI, or:
gh run watch

# OUTPUT (GitHub Actions log)
Run aws-actions/configure-aws-credentials@v4
  Assuming role: arn:aws:iam::123456789012:role/github-actions-eks-deploy
  AWS credentials configured via OIDC.

Run aws-actions/amazon-ecr-login@v2
  Login Succeeded

docker build -t 123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-eks:a1b2c3d ...
  [+] Building 38.2s FINISHED

docker push ... hello-eks:a1b2c3d4e5f6...
  latest: digest: sha256:abc123...

aws eks update-kubeconfig --name ml-serving-cluster --region us-east-1

envsubst | kubectl apply -f -
  namespace/hello-eks created
  deployment.apps/hello-eks created
  service/v1 created

kubectl rollout status deployment/hello-eks -n hello-eks --timeout=120s
  deployment "hello-eks" successfully rolled out
```

---

### STEP 7 — Verify the Deployment
Confirm pods are running and the app is reachable.

```bash
kubectl get pods -n hello-eks -o wide

# OUTPUT
NAME                        READY   STATUS    NODE
hello-eks-7d8f9c-kxp2m     1/1     Running   ip-192-168-64-12.ec2.internal
hello-eks-7d8f9c-rnt9q     1/1     Running   ip-192-168-96-47.ec2.internal

# Port-forward and test
kubectl port-forward svc/hello-eks 8080:80 -n hello-eks &

curl -s http://localhost:8080/ | python3 -m json.tool
# {
#   "message": "Hello from EKS",
#   "hostname": "hello-eks-7d8f9c-kxp2m",
#   "version": "v1"
# }

# Make a change — update APP_VERSION in deployment.yaml, push, watch workflow re-deploy
kill %1
```

---

### STEP 8 — Observe the OIDC Flow
No stored AWS keys anywhere. Confirm the trust model worked as designed.

```bash
# See that the IAM role has no access keys — OIDC only
aws iam list-access-keys --user-name github-actions-eks-deploy 2>&1
# NoSuchEntityException: user does not exist (it's a role, not a user)

# View the role's trust policy — locked to your repo and branch
aws iam get-role --role-name github-actions-eks-deploy \
  --query 'Role.AssumeRolePolicyDocument' | python3 -m json.tool

# See the deployment in git history — every deploy is a commit
git log --oneline -5
```

---

### STEP 9 — Tear Down
Remove AWS prereqs. The cluster stays for other tutorials.

```bash
./cicd-and-pipelines/github-actions-eks/phase1-basic/teardown.sh

# OUTPUT
── STEP 1: Delete ECR repository ───────────────────────────────────────────
  ✅  hello-eks deleted

── STEP 2: Detach and delete IAM role ──────────────────────────────────────
  ✅  github-actions-eks-deploy deleted

── STEP 3: Delete OIDC provider ────────────────────────────────────────────
  ✅  OIDC provider deleted

── STEP 4: Remove workflow file ────────────────────────────────────────────
  ✅  .github/workflows/eks-deploy.yml removed

── STEP 5: Delete hello-eks namespace ──────────────────────────────────────
  ✅  Namespace hello-eks deleted
```

---

**Next:** Phase 2 — multi-environment promotion: the same workflow promotes from dev → staging → prod with approval gates between environments.
