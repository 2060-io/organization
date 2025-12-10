# Publish Helm Charts Action

This GitHub Action packages and publishes one or more [Helm](https://helm.sh/) charts to the **Docker Hub OCI registry**.
It supports both **independent charts** and **dependent charts** that reference each other within the same repository.

---

## Requirements

Before using this Action, ensure the following requirements are met:

1. **Helm CLI** must be available on the runner (the action itself installs Helm if missing).
2. A **Docker Hub account** with permissions to push to your Helm chart repository.
3. GitHub repository secrets configured:

   * `DOCKER_HUB_LOGIN` → your Docker Hub username.
   * `DOCKER_HUB_PWD` → your Docker Hub password or access token.
4. Your charts must be stored under `./charts/` directory unless you override with the `charts` input.

---

## Inputs

| Name               | Required | Default                           | Description                                                                                                   |
| ------------------ | -------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `dh-username`      | Yes        | n/a                               | Docker Hub username.                                                                                          |
| `dh-token`         | Yes        | n/a                               | Docker Hub token or password.                                                                                 |
| `release-version`  | Yes        | n/a                               | Version to set in each `Chart.yaml` (e.g., `v1.2.3`).                                                         |
| `charts`           | No        | *(all subfolders of `./charts/`)* | Space-separated list of chart directories to process. If not set, all subfolders inside `./charts/` are used. |
| `dependent-charts` | No        | `""`                              | Space-separated list of charts that depend on other charts in the same repo.                                  |
| `dry-run`          | No        | `false`                           | If `true`, the action will print the `helm push` command instead of executing it.                             |

---

## Usage

### Example: Standard Workflow

```yaml
name: Continuous Deployment

on:
  push:
    branches: [main, 'release/**']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Publish Helm Charts
        uses: 2060-io/devops/actions/publish-helm@main
        with:
          dh-username: ${{ secrets.DOCKER_HUB_LOGIN }}
          dh-token: ${{ secrets.DOCKER_HUB_PWD }}
          release-version: v1.0.${{ github.run_number }}
```

---

## Handling Multiple Repositories and Charts

This action supports **both single-chart and multi-chart repositories**:

1. **Multi-chart repository (default):**

   * By default, the action scans all subfolders inside `./charts/`.
   * Example structure:

     ```
     ./charts/
       ├── chatbot/
       ├── vs-agent/
     ```

2. **Single chart repository:**

   * If you only want to process one chart, set the `charts` input explicitly:

     ```yaml
     with:
       charts: "./charts/my-service"
     ```
   * This will only package and publish `./charts/my-service`.

---

## Dependent Charts

If some charts inside your repo depend on other charts in the same repository, you must declare them in the `dependent-charts` input.

* Independent charts will be packaged and published first.
* Dependent charts will be updated afterward, with their dependencies automatically updated to the new versions.

### Example:

```yaml
with:
  release-version: v1.0.${{ github.run_number }}
  dependent-charts: "./charts/chatbot"
```

Here, `chatbot` depends on another chart (e.g., `vs-agent`) inside the same repo. The action will:

1. Publish `vs-agent` first.
2. Then update `chatbot/Chart.yaml` with the correct version of `vs-agent`.
3. Finally, package and publish `chatbot`.

---

## Dry Run Mode

To validate what would happen without pushing charts:

```yaml
with:
  dry-run: true
```

This will **print the `helm push` commands** instead of executing them. Useful for testing CI/CD pipelines.
