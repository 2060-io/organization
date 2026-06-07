# Discord Release Notify Workflow Documentation

## Overview

The **Discord Release Notify** workflow posts a Discord embed to a configured webhook for a published GitHub Release. It is **tag-driven**: the caller passes the release tag, and the workflow looks the release up via the GitHub API, so it works regardless of how the release was created (release-please, semantic-release, manual). It supports both stable and prerelease GitHub Releases and renders the release body as the embed description.

It is designed to be invoked as a **reusable workflow** through [`workflow_call`](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

---

## Inputs

* **`tag_name`** *(required)* — the release tag to announce, e.g. `v1.2.3`. The workflow fetches the matching GitHub Release (`GET /repos/{owner}/{repo}/releases/tags/{tag}`) and reads its body, URL, prerelease flag and timestamp.

## Secrets

* **`DISCORD_UPDATES_WEBHOOK_URL`** *(optional, required to actually post)* — Discord channel webhook URL. The workflow logs a warning and exits 0 if unset, so it is safe to enable before the secret is configured.

Pass the secret **explicitly** rather than `secrets: inherit`. The reusable workflow lives in a different org (`2060-io`), and inherited secrets are not reliably forwarded across the org boundary.

---

## Why tag-driven (and not `release: published`)

Releases cut by release-please / semantic-release run on the default `GITHUB_TOKEN`, and GitHub does **not** emit the `release: published` event for token-created releases. A standalone workflow keyed on `release: published` therefore never fires for those repos. Instead, call this workflow from the same job that creates the release (gated on the release-creation output), and pass the tag explicitly.

---

## Usage

### release-please pipeline (stable)

```yaml
name: Release Please

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      notify_tag:
        description: "Release tag to (re)announce on Discord, e.g. v1.2.0"
        required: true
        type: string

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - id: release
        uses: googleapis/release-please-action@v4
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

  discord-notify:
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    permissions:
      contents: read
    uses: 2060-io/organization/.github/workflows/discord-release-notify-call.yml@main
    with:
      tag_name: ${{ needs.release-please.outputs.tag_name }}
    secrets:
      DISCORD_UPDATES_WEBHOOK_URL: ${{ secrets.DISCORD_UPDATES_WEBHOOK_URL }}

  # Manual (re)send for an existing tag, no new release required.
  discord-notify-manual:
    if: github.event_name == 'workflow_dispatch'
    permissions:
      contents: read
    uses: 2060-io/organization/.github/workflows/discord-release-notify-call.yml@main
    with:
      tag_name: ${{ inputs.notify_tag }}
    secrets:
      DISCORD_UPDATES_WEBHOOK_URL: ${{ secrets.DISCORD_UPDATES_WEBHOOK_URL }}
```

Use `releases_created` instead of `release_created` if your release-please manifest is multi-package.

### resolve-version pipeline

If your repo resolves versions through `resolve-version-call.yml`, gate on its outputs instead (this example is stable only):

```yaml
  discord-notify:
    needs: resolve-version
    if: needs.resolve-version.outputs.new-release-published == 'true' && needs.resolve-version.outputs.release-type == 'stable'
    permissions:
      contents: read
    uses: 2060-io/organization/.github/workflows/discord-release-notify-call.yml@main
    with:
      tag_name: ${{ needs.resolve-version.outputs.release-version }}
    secrets:
      DISCORD_UPDATES_WEBHOOK_URL: ${{ secrets.DISCORD_UPDATES_WEBHOOK_URL }}
```

Then configure `DISCORD_UPDATES_WEBHOOK_URL` as a repository secret or an organization secret that grants access to the consuming repository.

---

## Behavior

For the resolved release the workflow posts an embed with:

* **Title:** `${repo_name} ${tag}` (for example `verana-frontend v0.12.0`).
* **Description:** the release body markdown, truncated to 3800 characters with a "View full release on GitHub" link appended when truncation occurs.
* **URL:** the release HTML URL.
* **Color:** green for stable releases, amber for prereleases.
* **Footer:** `${owner}/${repo} (stable|prerelease)`.
* **Timestamp:** the release `published_at`.

---

## Failure Modes

* **Missing webhook URL:** the job logs a workflow warning and exits 0. The release flow is unaffected.
* **Tag not found:** the release lookup fails the job. Gate `discord-notify` on the release-creation output so it only runs once the release exists.
* **Discord returns non-2xx:** the job logs the HTTP status and response body, then fails. The release itself is unaffected.
* **Empty release body:** replaced with `(No release notes provided.)`.
* **Very long release body:** truncated to 3800 characters with a link to the full release.

---

## Notes

* The workflow uses `curl`, `jq` and `gh`, all available on `ubuntu-latest` runners. No external action dependencies.
* The release lookup uses the automatic `GITHUB_TOKEN` with `contents: read`.
