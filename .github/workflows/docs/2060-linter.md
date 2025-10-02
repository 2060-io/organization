# Continuous Integration Workflow Documentation

## Overview

The **Continuous Integration** workflow provides automated validation of code quality, type safety, unit tests, integration tests, Helm charts, and pull request compliance.
It is designed to be invoked as a **reusable workflow** through [`workflow_call`](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

This workflow ensures consistency and reliability in contributions by enforcing formatting, type checking, testing, Helm chart validation, and semantic pull request titles.

---

## Workflow Triggers

This workflow is triggered via `workflow_call`. It is not intended to run on direct pushes or pull requests unless explicitly referenced from another workflow.

```yaml
on:
  workflow_call:
    inputs:
      charts-dir:
        description: "Directory containing Helm charts"
        required: false
        type: string
```

### Inputs

* **`charts-dir`** *(optional)*
  The path to the directory containing Helm charts.
  If omitted, the workflow defaults to linting all charts under `./charts/*`.

---

## Jobs

### 1. Lint, Types & Tests (`lint`)

Runs a series of checks to ensure code quality and reliability.

* **Steps**:

  1. Checkout repository.
  2. Setup Node.js v22.
  3. Enable Corepack.
  4. Install dependencies with `pnpm install --frozen-lockfile`.
  5. Run format checks (`pnpm check-format`).
  6. Run type checks (`pnpm check-types`).
  7. Execute unit tests (`pnpm test`).
  8. Execute integration tests (`pnpm test:integration`).

This job must succeed before Helm chart validation or PR validation can run.

---

### 2. Validate Helm Charts (`charts`)

Validates Helm charts using `helm lint`.

* **Dependencies**: Requires the successful completion of the `lint` job.
* **Behavior**:

  * If `charts-dir` input is provided and points to a valid directory, only that directory is validated.
  * Otherwise, all subdirectories under `./charts/*` containing a `Chart.yaml` file are validated.

---

### 3. Validate PR Title (`pr-validation`)

Ensures pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/) standards.

* **Dependencies**: Requires the successful completion of the `lint` job.
* **Conditions**: Runs only if the workflow is triggered by a pull request event.
* **Implementation**: Uses [`amannn/action-semantic-pull-request`](https://github.com/amannn/action-semantic-pull-request).

---

## Usage Example

To use this workflow from another workflow in your repository:

```yaml
name: Pull Request Validation

on:
  pull_request:

jobs:
  ci:
    uses: 2060-io/organization/workflows_call/2060-linter/template.yml@main
    with:
      charts-dir: ./helm/my-service
```

---

## Requirements

* Node.js 22 (installed automatically by the workflow).
* `pnpm` package manager (enabled via Corepack).
* Helm CLI available in the runner environment.
* Properly structured Helm charts with `Chart.yaml`.
* Pull requests must follow semantic commit message conventions.

---

## Notes

* The workflow enforces **formatting, typing, and testing** as prerequisites before Helm validation and PR title checks.
* If `charts-dir` is not defined, the workflow automatically attempts to validate all charts under the `./charts` directory.
* The `pr-validation` job is skipped if the workflow is not triggered by a pull request.
