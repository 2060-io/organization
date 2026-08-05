# Stable Versioning Workflow

## Overview

The **Stable Versioning** workflow provides automated version management for repositories that require both stable releases and development prereleases. It integrates two automated release systems:

1. **Release Please** – Used to create stable releases based on conventional commits.
2. **Semantic Release** – Used as a fallback mechanism to generate development prereleases when no stable release is produced.

This workflow is designed to be invoked using `workflow_call` from other workflows within the same repository. It ensures that each invoking workflow receives consistent versioning information, including version numbers and release metadata.

---

## Release Strategy

The workflow implements a two–tier versioning approach:

### Stable Release

If **Release Please** determines that a stable release should be created, the workflow:

* Generates a version tag
* Produces release notes
* Outputs semantic version components (major, minor, patch)
* Marks the release as published with type `latest`

### Development Release

If no stable release is produced:

* **Semantic Release** is executed as a fallback
* Generates a prerelease version (for example: `1.4.0-dev.3`)
* Produces version metadata
* Marks the release as published with type `dev`

### No Release

If neither system determines that a release should be created, the workflow outputs:

* `type=none`
* `published=false`

---

## Inputs

| Input | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `bump-minor-pre-major` | `boolean` | `true` | **Deprecated** — use `feat-release-type`. Only consulted when the Release Please config cannot be read. |
| `config-file` | `string` | `release-please-config.json` | Path to the Release Please configuration file. |
| `manifest-file` | `string` | `.release-please-manifest.json` | Path to the Release Please manifest file. |
| `generate-notes` | `boolean` | `false` | When `true`, uses `--generate-notes` to auto-generate release notes in GitHub's "What's Changed" format (PRs + contributors) for both stable and dev releases. |
| `create-pre-release` | `boolean` | `false` | When `true`, creates a GitHub pre-release for development versions produced by Semantic Release. Has no effect on stable releases. |
| `release-title` | `string` | `""` | Optional prefix for the GitHub Release title. When set, the title becomes `<release-title> <version>` (e.g. `My App v1.2.0`). Works independently of `generate-notes`. |
| `prerelease-branch` | `string` | `main` | Branch that Semantic Release treats as the `dev` prerelease branch. |
| `breaking-release-type` | `string` | `auto` | Bump applied to breaking changes in development (Semantic Release) releases: `major`, `minor`, `patch`, or `auto`. |
| `feat-release-type` | `string` | `auto` | Bump applied to `feat` commits in development (Semantic Release) releases: `major`, `minor`, `patch`, or `auto`. |

### How development bumps are resolved

Release Please owns the version policy, so the Semantic Release fallback **derives its rules from the
same `release-please-config.json`** rather than keeping a second source of truth. With both release
type inputs left at `auto` (the default), a repo needs no versioning inputs at all — the two channels
cannot drift apart.

Two separate Release Please keys govern pre-1.0.0 behavior, and they are easy to confuse:

| Key in `release-please-config.json` | Governs |
| ----------------------------------- | ------- |
| `bump-minor-pre-major` | **breaking** changes bump minor instead of major |
| `bump-patch-for-minor-pre-major` | **`feat`** commits bump patch instead of minor |

Resulting dev bumps under `auto`:

| Current version | Config keys | Breaking change | `feat` | `fix`, `refactor`, `build` |
| --------------- | ----------- | --------------- | ------ | -------------------------- |
| `>= 1.0.0` | any | **major** (`1.4.2 → 2.0.0-dev.1`) | minor | patch |
| `0.x.y` | `bump-minor-pre-major: true` | **minor** (`0.3.2 → 0.4.0-dev.1`) | — | patch |
| `0.x.y` | `bump-minor-pre-major: false` or unset | **patch** (`0.3.2 → 0.3.3-dev.1`) | — | patch |
| `0.x.y` | `bump-patch-for-minor-pre-major: true` | — | **patch** | patch |
| `0.x.y` | `bump-patch-for-minor-pre-major: false` or unset | — | **minor** | patch |

Breaking changes (`feat!:`, `fix(scope)!:`, or a `BREAKING CHANGE:` footer) are resolved by their own
rule, which takes precedence over the commit-type rules — a `feat!` commit is bumped as a breaking
change, not as a `feat`.

Setting `breaking-release-type` or `feat-release-type` to anything other than `auto` overrides the
derived value for that rule only.

#### Degraded behavior

`auto` reads the current version from `manifest-file` (the root `"."` entry, or the first entry in a
monorepo manifest) and the flags from `config-file`. Nothing here fails the job:

