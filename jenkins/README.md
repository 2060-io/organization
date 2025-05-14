# 2060 DevOps Deployment Configuration

## Configuring and Customizing Jenkins

To configure Jenkins with the necessary plugins and settings tailored to our needs, follow these steps:

Deployment configuration files can be found in the 2060 DevOps repository:
[2060 DevOps - Jenkins](https://github.com/2060-io/devops/tree/main/jenkins)

> **Note:** You must create a separate pipeline for each new project, ensuring that the project name matches the pipeline name, as it serves as the unique identifier for deployment.

### 1. Retrieve the Initial Admin Password

Run the following command to get the initial admin password from the pod logs:

```sh
kubectl get pods --namespace=devops-tools
kubectl exec -it `<pod>` -- cat /var/jenkins_home/secrets/initialAdminPassword -n devops-tools
```

Replace `<pod>` with the actual pod name where Jenkins is deployed.

### 2. Ensure the following plugins are installed

In addition to the recommended plugins, install the following:

- **GitHub** (repository integration)
- **GitHub Authentication Plugin** (OAuth-based authentication)
- **GitHub Branch Source Plugin** (multi-branch pipeline support)
- **Blue Ocean** (enhanced pipeline UI)
- **Environment Injector** (manage environment variables)
- **Kubernetes** (direct cluster integration)
- **Pipeline** (Jenkins pipeline support)

You can also install the necessary plugins by uploading a `plugins.txt` file. This file should be located in the Jenkins home directory and can be loaded by navigating to **Manage Jenkins > Plugins** and selecting **Advanced Settings**.

### 3. Add GitHub Credentials

To add GitHub credentials

- Go to **Manage Jenkins > Credentials**.
- Under the appropriate scope, add a **GitHub Personal Access Token**.

### 4. Best Practices for a New Deployment Repository

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

### 5. Create a New Pipeline

To create a new pipeline, follow these steps:

1. **Ensure the repository structure**:
   - The repository should have the following structure:

     ```text
     deployments/  # Each project should have its own folder here
     ├── projectA/
     ├── projectB/
     ├── projectC/
     Jenkinsfile   # Defines the Jenkins pipeline
     .github/
     ├── workflows/
     │   ├── deploy.yml  # GitHub Actions workflow for deployment
     ```

   - The GitHub Actions workflow [(`deploy.yml`)](./deploy.yml) is used to trigger Jenkins deployments and must declare the following repository variables:

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
   - In Jenkins, select the option **"Pipeline script from SCM"**.
   - Set the repository URL from GitHub.
   - If the repository is private, ensure that the necessary credentials (Personal Access Token) are added for authentication.

5. **Validate the Pipeline**:
   - Ensure that the pipeline syntax is correct before committing changes.
   - Run a test execution in Jenkins to verify functionality.

By following these steps, you ensure a consistent and efficient deployment workflow across all projects.

> **Note:** Once you have one pipeline created, you can copy the existing pipeline and create a new one based on it. The setup should work without any problems.

### 6. (Optional & Recommended) Configure GitHub OAuth for Authentication

#### GitHub OAuth Setup

1. Navigate to [GitHub Developer Settings](https://github.com/settings/developers) and create a new **OAuth App**.
2. Use the following values:
   - **Homepage URL:** `https://jenkins.dev.2060.io/`
   - **Authorization Callback URL:** `https://jenkins.dev.2060.io/securityRealm/finishLogin`
3. Generate a new **Client Secret** and take note of the **Client ID** and **Client Secret**.

#### Configure Jenkins Authentication

1. Go to **Manage Jenkins > Configure Global Security**.
2. In the **Authentication** section, change the method from **Jenkins' own user database** to **GitHub Authentication Plugin**.
3. Fill in the **Client ID** and **Client Secret** obtained from GitHub.
4. Save the changes.

With this setup, Jenkins will authenticate users via GitHub, simplifying access management and security.

### 7. (Optional) Configure a GitHub Webhook

- In your GitHub repository, go to **Settings > Webhooks**.
- Add a new webhook pointing to Jenkins (`https://jenkins.dev.2060.io/github-webhook/`).
- Use **application/json** as the content type.
- Select **Just the push event** for triggering builds.

> **Note:** This is the traditional method, but it is **not recommended** for this implementation, as deployments in 2060 are managed through GitHub Actions.

### 8. (Optional) Enable Kubernetes Cloud

- Navigate to **Manage Jenkins > Clouds**.
- Configure Kubernetes as a cloud provider to allow Jenkins to create additional pods dynamically.

> **Note:** it is **not recommended** for this implementation, as deployments in 2060 are managed through a custom image.

### 9. (Optional & Recommended) Configure Versioning with Release Please

#### GitHub Actions Versioning Setup

1. To manage versioning, we will use [Release Please](https://github.com/googleapis/release-please), which automates releases using conventional commits.
2. Modify the `deploy.yaml` workflow file to include the following `release-charts` section:

   ```yaml
   release-charts:
     needs: detect-changes
     if: ${{ needs.detect-changes.outputs.matrix != '{"project":[]}' }}
     runs-on: ubuntu-latest
     strategy:
       matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
     outputs:
       matrix: ${{ needs.detect-changes.outputs.matrix }}
       version: ${{ steps.get-version.outputs.version }}
     steps:
       - name: Release Charts
         id: release
         uses: googleapis/release-please-action@v4
         with:
           config-file: release-please-config.json
           manifest-file: .release-please-manifest.json
           token: ${{ secrets.GITHUB_TOKEN }}
       - name: Print release outputs for debugging
         continue-on-error: true
         run: echo ${{ toJson(steps.release.outputs) }}
       - name: Get version from manifest
         id: get-version
         run: |
           OUTPUT_JSON='${{ toJson(steps.release.outputs) }}'
           PR_JSON=$(echo "$OUTPUT_JSON" | jq -r '.pr | fromjson')
           TITLE=$(echo "$PR_JSON" | jq -r '.title')
           VERSION=$(echo "$TITLE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
           echo "version=$VERSION" >> $GITHUB_OUTPUT
   ```

#### Configure Deployment Versioning

1. Modify your deployment process to accept a **version parameter**(e.g. [step 2 in the new pipeline section](#5-create-a-new-pipeline)). This ensures that the pipeline deploys a specified version instead of relying on Jenkins' auto-generated versioning.
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
5. For further customization, check the configuration examples in the [`examples`](/jenkins/example/release-please/) directory.

With this setup, versioning is automated, ensuring consistency and traceability in your releases.

### How to Deploy Components

For a detailed, step-by-step guide on how deployments work in the 2060.io ecosystem—including naming conventions, Jenkins integration, Helm usage, and best practices—refer to the [2060.io Deployment Strategy Guide](./deployment-strategy.md).

### 10. (Optional & Recommended) PVC Migration for New Integration

#### Kubernetes Persistent Volume Claim (PVC) Migration Process

To initiate a migration process in the deployment system, it is essential to have a clear understanding of the following aspects. In Kubernetes, PVCs do not store data themselves; instead, they act as a bridge to connect with the actual stored data. Therefore, before starting the migration, it is crucial to identify the required PVCs and PVs.

#### Steps for Migration

1. **Check the PVCs in the Target Namespace**  
   Run the following command to list all PVCs in the relevant namespace:

   ```sh
   kubectl get pvc --namespace=demos-dev
   ```

2. **Retrieve PV Details**  
   Obtain details of the target Persistent Volume (PV) using:

   ```sh
   kubectl describe pv ovh-managed-kubernetes-s2jb2y-pvc-df66660e-ceb2-4d50-942a-dfe3f9ffff7a
   ```

3. **Update PV with Retain Policy**  
   To prevent the PV from being deleted even when it is not associated with a PVC, update its reclaim policy:

   ```sh
   kubectl patch pv ovh-managed-kubernetes-s2jb2y-pvc-df66660e-ceb2-4d50-942a-dfe3f9ffff7a -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
   ```

4. **Delete the PVC**  
   Ensure that the associated service is stopped to avoid potential errors. If the steps are followed correctly, the service will be down for approximately 10 minutes:

   ```sh
   kubectl delete pvc unic-id-test-pg-pv-main -n demos-dev
   ```

5. **Remove claimRef from the PV**  
   After the PVC is deleted, manually remove the `claimRef` from the PV to allow it to be bound to a new PVC:

   ```sh
   kubectl patch pv ovh-managed-kubernetes-s2jb2y-pvc-acb677e7-c451-46ac-b91b-341b98aa52ad --type=json -p='[{"op": "remove", "path": "/spec/claimRef"}]'
   ```

6. **Deploy the New Configuration**  
   After completing the previous steps, proceed with the new deployment provided in the [example](./example/helm/templates/deployment_with_persist_db.yaml). This new deployment will create independent PVCs. If the PVCs are created from scratch, there is no need to associate them with any `volumeName`.

7. **Associate a New PVC to the Existing PV using `volumeName`**  
   If you want to reuse the existing PV (e.g. the retained volume from the previous deployment), define the `volumeName` in your new PVC specification. This binds the PVC directly to the specified PV. For example:

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
     volumeName: ovh-managed-kubernetes-s2jb2y-pvc-acb677e7-c451-46ac-b91b-341b98aa52ad
     resources:
       requests:
         storage: 1Gi
   ```

   This ensures the new PVC will claim the existing PV, provided the access mode, storage class, and requested size are compatible.
