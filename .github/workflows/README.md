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
| `helm-deploy-call.yml`            | Deploy Helm charts to every cluster a change touches | [inputs in the file header](./helm-deploy-call.yml) |

## Usage

To reuse any of these workflows, reference them in your repository's workflow YAML using the `uses` keyword, for example:

```yaml
jobs:
  call-linter:
    uses: 2060-org/devops/.github/workflows/2060-linter-call.yml@main
```

For detailed usage and input/output parameters, see the documentation linked above for each workflow.

### Helm deploy

`helm-deploy-call.yml` replaces the deployment job that each `*-deploy` repository
keeps in its own `cd.yml`. It reads `clusters.yml` to resolve which clusters a push
touches, and then deploys each one from its own job, holding only the kubeconfig and
the secrets of that cluster's GitHub environment:

```yaml
jobs:
  cd:
    uses: 2060-io/organization/.github/workflows/helm-deploy-call.yml@main
    with:
      directory: charts
      # Optional: a Kubernetes Secret to create before deploying
      secret-name: hologram-secrets
      secret-namespace: hologram-backend
      secret-keys: |
        MEDIATOR_WALLET_KEY
        FIREBASE_CONFIG=@firebase-config.json
    secrets: inherit
```

Three requirements:

* `secrets: inherit`, because the workflow reads the kubeconfig and the values of
  `secret-keys` from the caller's secrets.
* Every cluster in the manifest declares `environment`, and the repository has a
  GitHub environment of that name holding its own `KUBECONFIG`.
* Every cluster in the manifest declares `kubeconfigSecret: KUBECONFIG`. The name of
  the secret in GitHub is free, through the `kubeconfig-secret` input.

The same workflow covers the manual flows: pass `release` for a single release, and
`uninstall: true` to remove it. The file header documents every input.