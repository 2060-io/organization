## Helm Deploy - GitHub Action

This GitHub Action detects changed Helm values files and deploys Helm charts accordingly. It supports multi-environment deployments with GitHub Environments integration, dynamic release detection, and optional overrides for production environments.

### Overview

**Helm Deploy** is a composite GitHub Action designed to implement a **manifest-driven Continuous Deployment (CD)** strategy for Kubernetes using Helm.

The action detects changes in environment configuration files, resolves the target clusters based on a manifest file, and deploys or uninstalls Helm releases in a controlled and auditable way. It is designed to work naturally with GitHub pull requests, CODEOWNERS, branch protection rules, and GitHub Environments for secrets management.

---

### Key characteristics

* Path-based and declarative deployment model
* Automatic deployment triggered by merges to `main`
* Support for manual install and uninstall workflows
* Multi-cluster deployment via a central manifest
* GitHub Environments integration for environment-specific secrets
* Optional environment filtering to restrict deployments
* Optional dry-run support
* Native integration with GitHub permissions and approvals

---

### How it works

At a high level, the action performs the following steps:

1. Validates required inputs and configuration files.
2. Detects modified YAML files under the configured directory, or uses a manually specified release.
3. Reads a cluster manifest file to determine which clusters are affected.
4. Filters clusters by environment if specified (optional).
5. Matches changed files to clusters using path patterns.
6. Configures Kubernetes access for each target cluster.
7. Deploys or uninstalls Helm releases accordingly.

The action assumes that any change merged into `main` has already been authorized through pull request reviews and CODEOWNERS.

---

### Inputs

| Input           | Required | Description                                                                                                        |
| --------------- | -------- | ------------------------------------------------------------------------------------------------------------------ |
| `directory`     | Yes      | Base directory containing Helm charts or environment configuration files (e.g. `charts/`).                         |
| `manifest`      | No       | YAML manifest file defining clusters and their path patterns. Defaults to `clusters.yml`.                          |
| `deploy-labels` | No       | Labels applied to the Helm release. Format: `key=value,key2=value2`.                                               |
| `environment`   | No       | Environment filter to restrict deployment to specific clusters. Must match `environment` field in cluster manifest. |
| `release`       | No       | Deploy or uninstall a specific release directly, bypassing change detection.                                       |
| `uninstall`     | No       | When set to `true`, performs a Helm uninstall instead of a deploy.                                                 |
| `dry-run`       | No       | When `true`, executes Helm commands in dry-run mode.                                                               |

> **Note:** The following label keys are reserved and must not be used in `deploy-labels`, as they are managed internally by Helm:  
> `name`, `owner`, `status`, `version`, `createdAt`, `modifiedAt`

---

### Cluster manifest

The cluster manifest file defines the available clusters and the file path patterns associated with each one.

Example:

```yaml
clusters:
  - name: development-cluster
    pattern: devnet
    kubeconfigSecret: DEV_KUBECONFIG
    environment: development # (Only if environments has been enabled)
  - name: testnet-cluster
    pattern: testnet
    kubeconfigSecret: DEV_KUBECONFIG
    environment: testing # (Only if environments has been enabled)
```

When a configuration file matching a pattern is modified, the release is deployed to the corresponding cluster. If the `environment` input is provided, only clusters matching that environment will be processed.

---

### Environment configuration files

Each environment or release is defined by a YAML file located under the configured `directory`.

Minimum required fields:

```yaml
chartSource: ./charts/service-a
chartVersion: 1.2.3
chartNamespace: my-namespace
chartSecrets:
  - name: DB_PASSWORD        # GitHub Actions secret name
    path: app.config.dbPassword
  - name: API_KEY
    path: app.config.apiKey

replicaCount: 2
image:
  repository: myrepo/service-a
  tag: latest
app:
  config:
    dbPassword: value
    apiKey: value    
```

The release name is inferred from the file name.

---

### GitHub Environments Integration
#### How it works

1. **Define environments in your repository**: Go to Settings -> Environments and create environments like `production`, `development`, `staging`
2. **Add environment-specific secrets**: Each environment can have its own set of secrets (e.g., different `DB_PASSWORD` for prod vs dev)
3. **Configure cluster manifest**: Add `environment` field to each cluster definition
4. **Declare environment in workflow**: Use `environment:` in your job to tell GitHub which environment's secrets to use
5. **Pass environment filter to action**: Use the `environment` input to ensure only matching clusters are deployed

---

### How Secrets Are Used

