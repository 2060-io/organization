## Helm Deploy -GitHub Action

This GitHub Action detects changed Helm values files and deploys Helm charts accordingly. It supports multi-environment deployments (`dev`, `prod`), dynamic release detection, and optional overrides for production environments.

### Overview

**Helm Deploy** is a composite GitHub Action designed to implement a **manifest-driven Continuous Deployment (CD)** strategy for Kubernetes using Helm.

The action detects changes in environment configuration files, resolves the target clusters based on a manifest file, and deploys or uninstalls Helm releases in a controlled and auditable way. It is designed to work naturally with GitHub pull requests, CODEOWNERS, and branch protection rules.

---

### Key characteristics

* Path-based and declarative deployment model
* Automatic deployment triggered by merges to `main`
* Support for manual install and uninstall workflows
* Multi-cluster deployment via a central manifest
* Optional dry-run support
* Native integration with GitHub permissions and approvals

---

### How it works

At a high level, the action performs the following steps:

1. Validates required inputs and configuration files.
2. Detects modified YAML files under the configured directory, or uses a manually specified release.
3. Reads a cluster manifest file to determine which clusters are affected.
4. Matches changed files to clusters using path patterns.
5. Configures Kubernetes access for each target cluster.
6. Deploys or uninstalls Helm releases accordingly.

The action assumes that any change merged into `main` has already been authorized through pull request reviews and CODEOWNERS.

---

### Inputs

| Input       | Required | Description                                                                            |
| ----------- | -------- | -------------------------------------------------------------------------------------- |
| `directory` | Yes      | Base directory containing environment or release configuration files (e.g. `charts/`). |
| `manifest`  | No       | Cluster manifest file defining clusters and path patterns. Defaults to `clusters.yml`. |
| `release`   | No       | Deploy or uninstall a specific release directly, bypassing change detection.           |
| `uninstall` | No       | When set to `true`, performs a Helm uninstall instead of a deploy.                     |
| `dryRun`    | No       | When `true`, executes Helm commands in dry-run mode.                                   |

---

### Cluster manifest

The cluster manifest file defines the available clusters and the file path patterns associated with each one.

Example:

```yaml
clusters:
  - name: devnet
    pattern: devnet
    kubeconfigSecret: DEV_KUBECONFIG
  - name: testnet
    pattern: testnet
    kubeconfigSecret: DEV_KUBECONFIG
```

When a configuration file matching a pattern is modified, the release is deployed to the corresponding cluster.

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

### How Secrets Are Used

* The `chartSecrets` section does **not** contain actual secret values, only mappings (`name` → `path`).
* GitHub Actions secrets (e.g., `DB_PASSWORD`, `API_KEY`, `EMAIL_PASS`, `TESTING`) must be defined under **Settings → Secrets and variables → Actions** in your repository.
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

**Example:**
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
      dryRun:
        description: Execute in dry-run mode
        required: false
        default: 'false'

jobs:
  install:
    runs-on: ubuntu-latest
    environment: install
    steps:
      - uses: actions/checkout@v4
      - name: Helm Deploy
        uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: charts
          manifest: clusters.yml
          release: ${{ inputs.release }}
          dryRun: ${{ inputs.dryRun }}
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
        description: Release file to deploy (e.g. devnet/my-app.yml)
        required: true
      dryRun:
        description: Execute in dry-run mode
        required: false
        default: 'false'

jobs:
  install:
    runs-on: ubuntu-latest
    environment: uninstall
    steps:
      - uses: actions/checkout@v4
      - name: Helm Deploy
        uses: 2060-io/organization/actions/helm-deploy@v1.0.0
        with:
          directory: charts
          manifest: clusters.yml
          release: ${{ inputs.release }}
          uninstall: true
          dryRun: ${{ inputs.dryRun }}
        env:
          DEV_KUBECONFIG: ${{ secrets.DEV_KUBECONFIG }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
```

Manual workflows should be protected using GitHub Environments.

---

### Access and permissions

* Automatic deployments rely on pull request approvals and CODEOWNERS.
* Manual workflows should be restricted using GitHub Environments and required reviewers.
* The action itself does not perform permission checks and assumes that `main` is a trusted branch.

This separation keeps deployment logic simple while ensuring governance is handled by GitHub.

---

### Recommended practices

* Keep environment changes isolated per pull request.
* Use CODEOWNERS to define clear ownership per environment.
* Protect sensitive environments (e.g. production) with additional approvals.
* Avoid mixing unrelated environment changes in a single PR.
