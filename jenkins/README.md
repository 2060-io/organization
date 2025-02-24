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
You can find a sample project illustrating the expected structure [here](./example/).

### 5. Create a New Pipeline
To create a new pipeline, follow these steps:

1. **Ensure the repository structure**:
   - The repository should have the following structure:
     ```
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
#### GitHub OAuth Setup:
1. Navigate to [GitHub Developer Settings](https://github.com/settings/developers) and create a new **OAuth App**.
2. Use the following values:
   - **Homepage URL:** `https://jenkins.dev.2060.io/`
   - **Authorization Callback URL:** `https://jenkins.dev.2060.io/securityRealm/finishLogin`
3. Generate a new **Client Secret** and take note of the **Client ID** and **Client Secret**.

#### Configure Jenkins Authentication:
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

