# AGENTS.md

Defaults for coding agents, and for anyone, working in the 2060-io and verana-labs repositories. A repository's own `AGENTS.md` adds what is specific to it (layout, commands, environments, traps) and wins where the two differ. Link this file from it rather than copying it.

The full rules are in [basic-rules.md](./basic-rules.md). This file is the short version.

## Before you change anything

- Read the repository's README and `AGENTS.md`. Fetch and work on the latest `main`.
- Components that implement a specification (for example in [verana-spec](https://github.com/verana-labs/verana-spec) or the VPR spec) follow it: read the relevant section first, and cite the requirement ids in the PR.
- Use the package manager and versions the repository pins (`packageManager` in `package.json`, the lockfile, `go.mod`). Run tools through it (`pnpm exec biome`, not a global or `npx` copy). Do not add a dependency without a reason the PR states.

## Branches, commits, pull requests

- Branch from `main`: `type/short-description`, optionally with the issue number (`fix/524-keyset-windows`).
- Conventional Commits: `feat`, `fix`, `perf`, `refactor`, `build`, `chore`, `docs`, `ci`, `test`, an optional scope, `!` for a breaking change. Sign off with `git commit -s`.
- One concern per PR. Its title is a conventional commit and becomes the squash commit on `main`; CI validates it, and the commit subject too when the PR has a single commit.
- Link the issue with `Closes #N`. Explain why, not what the diff already shows.
- Never push to `main`, to bot branches (`release-please--*`, `dependabot/*`, `autobump/*`) or to the `release` branch, and never force-push a branch someone else works on.

## Releases follow the commit type

| Commit | Development release (`vX.Y.Z-dev.N`, on every push to `main`) | Stable release (Release Please PR) |
|---|---|---|
| `feat`, `fix`, `perf`, breaking change | yes | yes |
| `refactor`, `build` | yes | no |
| `chore`, `docs`, `ci`, `test` | no | no |

Do not edit `CHANGELOG.md` or `.release-please-manifest.json`: the release pipeline owns them.

## Checks before pushing

For pnpm projects, run what the shared CI ([2060-linter-call.yml](./.github/workflows/docs/2060-linter.md)) runs:

```bash
pnpm install --frozen-lockfile
pnpm build
pnpm check-format
pnpm check-types
pnpm test
```

Other repositories (Go, specs, docs, deployment) list their commands in their README or `AGENTS.md`.

Know what CI picks up on its own:

- `pnpm test:integration` and `pnpm test:e2e` run whenever a script with that name exists. Use those names only for suites that pass on a plain runner, without secrets or funded accounts.
- Helm charts are linted under `./charts/<name>/`; a chart at `./charts/Chart.yaml` needs `charts-dir: ./charts`.

## Generated and shared things

- Do not hand-edit generated files (protobuf and ts-proto output, rendered spec HTML, OpenAPI exports, changelogs). Change the source and regenerate.
- Pin actions and reusable workflows, ours included, to a release commit SHA with the version in a comment. Do not add or widen CI triggers, permissions or secrets without a maintainer's agreement.
- Never commit secrets or real `.env` values.
- Shared environments (devnet, testnet) change through the deployment repositories and their workflows, following those repositories' `AGENTS.md`, never by hand.

## Keep this file true

When a change makes this file or a repository's `AGENTS.md` wrong, update it in the same PR.