| Situation | Breaking change | `feat` |
| --------- | --------------- | ------ |
| Manifest missing, empty or malformed | `major` | falls back to the deprecated `bump-minor-pre-major` input |
| Config missing or malformed, version pre-1.0 | `patch` | `minor` (both keys read as `false`, matching Release Please's defaults) |

> **Why this exists:** Semantic Release has no pre-1.0 special case — a breaking change on `0.3.2`
> would otherwise resolve to `1.0.0-dev.1`, while Release Please would propose `0.4.0` for the same
> commits. Deriving both rules from the Release Please config keeps the two systems on the same
> version.

> **Note on `!` in commit headers:** the `angular` preset does not recognize the `!` breaking-change
> marker on its own, so the workflow supplies `parserOpts` with a `breakingHeaderPattern`. Without it
> `feat!:` commits parse to no type at all and are silently dropped from the version calculation.

### `generate-notes`, `create-pre-release` and `release-title` behavior

These inputs are independent and can be combined freely:

| Input | Effect |
| ----- | ------ |
| `release-title` set | Renames the release title to `<release-title> <version>` (e.g. `My App v1.2.0`). |
| `generate-notes: true` | Replaces the default release notes with GitHub's auto-generated "What's Changed" format (`--generate-notes`): merged PRs, contributors, and full changelog link. |
| `create-pre-release: true` | Creates a GitHub pre-release for the dev version. Without this, Semantic Release only creates a tag with no GitHub Release entry. |
| All three set | Custom title, auto-generated notes, and a GitHub pre-release for dev versions. |

The post-release steps activate based on their respective conditions:

| Release type | Condition | Step | Customization |
| ------------ | --------- | ---- | ------------- |
| `stable` | `releases_created == 'true'` | `gh release edit` on the release created by Release Please | Title if `release-title` is set; notes if `generate-notes: true` |
| `dev` | `create-pre-release: true` and `new-release-published == 'true'` | `gh release create --prerelease` | Title if `release-title` is set; notes if `generate-notes: true` |

> **Note:** GitHub auto-generated notes list merged PRs and contributors between the previous tag and the current one, e.g.:
> ```
> What's Changed
> fix: testing by @user in #49
> feat: new feature by @user in #51
> Full Changelog: v1.0.0...v1.1.0-dev.1
> ```

---

## **Required Files for Release Please**

For **Release Please** to operate correctly within this workflow, you must include the minimum configuration and manifest files in the root of your repository.

### **1. `release-please-config.json`**

This file defines how Release Please manages versioning, changelogs, and tagging behavior.

```json
{
  "include-component-in-tag": false,
  "include-v-in-tag": true,
  "separate-pull-requests": true,
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "packages": {
    ".": {
      "changelog-path": "CHANGELOG.md",
      "release-type": "node"
    }
  },
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

### **2. `.release-please-manifest.json`**

The manifest file contains the current version of your project. Release Please reads and updates this file automatically on each release.

```json
{
  ".": "1.5.3"
}
```

Both files are mandatory. Without them, Release Please will not detect components, generate release PRs, or manage version bumps.

---

## Branch Requirements

The workflow expects a `release` branch to exist.
If the branch does not exist, it will be automatically created and pushed to the repository.

---

## Permissions

The workflow requires the following permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
```

These permissions enable the workflow to:

* Push tags and commits
* Create or update pull requests
* Manage release artifacts

---

## Outputs

The workflow exposes several outputs so that calling workflows can use versioning information in subsequent steps (for example, during build, publish, or deployment jobs).

| Output Name             | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `release-version`       | Resolved version string from the release system            |
| `release-type`          | Type of release: `stable`, `dev`, or `none`                |
| `new-release-published` | Indicates whether a new release was successfully published |
| `release-major`         | Major version component                                    |
| `release-minor`         | Minor version component                                    |
| `release-patch`         | Patch version component                                    |

Example values:

* `release-version`: `1.3.0`
* `release-type`: `stable`
* `new-release-published`: `true`
* `release-major`: `1`
* `release-minor`: `3`
* `release-patch`: `0`

---

## How to Call This Workflow

Below is an example of how to invoke the workflow from another workflow:

```yaml
name: Build and Publish

on:
  push:
    branches: ["main"]

jobs:
  versioning:
    uses: 2060-io/organization/.github/workflows/resolve-version-call.yml@main
    with:
      # Versioning inputs are optional: by default both rules are derived from
      # release-please-config.json, so the dev and stable channels stay in step.
      # breaking-release-type: minor # force breaking changes to bump minor in dev releases
      # feat-release-type: patch     # force feat commits to bump patch in dev releases
      generate-notes: true    # use GitHub's "What's Changed" auto-generated notes
      create-pre-release: true   # create a GitHub pre-release for dev versions
      release-title: "My App"    # results in "My App v1.2.0" or "My App v1.2.0-dev.1"

  build:
    runs-on: ubuntu-latest
    needs: versioning
    steps:
      - run: echo "Version: ${{ needs.versioning.outputs.release-version }}"
      - run: echo "Type: ${{ needs.versioning.outputs.release-type }}"
      - run: echo "Published: ${{ needs.versioning.outputs.new-release-published }}"
```

---

## Behavior Summary

1. Checks out the repository using full history.
2. Ensures that a `release` branch exists.
3. Runs Release Please to attempt generating a stable release.
4. Logs Release Please output for debugging.
5. If no stable release is produced, runs Semantic Release to create a development release.
6. Collects and outputs all versioning data in a consistent, structured format.

---

## Intended Use Cases

This workflow is suitable for:

* Monorepos or multi-service repositories needing consistent version outputs
* Projects that combine stable release lifecycles with development prereleases
* CI/CD pipelines that must tag, publish, and version artifacts automatically

---

## Usage Example

### Continuous Deployment Pipeline Using Stable Versioning

The following example demonstrates how to consume the Stable Versioning workflow in a Continuous Deployment pipeline. This pipeline:

* Invokes the versioning workflow
* Builds and tags Docker images based on the resolved version
* Publishes Helm charts with the resolved version tag

```yaml
name: Continuous Deployment

on:
  push:
    branches: [main, 'release/**']
  workflow_dispatch:

env:
  DH_USERNAME: ${{ secrets.DOCKER_HUB_LOGIN }}
  DH_TOKEN: ${{ secrets.DOCKER_HUB_PWD }}
  IMAGE_NAME: demos-resource

jobs:
  resolve-version:
    uses: 2060-io/organization/.github/workflows/resolve-version-call.yml@fix/unify-generate-version

  docker:
    needs: resolve-version
    if: needs.resolve-version.outputs.new-release-published == 'true'
    runs-on: ubuntu-latest
    env:
      IMAGE_TAG: ${{ needs.resolve-version.outputs.release-type }}
      RELEASE_VERSION: ${{ needs.resolve-version.outputs.release-version }}
      RELEASE_MAJOR: ${{ needs.resolve-version.outputs.release-major }}
      RELEASE_MINOR: ${{ needs.resolve-version.outputs.release-minor }}
      RELEASE_PATCH: ${{ needs.resolve-version.outputs.release-patch }}
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Log in to Docker Hub
        run: |
          echo "$DH_TOKEN" | docker login -u "$DH_USERNAME" --password-stdin

      - name: Build Docker image
        run: |
          docker build -f ./apps/vs-agent/Dockerfile -t $DH_USERNAME/$IMAGE_NAME:$IMAGE_TAG .

      - name: Add tags to Docker image and push to Docker Hub
        run: |
          if [ "$IMAGE_TAG" = "latest" ]; then
            TAGS=("v${RELEASE_VERSION}")
          else
            TAGS=(
              "v${RELEASE_MAJOR}-${IMAGE_TAG}"
              "v${RELEASE_MAJOR}.${RELEASE_MINOR}-${IMAGE_TAG}"
              "v${RELEASE_MAJOR}.${RELEASE_MINOR}.${RELEASE_PATCH:0:1}-${IMAGE_TAG}"
              "v${RELEASE_VERSION}"
            )
          fi
          
          docker push $DH_USERNAME/$IMAGE_NAME:$IMAGE_TAG

          for tag in "${TAGS[@]}"; do
            echo "Dry run: docker tag $DH_USERNAME/$IMAGE_NAME:$IMAGE_TAG $DH_USERNAME/$IMAGE_NAME:$tag"
            echo "Dry run: docker push $DH_USERNAME/$IMAGE_NAME:$tag"
          done

  helm:
    needs: [resolve-version, docker]
    if: needs.resolve-version.outputs.new-release-published == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Run publish-helm action
        id: publish-helm
        uses: 2060-io/devops/actions/publish-helm@main
        with:
          dh-username: ${{ secrets.DOCKER_HUB_LOGIN }}
          dh-token: ${{ secrets.DOCKER_HUB_PWD }}
          release-version: v${{ needs.resolve-version.outputs.release-version }}
          charts: "./charts"
          dry-run: true
```

---

## Security Note: Pin Third-Party Actions by SHA

Third-party actions in these examples are pinned to a **full commit SHA** instead of a
mutable tag (e.g. `actions/checkout@11bd719...` instead of `actions/checkout@v4`). A tag
can be silently moved or republished by its maintainer, so pinning to an immutable SHA
protects the pipeline against a compromised or hijacked action.

The trailing comment (`# v4.2.2`) records the human-readable version so the pin stays
auditable and tools like Dependabot can keep it updated.

> First-party references to this org's own reusable workflows and actions
> (`2060-io/...@main`) are intentionally kept on `@main`.
