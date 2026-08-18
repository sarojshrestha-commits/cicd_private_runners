# Self-Hosted GitHub Actions Runner

Docker Compose setup for an org-scoped, ephemeral self-hosted GitHub Actions runner.

The CI/CD setup has two parts:

1. **Runners** — the machines that execute workflow jobs (this repo)
2. **Repo** — the application repo whose workflows target these runners

## Requirements

- Docker Engine + Docker Compose v2
- A GitHub org you have admin rights on
- A PAT (classic) with `admin:org` scope, or a fine-grained token with org self-hosted runner permissions

## Setup

```bash
cp .env.sample .env
# edit .env with your org name and token
docker compose up -d
```

Verify the runner registered:

```bash
docker compose logs -f org-runner
```

It should also appear under **Org Settings → Actions → Runners**.

## Configuration

Set in `.env`:

| Variable | Description | Example |
|---|---|---|
| `ORG_NAME` | GitHub organization name | `my-org` |
| `ACCESS_TOKEN` | PAT with `admin:org` scope | `ghp_xxxx` |
| `RUNNER_SCOPE` | Registration scope | `org` |
| `RUNNER_NAME` | Runner name shown in GitHub | `hetzner-org-runner` |
| `LABELS` | Comma-separated job routing labels | `self-hosted,linux,x64` |
| `EPHEMERAL` | Deregister + reset after each job | `true` |

`EPHEMERAL=true` is recommended: each job gets a clean runner, so no state leaks between workflow runs.

## Using the runner

In a workflow in any repo in the org:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - run: echo "running on self-hosted"
```

The `runs-on` labels must match `LABELS` in `.env`.

## Scaling

Run more runners by scaling the service:

```bash
docker compose up -d --scale org-runner=3
```

Leave `RUNNER_NAME` unset when scaling so each container generates its own name.

## Operations

```bash
docker compose logs -f org-runner   # tail logs
docker compose restart org-runner   # restart
docker compose down                 # stop and deregister
docker compose pull && docker compose up -d   # update runner image
```

## Security notes

- **Never enable these runners for public repositories.** Any fork can open a PR that runs arbitrary code on your host.
- The container mounts `/var/run/docker.sock` so jobs can build images. This grants jobs root-equivalent access to the Docker host — only run trusted workflows from private repos in your org.
- `.env` holds a token that can administer org runners. It is gitignored; do not commit it, and rotate the token if it leaks.
