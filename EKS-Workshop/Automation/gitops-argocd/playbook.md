# Playbook — GitOps with Argo CD

**Source:** EKS Workshop — https://www.eksworkshop.com/docs/automation/gitops/argocd  
**Estimated time:** ~60 minutes total (cluster ~20 min + NLB ~10 min + lab ~30 min)

This playbook runs the complete Argo CD lab from the EKS Workshop — in order, end to end.  
The cluster stack is built piece by piece using shared scripts from `EKS-Workshop/cluster/` and `EKS-Workshop/addons/`.

---

## STEP 0 — Build the cluster stack

This replaces what the workshop calls `prepare-environment automation/gitops/argocd`.  
Run each script in order. Each is independently reversible.

**0a — Create the EKS cluster (managed node group, ~20 min)**

```bash
# Default cluster name: eks-workshop. Override with EKS_CLUSTER_NAME=my-name
EKS-Workshop/cluster/managed-node-group/create.sh
```

What it creates: EKS 1.35 cluster, 3x m5.large managed node group, EBS CSI addon, OIDC provider.

**0b — Install AWS Load Balancer Controller**

```bash
# Requires the cluster from 0a to be ACTIVE
EKS-Workshop/addons/aws-lbc/install.sh
```

What it creates: IAM policy, IRSA service account, Helm install of aws-load-balancer-controller.  
Why needed: ArgoCD server service type is `LoadBalancer` → NLB provisioned by LBC.

**0c — Set up CodeCommit GitOps repository**

```bash
EKS-Workshop/addons/codecommit/setup.sh
```

What it creates: CodeCommit repo `<cluster-name>-argocd`, RSA SSH key pair, uploads public key to IAM, writes private key to `~/.ssh/gitops_ssh.pem`.

At the end the script prints env vars — **copy and run the export block** before continuing:

```bash
export ARGOCD_CHART_VERSION="7.9.1"
export GITOPS_REPO_URL_ARGOCD="ssh://<key-id>@git-codecommit.<region>.amazonaws.com/v1/repos/<cluster-name>-argocd"
export INBOUND_CIDRS="0.0.0.0/0"
export AWS_REGION="us-east-1"
```

**Verify the full stack before proceeding**

```bash
# Cluster active
kubectl get nodes

# LBC running
kubectl get deployment aws-load-balancer-controller -n kube-system

# EBS CSI running
kubectl get pods -n kube-system | grep ebs-csi

# Env vars set
echo $ARGOCD_CHART_VERSION
echo $GITOPS_REPO_URL_ARGOCD
```

---

## Teardown order (reverse of build)

When done with the lab, tear down in reverse:

```bash
# 1. ArgoCD cleanup (STEP 11 in this playbook)
# 2. Remove CodeCommit
EKS-Workshop/addons/codecommit/teardown.sh

# 3. Remove LBC
EKS-Workshop/addons/aws-lbc/uninstall.sh

# 4. Delete cluster
EKS-Workshop/cluster/managed-node-group/destroy.sh
```

---

## Before you begin (post-stack verification)

Confirm the stack is ready:

```bash
# Verify AWS LBC is installed
kubectl get deployment aws-load-balancer-controller -n kube-system

# Verify EBS CSI driver is present
kubectl get daemonset ebs-csi-node -n kube-system

# Verify env vars are set
echo $ARGOCD_CHART_VERSION       # should be 7.9.1
echo $GITOPS_REPO_URL_ARGOCD     # should be ssh://...@git-codecommit...
echo $INBOUND_CIDRS              # your CIDR or 0.0.0.0/0
```

---

## STEP 1 — Install Argo CD

**Install ArgoCD 7.9.1 via Helm with a LoadBalancer service (NLB)**

```bash
helm repo add argo-cd https://argoproj.github.io/argo-helm
ESCAPED_CIDRS="${INBOUND_CIDRS//,/\\,}"
helm upgrade --install argocd argo-cd/argo-cd --version "${ARGOCD_CHART_VERSION}" \
  --namespace "argocd" --create-namespace \
  --values ~/environment/eks-workshop/modules/automation/gitops/argocd/values.yaml \
  --set "server.service.annotations.service\.beta\.kubernetes\.io/load-balancer-source-ranges=$ESCAPED_CIDRS" \
  --wait
```

