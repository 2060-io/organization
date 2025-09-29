# 2060 Organization - Reusable Workflows

This directory contains **callable GitHub Actions workflows** designed for reuse across repositories in the 2060 organization.

## Callable Workflows

| Workflow File            | Description                | Documentation                        |
|------------------------- |---------------------------|---------------------------------------|
| `2060-linter-call.yml`   | Linting workflow          | [docs/2060-linter.md](./docs/2060-linter.md)   |
| `stable-image-call.yml`  | Build stable Docker image  | [docs/stable-image.md](./docs/stable-image.md) |
| `unstable-image-call.yml`| Build unstable Docker image| [docs/unstable-image.md](./docs/unstable-image.md) |

## Usage

To reuse any of these workflows, reference them in your repository's workflow YAML using the `uses` keyword, for example:

```yaml
jobs:
  call-linter:
    uses: 2060-org/devops/.github/workflows/2060-linter-call.yml@main
```

For detailed usage and input/output parameters, see the documentation linked above for each workflow.