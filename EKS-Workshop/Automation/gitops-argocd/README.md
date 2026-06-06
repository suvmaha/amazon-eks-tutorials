# EKS Workshop — GitOps with Argo CD

**Workshop source:** https://www.eksworkshop.com/docs/automation/gitops/argocd  
**Local source:** `eks-workshop-v2/website/docs/automation/gitops/argocd/`

This folder captures the EKS Workshop Argo CD lab exactly as the workshop runs it. No adaptations.

---

## What this lab covers

| Section | What happens |
|---|---|
| Installing Argo CD | Helm install argo-cd 7.9.1, LoadBalancer (NLB) for UI |
| Git repository | Clone CodeCommit repo, initial commit, register with Argo CD via SSH |
| Deploying an application | Argo CD Application CRD → syncs Helm chart from Git → deploys UI |
| Updating an application | Push values.yaml change → Argo CD auto-detects → scales to 3 replicas |
| App of Apps | Parent Application manages child Application CRDs for all 5 services |

---

## Prerequisites set by `prepare-environment automation/gitops/argocd`

The workshop's `prepare-environment` command does the following. In your own account, complete these before running the playbook:

1. **AWS Load Balancer Controller** installed in the cluster (required for NLB service type)
2. **EBS CSI driver** addon enabled on the cluster
3. **CodeCommit repository** named `<cluster-id>-argocd` created
4. **SSH key** for CodeCommit uploaded to IAM, PEM file at `~/.ssh/gitops_ssh.pem`
5. **Environment variables** set:
   ```bash
   export ARGOCD_CHART_VERSION="7.9.1"
   export GITOPS_REPO_URL_ARGOCD="ssh://<ssh-key-id>@git-codecommit.<region>.amazonaws.com/v1/repos/<cluster-id>-argocd"
   export INBOUND_CIDRS="<your-cidr>/32"   # restricts NLB source; use 0.0.0.0/0 for open lab
   ```

---

## Folder structure

```
gitops-argocd/
├── README.md
├── playbook.md                    ← run the entire lab from here
├── Chart.yaml                     ← UI wrapper Helm chart (copied to Git repo in step 5)
├── install/
│   └── values.yaml                ← ArgoCD Helm install values (NLB, replicas, timeout)
├── update-application/
│   └── values.yaml                ← ui.replicaCount: 3 (pushed in step 7)
├── app-charts/                    ← per-service wrapper charts (copied to Git repo in step 9)
│   ├── ui/Chart.yaml
│   ├── carts/Chart.yaml
│   ├── catalog/Chart.yaml
│   ├── checkout/Chart.yaml
│   └── orders/Chart.yaml
└── app-of-apps/                   ← parent Helm chart that generates child Applications
    ├── Chart.yaml
    ├── values.yaml                ← repoURL = ${GITOPS_REPO_URL_ARGOCD}
    └── templates/
        ├── _application.yaml      ← Helm template loop generating Application CRDs
        └── application.yaml      ← entry point calling the template
```

---

## How the GitOps repo is used

The CodeCommit repo (`~/environment/argocd/`) is the GitOps source of truth. The workshop builds it incrementally:

```
Step 5:  argocd/ui/Chart.yaml              ← UI Helm wrapper
Step 7:  argocd/ui/values.yaml             ← scale to 3 replicas
Step 8:  argocd/app-of-apps/               ← App of Apps Helm chart
Step 9:  argocd/{carts,catalog,checkout,orders}/Chart.yaml
```

Argo CD polls this repo every 5 seconds (`timeout.reconciliation: 5s`) and reconciles any drift.