> In this repo the values file is at `install/values.yaml`. Workshop participants use the path shown above.  
> Expected output: `STATUS: deployed`

---

## STEP 2 — Get the Argo CD URL and wait for the NLB

**Retrieve the NLB hostname — the LB takes 3-5 minutes to provision**

```bash
export ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname')
echo "Argo CD URL: https://$ARGOCD_SERVER"
```

**Wait until Argo CD responds (up to 10 minutes)**

```bash
curl --head -X GET --retry 20 --retry-all-errors --retry-delay 15 \
  --connect-timeout 5 --max-time 10 -k \
  https://$ARGOCD_SERVER
```

Expected final output:
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
```

---

## STEP 3 — Retrieve admin password and log in

**Get the auto-generated admin password**

```bash
export ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD admin password: $ARGOCD_PWD"
```

**Log in with the argocd CLI**

```bash
argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PWD --insecure
```

Expected output:
```
'admin:login' logged in successfully
Context '...elb.amazonaws.com' updated
```

---

## STEP 4 — Set up the CodeCommit Git repository

**Add CodeCommit to known hosts to suppress SSH warnings**

```bash
ssh-keyscan -H git-codecommit.${AWS_REGION}.amazonaws.com &> ~/.ssh/known_hosts
```

**Configure Git identity**

```bash
git config --global user.email "you@eksworkshop.com"
git config --global user.name "Your Name"
```

**Clone the CodeCommit repo and push an initial commit to main**

```bash
git clone $GITOPS_REPO_URL_ARGOCD ~/environment/argocd
git -C ~/environment/argocd checkout -b main
touch ~/environment/argocd/.gitkeep
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Initial commit"
git -C ~/environment/argocd push --set-upstream origin main
```

Expected output:
```
Switched to a new branch 'main'
[main (root-commit) ...] Initial commit
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

---

## STEP 5 — Register the Git repo with Argo CD

**Provide Argo CD with SSH access to the CodeCommit repo**

```bash
argocd repo add $GITOPS_REPO_URL_ARGOCD \
  --ssh-private-key-path ${HOME}/.ssh/gitops_ssh.pem \
  --insecure-ignore-host-key --upsert --name git-repo
```

Expected output:
```
Repository 'ssh://...' added
```

---

## STEP 6 — Remove existing sample app deployments

**The workshop migrates the UI from kubectl to Argo CD — remove namespaces first**

```bash
kubectl delete namespace -l app.kubernetes.io/created-by=eks-workshop
```

Expected output:
```
namespace "carts" deleted
namespace "catalog" deleted
namespace "checkout" deleted
namespace "orders" deleted
namespace "other" deleted
namespace "ui" deleted
```

---

## STEP 7 — Deploy the UI component via Argo CD

**Copy the UI Helm wrapper chart to the GitOps repo**

```bash
mkdir -p ~/environment/argocd/ui
cp ~/environment/eks-workshop/modules/automation/gitops/argocd/Chart.yaml \
  ~/environment/argocd/ui
```

> The `Chart.yaml` wraps `retail-store-sample-ui-chart:1.2.1` from `oci://public.ecr.aws/aws-containers`

**Verify the repo structure**

```bash
tree ~/environment/argocd
```

Expected:
```
`-- ui
    `-- Chart.yaml
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding the UI service"
git -C ~/environment/argocd push
```

**Create the Argo CD Application (manual sync policy)**

```bash
argocd app create ui --repo $GITOPS_REPO_URL_ARGOCD \
  --path ui --dest-server https://kubernetes.default.svc \
  --dest-namespace ui --sync-option CreateNamespace=true
```

Expected output:
```
application 'ui' created
```

**Verify the application exists (will show OutOfSync — expected)**

```bash
argocd app list
```

```
NAME         CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY
argocd/ui    https://kubernetes.default.svc  ui         default  OutOfSync  Missing  Manual
```

**Manually trigger sync**

```bash
argocd app sync ui
argocd app wait ui --timeout 120
```

**Verify the deployment**

```bash
kubectl get deployment -n ui ui
kubectl get pod -n ui
```

Expected:
```
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     1/1     1            1           61s
```

---

