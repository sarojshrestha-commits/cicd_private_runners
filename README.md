# Self-Hosted GitHub Actions Runner

Docker Compose setup for ephemeral self-hosted GitHub Actions runners.

Choose setup based on scope:
- **Organization-scoped** — runs jobs across entire org
- **Repository-scoped** — runs jobs for single private repo

The CI/CD setup has two parts:

1. **Runners** — the machines that execute workflow jobs (this repo)
2. **Repo** — the application repo whose workflows target these runners

## Requirements

- Docker Engine + Docker Compose v2
- GitHub account with appropriate permissions
- PAT (Personal Access Token) with correct scopes

## Setup

### Organization Runner

For running jobs across entire GitHub organization:

```bash
cp .env.org.sample .env
# edit .env with your org name and token (scope: admin:org_hook)
docker compose -f docker-compose.org.yml up -d
```

Verify registration:

```bash
docker compose -f docker-compose.org.yml logs -f org-runner
```

Check **Org Settings → Actions → Runners**.

### Repository Runner

For running jobs in a single private repository:

```bash
cp .env.repo.sample .env
# edit .env with repo URL and token (scopes: repo, admin:repo_hook)
docker compose -f docker-compose.repo.yml up -d
```

Verify registration:

```bash
docker compose -f docker-compose.repo.yml logs -f repo-runner
```

Check **Repo Settings → Actions → Runners**.

## Configuration

Set in `.env` (use `.env.org.sample` or `.env.repo.sample` as template):

### Organization Runner Variables

| Variable | Description | Example |
|---|---|---|
| `ORG_NAME` | GitHub organization name | `my-org` |
| `ACCESS_TOKEN` | PAT with `admin:org_hook` scope | `ghp_xxxx` |
| `RUNNER_SCOPE` | Registration scope | `org` |
| `RUNNER_NAME` | Runner name shown in GitHub | `org-runner-1` |
| `LABELS` | Comma-separated job routing labels | `self-hosted,linux,x64` |
| `EPHEMERAL` | Deregister + reset after each job | `true` |

### Repository Runner Variables

| Variable | Description | Example |
|---|---|---|
| `REPO_URL` | Full GitHub repo URL | `https://github.com/username/repo` |
| `ACCESS_TOKEN` | PAT with `repo` + `admin:repo_hook` scopes | `ghp_xxxx` |
| `RUNNER_SCOPE` | Registration scope | `repo` |
| `RUNNER_NAME` | Runner name shown in GitHub | `repo-runner-1` |
| `LABELS` | Comma-separated job routing labels | `self-hosted,linux,x64` |
| `EPHEMERAL` | Deregister + reset after each job | `true` |

**Token Scopes:**
- Org runners: `admin:org_hook`
- Repo runners: `repo` + `admin:repo_hook`

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

Replace `docker-compose.org.yml` with `docker-compose.repo.yml` if using repo-scoped runner:

```bash
# Tail logs
docker compose -f docker-compose.org.yml logs -f org-runner

# Restart
docker compose -f docker-compose.org.yml restart org-runner

# Stop and deregister
docker compose -f docker-compose.org.yml down

# Update runner image
docker compose -f docker-compose.org.yml pull && docker compose -f docker-compose.org.yml up -d
```

## Security notes

- **Never enable these runners for public repositories.** Any fork can open a PR that runs arbitrary code on your host.
- The container mounts `/var/run/docker.sock` so jobs can build images. This grants jobs root-equivalent access to the Docker host — only run trusted workflows from private repos in your org.
- `.env` holds a token that can administer org runners. It is gitignored; do not commit it, and rotate the token if it leaks.