* The `chartSecrets` section does **not** contain actual secret values, only mappings (`name` -> `path`).
* GitHub Actions secrets (e.g., `DB_PASSWORD`, `API_KEY`, `EMAIL_PASS`, `TESTING`) must be defined under:
  * Settings -> Secrets and variables -> Actions (for repository-level secrets), OR
  * Settings -> Environments -> [environment name] -> Secrets (for environment-specific secrets)
* During deployment, these secrets are exported as **environment variables** (e.g. `$DB_PASSWORD`, `$API_KEY`) and then mapped dynamically according to the `chartSecrets` configuration.
* At runtime, the script resolves them and generates Helm arguments such as:

```bash
--set app.config.dbPassword=$DB_PASSWORD \
--set app.config.apiKey=$API_KEY \
--set name=$EMAIL_PASS \
--set app.config.testing=$TESTING
```

This ensures secrets are securely injected at deployment time without being exposed in your repository or action inputs.

---

### Deployment modes

#### Automatic CD

* Triggered by a `push` to `main`.
* Deploys only the releases affected by the merged pull request.
* Authorization is enforced through CODEOWNERS and branch protection rules.

**Example without environments:**
```yaml
name: CD
on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Helm Deploy
        uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: charts
          manifest: clusters.yml
        env:
          DEV_KUBECONFIG: ${{ secrets.DEV_KUBECONFIG }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
```

**Example with environment filtering:**
```yaml
name: Deploy Charts
on:
  push:
    branches:
      - main

jobs:
  detect:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.env.outputs.name }}
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - id: env
        run: |
          CHANGED=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }})
          
          if echo "$CHANGED" | grep -q "^charts/mainnet/"; then
            echo "name=production" >> $GITHUB_OUTPUT
          elif echo "$CHANGED" | grep -q "^charts/testnet/"; then
            echo "name=testing" >> $GITHUB_OUTPUT
          fi

  deploy:
    needs: detect
    if: needs.detect.outputs.environment != ''
    runs-on: ubuntu-latest
    environment: ${{ needs.detect.outputs.environment }}
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: 'charts'
          environment: ${{ needs.detect.outputs.environment }}
        env:
          KUBECONFIG_PROD: ${{ secrets.KUBECONFIG_PROD }}
          KUBECONFIG: ${{ secrets.KUBECONFIG }}
          EMAIL_PASS: ${{ secrets.EMAIL_PASS }}
```

#### Manual install

* Triggered via `workflow_dispatch`.
* Allows deploying a specific release on demand.
* Supports dry-run execution.

**Example:**
```yaml
name: Manual install
on:
  workflow_dispatch:
    inputs:
      release:
        description: Release file to deploy (e.g. devnet/my-app.yml)
        required: true
      environment:
        description: Environment to deploy to (optional filter)
        required: false
      dryRun:
        description: Execute in dry-run mode
        required: false
        default: 'false'

jobs:
  install:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'default' }}
    steps:
      - uses: actions/checkout@v4
      - name: Helm Deploy
        uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: charts
          manifest: clusters.yml
          release: ${{ inputs.release }}
          environment: ${{ inputs.environment }}
          dry-run: ${{ inputs.dryRun }}
        env:
          DEV_KUBECONFIG: ${{ secrets.DEV_KUBECONFIG }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
```

#### Manual uninstall

* Triggered via `workflow_dispatch`.
* Explicitly removes a Helm release from the target cluster.

**Example:**
```yaml
name: Manual uninstall
on:
  workflow_dispatch:
    inputs:
      release:
        description: Release file to uninstall (e.g. devnet/my-app.yml)
        required: true
      dryRun:
        description: Execute in dry-run mode
        required: false
        default: 'false'

jobs:
  uninstall:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Helm Uninstall
        uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: charts
          manifest: clusters.yml
          release: ${{ inputs.release }}
          uninstall: true
          dry-run: ${{ inputs.dryRun }}
        env:
          DEV_KUBECONFIG: ${{ secrets.DEV_KUBECONFIG }}
```

Manual workflows should be protected using GitHub Environments.

---

### Access and permissions

* Automatic deployments rely on pull request approvals and CODEOWNERS.
* Manual workflows should be restricted using GitHub Environments and required reviewers.
* Environment-based deployments can enforce additional protection rules through GitHub Environments.
* The action itself does not perform permission checks and assumes that `main` is a trusted branch.

This separation keeps deployment logic simple while ensuring governance is handled by GitHub.

---

### Recommended practices

* Keep environment changes isolated per pull request.
* Use CODEOWNERS to define clear ownership per environment.
* Use GitHub Environments for production and other sensitive environments to enable:
  * Required approvals before deployment
  * Environment-specific secrets
  * Deployment history and audit logs
* Protect sensitive environments (e.g. production) with additional approvals.
* Avoid mixing unrelated environment changes in a single PR.
