## Helm Plan - GitHub Action

Resolves which GitHub environments a run deploys to, as the matrix of the deploy job.
It reads the cluster manifest and the diff of the push, so it needs no secrets and can
run in a job with no `environment:` of its own.

It is the first half of the deploy pipeline every `*-deploy` repository runs; the
canonical shape of the two jobs is in
[../../.github/workflows/README.md](../../.github/workflows/README.md).

### Inputs

| Input       | Required | Description                                                                              |
| ----------- | -------- | ---------------------------------------------------------------------------------------- |
| `directory` | Yes      | Base directory holding the values files (e.g. `charts`).                                 |
| `manifest`  | No       | Cluster manifest. Defaults to `clusters.yml`.                                            |
| `release`   | No       | A single release as the path of its values file without the extension. Skips the diff.    |

### Outputs

| Output   | Description                                                                                 |
| -------- | ------------------------------------------------------------------------------------------- |
| `matrix` | `[{"environment": "...", "namespace": "..."}, ...]`, one entry per cluster the run touches. |

`namespace` is the `chartNamespace` the values files of the cluster declare, and is
empty when they disagree, in which case the deploy job has to name the namespace of
its Secret itself. `matrix` is `[]` when the run touches no cluster, which the deploy
job skips with `if: needs.plan.outputs.matrix != '[]'`.

### Requirements

* A checkout with `fetch-depth: 0` in the same job: without the history there is no diff.
* Every cluster of the manifest that the run matches declares `environment`.
* Exclusive patterns in the manifest. A `release` that matches two clusters stops the
  run, because one job cannot hold two kubeconfigs.

### Example

```yaml
jobs:
  plan:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.plan.outputs.matrix }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - id: plan
        uses: 2060-io/organization/actions/helm-plan@main
        with:
          directory: charts
          manifest: charts/clusters.yml
```

On a branch's first push, or after a force push that dropped the previous commit,
there is no range to diff and the action stops: deploy those releases one by one with
the `release` input.
