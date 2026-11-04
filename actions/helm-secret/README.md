## Helm Secret - GitHub Action

Creates or updates the Kubernetes Secret the charts of a cluster read, and exports the
chart secrets their values files reference, both from the secrets and variables of the
GitHub environment of the calling job.

It is the second step of the deploy pipeline every `*-deploy` repository runs; the
canonical shape of the two jobs is in
[../../.github/workflows/README.md](../../.github/workflows/README.md).

### Inputs

| Input              | Required | Description                                                               |
| ------------------ | -------- | ------------------------------------------------------------------------- |
| `environment`      | Yes      | The GitHub environment of the job, for the messages.                      |
| `secret-name`      | No       | Kubernetes Secret to create or update. Empty skips that part.             |
| `secret-namespace` | No       | Namespace of `secret-name`. Required when `secret-name` is set.           |
| `secret-keys`      | No       | Keys of `secret-name`, one per line. Required when `secret-name` is set.  |
| `chart-secrets`    | No       | Secrets the `chartSecrets` blocks of the values files reference.          |

### The values arrive in the environment, not in `with:`

The name of an `env:` key cannot be an expression, so a name of `secret-keys` cannot be
turned into a value by the workflow. The whole objects are handed over instead, and the
action looks each name up in them:

```yaml
- uses: 2060-io/organization/actions/helm-secret@main
  with:
    environment: ${{ matrix.environment }}
    secret-name: hologram-secrets
    secret-namespace: ${{ matrix.namespace }}
    secret-keys: |
      MEDIATOR_WALLET_KEY
      OPENAI_API_KEY=openai-key
      FIREBASE_CONFIG=@firebase-config.json
      vars:GH_AGENT_CREDENTIAL_DEFINITION_ID
    chart-secrets: INDEXER_POSTGRES_PWD
  env:
    KUBECONFIG_CONTENT: ${{ secrets.KUBECONFIG }}
    SECRETS_JSON: ${{ toJSON(secrets) }}
    VARS_JSON: ${{ toJSON(vars) }}
```

| `env:` key           | Description                                                             |
| -------------------- | ----------------------------------------------------------------------- |
| `KUBECONFIG_CONTENT` | The kubeconfig of the cluster, in plain text. Required by `secret-name`. |
| `SECRETS_JSON`       | `${{ toJSON(secrets) }}`. Required.                                     |
| `VARS_JSON`          | `${{ toJSON(vars) }}`. Required by a `vars:` name.                      |

Nothing secret reaches a `with:` block, so no value shows in the inputs group of the
log, and `--from-file` keeps the values out of the process list.

### The forms of `secret-keys`

| Line                                   | Key it writes                            |
| -------------------------------------- | ---------------------------------------- |
| `MEDIATOR_WALLET_KEY`                  | `MEDIATOR_WALLET_KEY`                    |
| `OPENAI_API_KEY=openai-key`            | `openai-key`                             |
| `FIREBASE_CONFIG=@firebase.json`       | `firebase.json`, written as a file       |
| `vars:GH_AGENT_CRED_DEF_ID`            | value read from `VARS_JSON`              |

**CAUTION:** the apply removes every key it does not write. A name with no value stops
the run when the Secret already holds its key, and only warns when it does not, so a
key is never dropped by accident.

### Requirements

The job declares `environment:`, which is the only way the secrets and variables of
that environment resolve. A job that calls a reusable workflow cannot declare one, and
`secrets: inherit` passes nothing to a workflow of another organization, so the first
step of this action stops the run when the `secrets` context holds nothing but
`github_token`.
