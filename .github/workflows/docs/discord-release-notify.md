# Discord Release Notify Workflow Documentation

## Overview

The **Discord Release Notify** workflow posts a Discord embed to a configured webhook whenever a GitHub Release is published in a consuming repository. It supports both stable and prerelease GitHub Releases and renders the release body as the embed description.

It is designed to be invoked as a **reusable workflow** through [`workflow_call`](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

---

## Workflow Triggers

This workflow is triggered via `workflow_call`. The calling workflow is expected to fire on `release: published`:

```yaml
on:
  release:
    types: [published]
```

### Secrets

* **`DISCORD_UPDATES_WEBHOOK_URL`** *(optional, but required for notifications to actually post)*
  Discord channel webhook URL. The workflow exits with a warning if this is unset, so it is safe to enable the workflow before the secret is configured.

---

## Behavior

For each published release the workflow posts an embed with:

* **Title:** `${repo_name} ${tag}` (for example `verana-frontend v0.12.0`).
* **Description:** The release body markdown, truncated to 3800 characters with a "View full release on GitHub" link appended when truncation occurs.
* **URL:** The release HTML URL.
* **Color:** Green for stable releases, amber for prereleases.
* **Footer:** `${owner}/${repo} (stable|prerelease)`.
* **Timestamp:** The release `published_at`.

The workflow runs only when the calling workflow was triggered by a `release: published` event. Any other event causes the job to be skipped via job-level `if`.

---

## Usage Example

In a consuming repository:

```yaml
name: Discord Release Notify

on:
  release:
    types: [published]

jobs:
  notify:
    uses: 2060-io/organization/.github/workflows/discord-release-notify-call.yml@main
    secrets: inherit
```

Then configure `DISCORD_UPDATES_WEBHOOK_URL` either as a repository secret or as an organization secret that grants access to the consuming repository.

---

## Failure Modes

* **Missing webhook URL:** The job logs a workflow warning and exits 0. The release flow is unaffected.
* **Discord returns non-2xx:** The job logs the HTTP status and response body, then fails. The release itself is unaffected because the notification job runs after the release is already published.
* **Empty release body:** Replaced with `(No release notes provided.)`.
* **Very long release body:** Truncated to 3800 characters with a link to the full release.

---

## Notes

* The workflow uses `curl` and `jq` only, both available on `ubuntu-latest` runners. No external action dependencies.
* The webhook URL is read from `secrets.DISCORD_UPDATES_WEBHOOK_URL`. To use it via an org-level secret, the calling workflow must pass `secrets: inherit`.
