# Helm Deploy 2060 – GitHub Action

This GitHub Action detects changed Helm values files and deploys Helm charts accordingly. It supports multi-environment deployments (`dev`, `prod`), dynamic release detection, and optional overrides for production environments.

## Use Case

Deploy Helm charts only when values or override files change, with environment-aware customization.

---

## Usage

```yaml
- name: Helm Deploy
  uses: 2060-io/devops/actions/helm-deploy@main
  with:
    environment: dev
    namespace: my-namespace
    valuesDir: values
    domain: mydomain.com
```

### Trigger only on changes (suggested)

In your workflow, you might combine this with a conditional or path filter for performance:

```yaml
on:
  push:
    paths:
      - 'values/**'
      - 'pro/**'
```

---

## Inputs

| Name           | Required | Description                                                       |
| -------------- | -------- | ----------------------------------------------------------------- |
| `environment`  | Yes    | Deployment environment. Must be either `dev` or `prod`.           |
| `namespace`    | Yes    | Kubernetes namespace to deploy into.                              |
| `valuesDir`    | Yes    | Directory where Helm values files are stored. Example: `values/`  |
| `overridesDir` | No     | Directory for environment-specific overrides. Required in `prod`. |
| `domain`       | No     | Passed as `--set global.domain=...` during Helm install/upgrade.  |
| `release`      | No     | Explicit release to deploy, bypassing change detection.           |

---

## How It Works

### 1. Validate Inputs

Ensures `environment`, `namespace`, and `valuesDir` are defined and that `overridesDir` is provided in non-`dev` environments.

### 2. Detect Changed Files

* If `release` is provided: deploy only that one.
* Otherwise:

  * Scans changed `.yaml` files in `valuesDir` and (if `prod`) `overridesDir`.
  * Computes base filenames to identify which Helm releases changed.

### 3. Deploy Using Helm

For each detected release:

* Extracts `chartSource` and `chartVersion` from the YAML.
* Applies overrides if present.
* Sets `global.domain` if provided.
* Executes `helm upgrade --install`.

---

## Example File Structure

```
values/
├── service-a.yaml   # chartSource: ./charts/service-a
├── service-b.yaml   # chartSource: ./charts/service-b

pro/
├── service-a.yaml   # Production overrides

charts/
└── service-a/
```

---

## Example YAML Value File

```yaml
chartSource: ./charts/service-a
chartVersion: 1.2.3
chartSecrets:
  - name: DB_PASSWORD        # GitHub Actions secret name
    path: app.config.dbPassword
  - name: API_KEY
    path: app.config.apiKey

replicaCount: 2
image:
  repository: myrepo/service-a
  tag: latest
```

## How Secrets Are Used

* The `chartSecrets` section does **not** contain actual secret values, only mappings (`name` → `path`).
* GitHub Actions secrets (e.g., `DB_PASSWORD`, `API_KEY`, `EMAIL_PASS`, `TESTING`) must be defined under **Settings → Secrets and variables → Actions** in your repository.
* During deployment, these secrets are exported as **environment variables** (e.g. `$DB_PASSWORD`, `$API_KEY`) and then mapped dynamically according to the `chartSecrets` configuration.
* At runtime, the script resolves them and generates Helm arguments such as:

```bash
--set app.config.dbPassword=$DB_PASSWORD \
--set app.config.apiKey=$API_KEY \
--set name=$EMAIL_PASS \
--set app.config.testing=$TESTING
```

This ensures secrets are securely injected at deployment time without being exposed in your repository or action inputs.

---

### Usage with secrets

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Helm Deploy
        uses: 2060-io/devops/actions/helm-deploy@main
        with:
          environment: dev
          namespace: my-namespace
          valuesDir: values
          domain: mydomain.com
        env:
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
          EMAIL_PASS: ${{ secrets.EMAIL_PASS }}
          TESTING: ${{ secrets.TESTING }}
```

---

## Best Practices

* Store sensitive data (e.g., Helm credentials) as [GitHub Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets).

---

## Repo Structure

```text
.github/
└── actions/
    └── helm-deploy-2060/
        ├── action.yml
        └── README.md
```