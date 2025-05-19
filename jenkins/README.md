# 🚀 2060.io Deployment Strategy – Detailed Guide

This document describes the detailed procedure to deploy components of the **2060.io** infrastructure. It covers both automated deployments using **Jenkins with Blue-Green strategy** and manual deployments via **Helm**. The goal is to standardize and clarify every step to ensure safe and reliable deployments.

---

## 📦 Pre-requisites

Before starting any deployment, ensure the following:

### 🔐 Access Requirements

- Access to the relevant GitHub deployment repositories (e.g. [2060-core-deploy-dev])
- Access to the appropriate **Jenkins** instance (e.g. <https://jenkins.dev.2060.io>) with permissions to execute deployment jobs
- Access to **Kubernetes cluster**
- DockerHub read/push credentials (as needed)

### 💻 Tools Needed (Local Environment)

Only required for **manual Helm deployments**:

- `kubectl`
- `helm` v3+
- Valid `KUBECONFIG` file
- `git` (to fetch the latest deployment chart)

---

## Best Practices for a New Deployment

### Namespace Handling

- If a new namespace is required, it is recommended to define it in the deployment files.  
- For existing namespaces, exclude them from `deployment.yaml` to prevent conflicts.  
- *(Recommended)* Use a [`pre-requisites.yaml`](./example/pre-requisites.yaml) file to define the necessary configurations for setting up namespaces and permissions. This approach ensures consistency across deployments and can be adjusted based on project requirements.

#### Recommended Configuration with `pre-requisites.yaml`  

The `pre-requisites.yaml` file should include:  

- **Namespace manifest**  
- **ServiceAccount manifest**  
- **Role manifest** with the necessary permissions to create resources such as apps, ingress, etc.  
- **Secret registry-credentials** to allow the creation of Docker containers within the corresponding namespace.  

This file should be customized as needed and applied manually using:  

```bash
kubectl apply -f pre-requisites.yaml
```

It is recommended to review and adapt the configurations according to the specific requirements of each repository.

### Helm `values.yaml` Requirements

The `values.yaml` file must include at least the following fields for Blue/Green deployments:

```yaml
# Blue / Green Deployment
name: example
namespace: example
replicas: 1
# blue / green
deployment:
  color: blue
  first: true
```

### Deployment Files Configuration

Use the `if-end` clause for everything except clause for everything except StatefulSets or Deployments, ensuring that the Jenkins file creates pods only for Blue/Green integration:

```yaml
{{- if .Values.deployment.first }}
{{- end }}
```

For more details on Blue/Green deployment strategies, refer to [Red Hat's guide](https://www.redhat.com/en/topics/devops/what-is-blue-green-deployment).

### Example Project

You can find a sample project illustrating the expected structure [here](./example/helm/).

## 🛠️ Create a New Pipeline

To create a new pipeline, follow these steps:

1. **Ensure the repository structure**:
   - The repository should have the following structure:

     ```text
     deployments/
     ├── projectA/
     ├── projectB/
     ├── projectC/
     Jenkinsfile
     .github/
     └── workflows/
         └── deploy.yml
     ```

   - The GitHub Actions workflow (`deploy.yml`) is used to trigger Jenkins deployments and must declare the following repository secrets:

     ```yaml
     secrets:
       JENKINS_URL: "https://jenkins.dev.2060.io/"
       JENKINS_TOKEN: "<token_generated_by_jenkins_pipeline>"
       OAUTH_TOKEN: "<your_personal_access_token>"
     ```

2. **Enable Pipeline Parameterization**:
   - Configure the pipeline to allow execution parameterization using the string parameter `PROJECT`.

3. **Configure Remote Execution Triggers**:
   - Allow remote executions (e.g., from scripts) as a trigger.
   - Create a new identifier that corresponds to the `JENKINS_TOKEN` secret in GitHub.

4. **Configure the Pipeline Source**:
   - In Jenkins, select **"Pipeline script from SCM"**.
   - Set the GitHub repository URL.
   - If the repository is private, ensure credentials are added.

5. **Validate the Pipeline**:
   - Check pipeline syntax before committing.
   - Run a test job in Jenkins.

> Once a pipeline is created, you can clone/copy the existing one for similar projects.

---

## 🏷️ Configure Deployment Versioning

1. Modify your deployment process to accept a **version parameter** (e.g. see step 2 in the new pipeline section). This ensures that the pipeline deploys a specified version instead of relying on Jenkins' auto-generated versioning.
2. Update the Jenkins pipeline configuration to support the new versioning mechanism.
3. Use the following configuration file to automate the versioning process:

```json
{
  "packages": {
    "deployments/unic-id": {
      "changelog-path": "CHANGELOG.md",
      "release-type": "helm"
    },
    "deployments/unic-id-verifier": {
      "changelog-path": "CHANGELOG.md",
      "release-type": "helm"
    }
  },
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "include-component-in-tag": true,
  "include-v-in-tag": false,
  "tag-separator": "-",
  "separate-pull-requests": true,
  "pull-request-title-pattern": "chore(release):${scope} ${component} ${version}",
  "release-search-depth": 100,
  "commit-search-depth": 100,
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

4. When initializing a component for the first time, use the `bootstrap` command.
5. For more examples, check the [`examples`](/jenkins/example/release-please/) directory.

---

## 🗃️ PVC Migration for Stateful Deployments

In Kubernetes, PVCs do not store data themselves but act as a link to the Persistent Volumes (PVs). If you need to migrate or preserve existing storage when deploying new versions, follow these steps.

### 🧭 Steps for Migration

1. **Check the PVCs in the target namespace**

```sh
kubectl get pvc --namespace=demos-dev
```

1. **Retrieve PV details**

```sh
kubectl describe pv <pv-name>
```

1. **Update PV reclaim policy to Retain**

```sh
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

1. **Delete the existing PVC**

Ensure the associated service is stopped first.

```sh
kubectl delete pvc <pvc-name> -n <namespace>
```

1. **Remove claimRef from the PV**

```sh
kubectl patch pv <pv-name> --type=json -p='[{"op": "remove", "path": "/spec/claimRef"}]'
```

1. **Deploy the new Helm chart**

If you're creating a new PVC, no volume name is needed.

1. **Reuse existing PV by setting `volumeName` in the PVC**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Values.name }}-pg-pv-main
  namespace: {{ .Values.namespace }}
  labels:
    app: {{ .Values.name }}
    color: {{ .Values.deployment.color }}
  annotations:
    helm.sh/resource-policy: keep