## STEP 8 — Update the application via GitOps

**Create a values.yaml to scale UI replicas from 1 to 3**

```bash
cp ~/environment/eks-workshop/modules/automation/gitops/argocd/update-application/values.yaml \
  ~/environment/argocd/ui
```

> This file sets `ui.replicaCount: 3`

**Verify the repo structure**

```bash
tree ~/environment/argocd
```

Expected:
```
`-- ui
    |-- Chart.yaml
    `-- values.yaml
```

**Commit and push the change**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Update UI service replicas"
git -C ~/environment/argocd push
```

**Sync the application**

```bash
argocd app sync ui
argocd app wait ui --timeout 120
```

**Verify 3 replicas are running**

```bash
kubectl get deployment -n ui ui
kubectl get pod -n ui
```

Expected:
```
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     3/3     3            3           3m33s

NAME                  READY   STATUS    RESTARTS   AGE
ui-6d5bb7b95-hzmgp   1/1     Running   0          61s
ui-6d5bb7b95-j28ww   1/1     Running   0          61s
ui-6d5bb7b95-rjfxd   1/1     Running   0          3m34s
```

---

## STEP 9 — Set up App of Apps

**Copy the App of Apps Helm chart to the GitOps repo**

```bash
cp -R ~/environment/eks-workshop/modules/automation/gitops/argocd/app-of-apps ~/environment/argocd/
```

**Patch the repoURL in values.yaml with the CodeCommit repo URL**

```bash
yq -i ".spec.source.repoURL = env(GITOPS_REPO_URL_ARGOCD)" ~/environment/argocd/app-of-apps/values.yaml
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding App of Apps"
git -C ~/environment/argocd push
```

**Create the parent Argo CD Application with automated sync**

```bash
argocd app create apps --repo $GITOPS_REPO_URL_ARGOCD \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated --self-heal --auto-prune \
  --set-finalizer \
  --upsert \
  --path app-of-apps
argocd app wait apps --timeout 120
```

Expected output:
```
application 'apps' created
```

> At this point in the Argo CD UI, `apps` syncs but child apps (carts, catalog, checkout, orders) show "Unknown" — their Git paths don't exist yet.

---

## STEP 10 — Add all workload charts

**Copy the per-service Helm wrapper charts to the GitOps repo**

```bash
cp -R ~/environment/eks-workshop/modules/automation/gitops/argocd/app-charts/* \
  ~/environment/argocd/
```

**Verify the full repo structure**

```bash
tree ~/environment/argocd
```

Expected:
```
.
|-- app-of-apps/
|   |-- Chart.yaml
|   |-- templates/
|   |   |-- _application.yaml
|   |   `-- application.yaml
|   `-- values.yaml
|-- carts/
|   `-- Chart.yaml
|-- catalog/
|   `-- Chart.yaml
|-- checkout/
|   `-- Chart.yaml
|-- orders/
|   `-- Chart.yaml
`-- ui/
    |-- Chart.yaml
    `-- values.yaml
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding apps charts"
git -C ~/environment/argocd push
```

**Sync the parent apps Application**

```bash
argocd app sync apps
argocd app wait -l app.kubernetes.io/created-by=eks-workshop
```

**Verify all namespaces are present**

```bash
kubectl get namespaces
```

Expected:
```
NAME              STATUS   AGE
argocd            Active   18m
carts             Active   28s
catalog           Active   28s
checkout          Active   28s
default           Active   8h
kube-node-lease   Active   8h
kube-public       Active   8h
kube-system       Active   8h
orders            Active   28s
ui                Active   11m
```

**Spot-check one workload**

```bash
kubectl get deployment -n carts
```

Expected:
```
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
carts   1/1     1            1           46s
```

---

## STEP 11 — Cleanup

**Remove the GitOps working directory**

```bash
rm -rf ~/environment/argocd
```

**Uninstall Argo CD**

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd --ignore-not-found=true
```

**Delete all app namespaces created by this lab**

```bash
kubectl delete namespace -l app.kubernetes.io/created-by=eks-workshop
```

Expected:
```
namespace "carts" deleted
namespace "catalog" deleted
namespace "checkout" deleted
namespace "orders" deleted
namespace "ui" deleted
```
