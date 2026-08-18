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

## Runner image

`Dockerfile` extends `myoung34/github-runner:latest` with `uv` preinstalled, so workflows can use `uv pip install` instead of plain `pip`. Both compose files build this image locally (`build: .`) rather than pulling the base image directly.

## Setup

### Organization Runner

For running jobs across entire GitHub organization:

```bash
cp .env.org.sample .env
# edit .env with your org name and token (scope: admin:org_hook)
docker compose -f docker-compose.org.yml up -d --build
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
docker compose -f docker-compose.repo.yml up -d --build
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

## Docker access inside jobs

Jobs that run `docker build`/`docker push` need access to a Docker daemon. Each compose file mounts a host Docker socket into the runner at `/var/run/docker-host.sock` and sets `DOCKER_HOST=unix:///var/run/docker-host.sock`, so the container's `docker` CLI talks to it automatically — no `sudo` or extra flags needed in workflow steps.

**Check which socket to mount before first run:**

```bash
docker context ls
```

If the `*` marks `rootless`, your daemon lives at `/run/user/<uid>/docker.sock`, not `/var/run/docker.sock` — the two are separate daemons on a rootless install. The compose files here are set to `/run/user/1000/docker.sock`; adjust the uid if yours differs. Binding the wrong path doesn't error — dockerd silently mounts an empty placeholder directory instead of the socket, and every `docker` command inside the runner fails with `Cannot connect to the Docker daemon`. If that happens, verify:

```bash
docker exec <runner-container> stat /var/run/docker-host.sock
```

It must report type `socket`, not `directory`. We avoid mounting straight to `/var/run/docker.sock` inside the container because the base runner image already has a directory baked in at that exact path, which silently blocks the bind mount the same way.

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

# Rebuild runner image (after Dockerfile or base image changes) and restart
docker compose -f docker-compose.org.yml up -d --build

# Full reset: drop containers, volumes, and orphans, then rebuild
docker compose -f docker-compose.org.yml down -v --remove-orphans
docker compose -f docker-compose.org.yml up -d --build
```

## Security notes

- **Never enable these runners for public repositories.** Any fork can open a PR that runs arbitrary code on your host.
- The container mounts the host Docker socket so jobs can build images. This grants jobs root-equivalent access to the Docker host — only run trusted workflows from private repos in your org.
- `.env` holds a token that can administer org/repo runners. It is gitignored; do not commit it, and rotate the token if it leaks.
- Never commit a real token into a `.env.*.sample` file, even temporarily — GitHub push protection will block the push, but rotate the token anyway if one ever lands in a commit.