spec:
  accessModes:
    - "ReadWriteOnce"
  storageClassName: csi-cinder-classic
  volumeName: <existing-pv-name>
  resources:
    requests:
      storage: 1Gi
```

✅ This binds the PVC to a retained PV if compatible.

## 🔄 Blue-Green Deployment via Jenkins

This strategy allows you to deploy a new version in parallel ("blue" or "green") and switch traffic only when the deployment is verified.

### 📘 Naming Convention

All Helm releases **must be prefixed with `2060-`**, followed by the service name (which must match the folder name under `deployments/`) and the color suffix (either `-blue` or `-green`).

Example: `2060-webrtc-server-blue`

---

### 🚀 Jenkins Blue-Green Deployment Steps

Before starting, ensure that a Jenkins pipeline is already configured for the service you intend to deploy. Each service must have a corresponding job in Jenkins to execute the deployment process.

If your service does not yet have a pipeline, follow the steps in the [Create a New Pipeline](./README.md#5-create-a-new-pipeline) section of the Jenkins guide.

![Deployment Workflow Diagram](./docs/diagrams/deployment_workflow.png)

1. **Check the current live color**
   - Run `helm list -n <namespace>` or check Jenkins dashboard to see if `-blue` or `-green` is active

2. **Prepare changes**
   - Navigate to `deployments/<service-name>`
   - Update `Chart.yaml` with the new version and adjust `values.yaml` if needed

3. **Create a feature branch**

   ```bash
   git checkout -b feat/update-<service>-vX.Y.Z
   ```

4. **Commit your changes**

   ```bash
   git commit -am "feat: bump <service> to vX.Y.Z"
   ```

5. **Open a Pull Request to `main`**
   - Provide a meaningful title and description
   - Include release name and namespace for clarity

6. **After approval:**
   - GitHub Actions triggers Jenkins with the deployment parameters
   - Jenkins installs the new release with the opposite color (e.g., `green` if `blue` is active)

7. **Check Jenkins status**
   - Ensure the job completes successfully
   - Validate endpoint and logs for the new release

8. **Switch traffic**

   - Update Ingress or service selectors to route traffic to the new release.

   This step is triggered manually in Jenkins **only if the deployment stage completes successfully**:

   - In the classic Jenkins UI:  
     Scroll to the pipeline log and click the **"Approve and Switch Traffic"** button when prompted.  
     Alternatively, click **"Abort"** to cancel the switch if something needs to be reviewed.

   - In Blue Ocean:  
     Locate the `Switch Traffic` stage in the visual pipeline and click **"Approve and Switch Traffic"** to continue.

   This manual approval step will **not appear** if the pipeline fails before reaching the traffic switch stage.

---

## ⚙️ Manual Deployment via Helm

Manual deployments can be done directly using Helm when needed.

### ✅ Install a Service

```bash
helm upgrade --install 2060-<service>-<color> ./deployments/<service> --namespace <namespace>  --wait
```

Example:

```bash
helm upgrade --install 2060-webrtc-server-blue ./deployments/webrtc-server --namespace demos --wait
```

### 🧹 Uninstall a Service

```bash
helm uninstall 2060-<service>-<color> --namespace <namespace>
```

---

## 🧪 Post-Deployment Validation

1. Verify that pods are running:

   ```bash
   kubectl get pods -n <namespace>
   ```

2. Test service endpoints:
   - Use `kubectl port-forward`, or
   - Check configured domain via Ingress

3. View logs:

   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

4. Check ConfigMaps/Secrets mounting:

   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

---

## 🛠️ Common Troubleshooting

| Issue | Solution |
|-------|----------|
| Jenkins job fails | Verify webhook trigger and credentials |
| Helm error (conflict) | Ensure no existing release with same name |
| Pods crashloop | Inspect logs and environment configs |

---

## ✅ Best Practices Checklist

- [ ] All release names follow the format `2060-<service>-<blue|green>`
- [ ] Docker image is properly tagged and available in DockerHub
- [ ] `Chart.yaml` and `values.yaml` reflect the correct version and configuration
- [ ] A feature branch is created for every deployment change
- [ ] Pull Request clearly documents what is being deployed (version, namespace, service)
- [ ] Jenkins logs are reviewed after deployment
- [ ] Helm releases are cleaned up after switching production traffic
- [ ] Use `--wait` flag in Helm to ensure readiness before traffic switch (manual only)
- [ ] Keep Ingress and Service selectors aligned with active color deployment
- [ ] Monitor application after switch to detect regressions early

---

🎉 **Happy Deploying!**
