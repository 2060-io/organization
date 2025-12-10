# Publish pnpm Libraries Deployment Workflow

## Overview

The **Publish pnpm Libraries Deployment** workflow is designed to automate the process of packaging and publishing one or more NPM packages managed with **pnpm**. It sets the release version in `package.json`, installs dependencies, and publishes the packages to the NPM registry.

The workflow also supports a **dry-run mode**, which outputs the commands that would be executed without performing any actions.

---

## Inputs

The workflow requires the following inputs:

| Name              | Required | Default | Description                                                               |
| ----------------- | -------- | ------- | ------------------------------------------------------------------------- |
| `release-version` | Yes      | —       | The version to set in `package.json` files (e.g., `1.2.3`).               |
| `npm-token`       | Yes      | —       | NPM authentication token used to publish packages to the registry.        |
| `dry-run`         | No       | `false` | If set to `true`, the workflow only prints commands instead of executing. |

---

## Workflow Steps

### 1. Setup Node.js

* **Action**: [actions/setup-node@v4](https://github.com/actions/setup-node)
* **Version**: Node.js 22
* **Condition**: Runs only if `dry-run` is not enabled.

### 2. Enable Corepack for pnpm

* **Command**: `corepack enable`
* **Condition**: Runs only if `dry-run` is not enabled.

### 3. Install Dependencies

* **Command**: `pnpm install`
* **Condition**: Runs only if `dry-run` is not enabled.

### 4. Set Release Version

* **Command**:

  ```bash
  pnpm -r --topological version "${{ inputs.release-version }}"
  ```
* **Condition**: Runs only if `dry-run` is not enabled.

### 5. Publish Packages

* **Authentication**: Uses `NPM_AUTH_TOKEN` from `npm-token` input.
* **Commands**:

  ```bash
  echo "//registry.npmjs.org/:_authToken=${NPM_AUTH_TOKEN}" > ~/.npmrc
  pnpm config set npmAuthToken ${NPM_AUTH_TOKEN}
  pnpm -r publish --no-git-checks --access public
  ```
* **Condition**: Runs only if `dry-run` is not enabled.

### 6. Dry-Run Mode

If `dry-run` is set to `true`, the workflow will not execute any publishing steps. Instead, it will print the commands that would have been executed.

Example output:

```
Dry run mode enabled
Would run with release version: 1.2.3
Commands that would be executed:
  corepack enable
  pnpm install
  pnpm -r --topological version "1.2.3"
  pnpm -r publish --no-git-checks --access public
```

---

## Usage Example

To call this workflow from another workflow in the same repository, reference it as follows:

```yaml
jobs:
  publish:
    uses: ./.github/workflows/publish-pnpm-libraries.yml
    with:
      release-version: "1.2.3"
      npm-token: ${{ secrets.NPM_TOKEN }}
      dry-run: "false"
```

---

## Notes

* Ensure that `NPM_TOKEN` is stored as a secret in your repository or organization settings.
* The workflow assumes the project is managed using **pnpm workspaces**.
* Dry-run mode is useful for validating release commands before performing an actual publish.
