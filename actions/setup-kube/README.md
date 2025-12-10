# Setup Kubeconfig GitHub Action

This GitHub Action sets up the Helm CLI and configures access to a Kubernetes cluster using a base64-encoded `kubeconfig`. It is designed to be reused across multiple repositories in your organization.

## Usage

```yaml
- name: Setup kubeconfig and Helm
  uses: 2060-io/devops/actions/setup-kube@main
  with:
    kubeconfig: ${{ secrets.KUBECONFIG }}
```

> It's recommended to store your base64-encoded `kubeconfig` as a GitHub secret.

## Inputs

| Name         | Description                                       | Required |
| ------------ | ------------------------------------------------- | -------- |
| `kubeconfig` | Base64-encoded KUBECONFIG file for cluster access | ✅ Yes    |

## What it does

1. Installs Helm using the [`azure/setup-helm`](https://github.com/Azure/setup-helm) action.
2. Decodes the base64-encoded `kubeconfig` into a temporary file inside the GitHub workspace.
3. Sets the `KUBECONFIG` environment variable so that subsequent steps (e.g., `helm install`) can access the cluster.

## Example with Helm

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup kubeconfig
        uses: 2060-io/devops/actions/setup-kube@main
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Helm install
        run: helm upgrade --install my-app ./charts/my-app --namespace default
```

## Structure

```text
└── actions/
    └── setup-kube/
        └── action.yml
```

## Security Note

* Always store your `kubeconfig` securely using [GitHub secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets).
* Avoid committing raw `kubeconfig` files in your repositories.
