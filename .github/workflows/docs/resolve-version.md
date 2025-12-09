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
| `release-type`          | Type of release: `latest`, `dev`, or `none`                |
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
        uses: actions/checkout@v4

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
        uses: actions/checkout@v4

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
