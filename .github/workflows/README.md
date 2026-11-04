# 2060 Organization - Reusable Workflows

This directory contains **callable GitHub Actions workflows** designed for reuse across repositories in the 2060 organization.

## Callable Workflows

| Workflow File                     | Description                            | Documentation                                                  |
|---------------------------------- |----------------------------------------|----------------------------------------------------------------|
| `2060-linter-call.yml`            | Linting workflow                       | [docs/2060-linter.md](./docs/2060-linter.md)                   |
| `stable-image-call.yml`           | Build stable Docker image              | [docs/stable-image.md](./docs/stable-image.md)                 |
| `unstable-image-call.yml`         | Build unstable Docker image            | [docs/unstable-image.md](./docs/unstable-image.md)             |
| `discord-release-notify-call.yml` | Post release notifications to Discord  | [docs/discord-release-notify.md](./docs/discord-release-notify.md) |
| `resolve-version-call.yml`        | Resolve the next release version       | [docs/resolve-version.md](./docs/resolve-version.md)           |

## Usage

To reuse any of these workflows, reference them in your repository's workflow YAML using the `uses` keyword, for example:

```yaml
jobs:
  call-linter:
    uses: 2060-org/devops/.github/workflows/2060-linter-call.yml@main
```

For detailed usage and input/output parameters, see the documentation linked above for each workflow.

### Deploying Helm charts

Deployment is not a callable workflow of this repository, it is a **shape of two jobs**
that every `*-deploy` repository keeps in its own `cd.yml`, `install.yml` and
`uninstall.yml`, over three composite actions kept here:

| Action                                                   | What it does in the shape                                            |
| -------------------------------------------------------- | -------------------------------------------------------------------- |
| [helm-plan](../../actions/helm-plan/README.md)           | Resolves the clusters the run touches, as the matrix of the deploy job |
| [helm-secret](../../actions/helm-secret/README.md)       | Writes the Kubernetes Secret and exports the chart secrets             |
| [helm-deploy](../../actions/helm-deploy/README.md)       | Runs `helm upgrade --install`, or `helm uninstall`                     |

The jobs live in each repository, and not in a reusable workflow here, because
`environment:` is a job key: the secrets and variables of a GitHub environment only
resolve in a job that declares it. A job that calls a reusable workflow cannot declare
one, and `secrets: inherit` passes nothing at all when the caller belongs to another
organization, as `verana-labs/verana-deploy` does. An action has neither limit, since it
runs inside the job of the caller. So the shape is the standard, and the actions are the
shared implementation.

> `helm-deploy-call.yml` wrapped this shape for repositories of 2060-io only, and was
> removed for the same reason. A repository that still pins it by SHA keeps working, and
> moves to the shape below at its next change.

#### The shape

```yaml
name: Deploy to Kubernetes

on:
  push:
    branches:
      - main

permissions:
  contents: read

jobs:
  # Which environments does this run deploy to? Reads the manifest, needs no secrets.
  plan:
    runs-on: ubuntu-latest
    outputs:
      # [{"environment": "...", "namespace": "..."}, ...]
      matrix: ${{ steps.plan.outputs.matrix }}
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Resolve target environments
        id: plan
        uses: 2060-io/organization/actions/helm-plan@main
        with:
          directory: charts

  # One job per environment: its own kubeconfig, secrets and approval.
  deploy:
    needs: plan
    if: needs.plan.outputs.matrix != '' && needs.plan.outputs.matrix != '[]'
    runs-on: ubuntu-latest
    name: deploy (${{ matrix.environment }})
    strategy:
      fail-fast: false
      matrix:
        include: ${{ fromJSON(needs.plan.outputs.matrix) }}
    environment: ${{ matrix.environment }}
    concurrency:
      # One queue per cluster. Never cancelled: a cancelled `helm upgrade`
      # leaves the release in pending-upgrade.
      group: helm-deploy-${{ matrix.environment }}
      cancel-in-progress: false
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Kubernetes and chart secrets
        uses: 2060-io/organization/actions/helm-secret@main
        with:
          environment: ${{ matrix.environment }}
          secret-name: hologram-secrets
          # The namespace the values files of this cluster declare.
          secret-namespace: ${{ matrix.namespace }}
          secret-keys: |
            MEDIATOR_WALLET_KEY
            FIREBASE_CONFIG=@firebase-config.json
        env:
          # Secret and multi-line: they must never reach a `with:` block.
          KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}
          SECRETS_JSON: ${{ toJSON(secrets) }}
          VARS_JSON: ${{ toJSON(vars) }}

      - name: Helm deploy
        uses: 2060-io/organization/actions/helm-deploy@v0.5.2
        with:
          directory: charts
          environment: ${{ matrix.environment }}
          deploy-labels: managed-by=2060-deploy
        env:
          # The name `kubeconfigSecret` gives in the manifest.
          KUBECONFIG: ${{ secrets.KUBECONFIG }}
```

Nothing of the shape changes from one repository to the next. What changes is data: the
manifest path, the name of the Secret and its keys, the `chartSecrets` names, the labels
and the name of the secret that holds the kubeconfig:

| Repository                           | Manifest              | Secret            | Kubeconfig           |
| ------------------------------------ | --------------------- | ----------------- | -------------------- |
| `2060-io/hologram-backend-deploy`    | `clusters.yml`        | `hologram-secrets`| `KUBECONFIG`         |
| `2060-io/hologram-demos-deploy`      | `clusters.yml`        | `demos-secrets`   | `KUBECONFIG`         |
| `verana-labs/verana-deploy`          | `charts/clusters.yml` | `verana-secrets`  | `VERANA_KUBECONFIG`  |

#### The manual flows

`install.yml` and `uninstall.yml` run the same two jobs on `workflow_dispatch`, and
hand the chosen release to both actions as
`release: ${{ inputs.environment }}/${{ inputs.release }}`, which skips change
detection. `uninstall.yml` passes `uninstall: true` to `helm-deploy` and no
`helm-secret` step at all; both pass `dry-run: ${{ inputs.dry-run }}`.

#### Requirements

* Every cluster of the manifest declares `environment`, and the repository has a GitHub
  environment of that name holding its own kubeconfig, under the name
  `kubeconfigSecret` gives.
* A checkout with `fetch-depth: 0` in both jobs: the plan diffs the push, and the deploy
  action diffs it again to pick the values files.
* The values files of one cluster declare a single `chartNamespace`, or the deploy job
  names the namespace of its Secret in `secret-namespace` itself.
