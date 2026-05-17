# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Local dev server (live reload, drafts included)
hugo server -D

# Production build
hugo --minify

# Create a new post
hugo new posts/YYYY-MM-DD-title.md
```

## Architecture

This is a **Hugo** static site with a fully custom theme (no external theme dependency). All templates live in `layouts/`, all styles in `static/css/style.css`.

### Layout hierarchy

- `layouts/_default/baseof.html` — master shell (HTML head, two-column grid: `main-content` + `sidebar`)
- `layouts/index.html` — homepage post list (paginated)
- `layouts/_default/list.html` — category / tag / section post lists
- `layouts/_default/single.html` — individual post page
- `layouts/_default/archives.html` — driven by `content/archives.md` via `layout: "archives"` front matter
- `layouts/partials/` — `header.html`, `footer.html`, `sidebar.html`

### Content structure

```
content/
  posts/          # Blog articles (Markdown)
  about.md        # About page (layout: single)
  archives.md     # Archive index (layout: archives)
```

Front matter for posts:
```yaml
title: ""
date: 2024-01-01T00:00:00+08:00
draft: false
categories: ["技术"]
tags: ["tag1", "tag2"]
description: ""   # Used as excerpt on list pages
```

### Deployment

**Stack:** Docker (multi-stage build) → Docker Hub → Alibaba Cloud ECS (Ubuntu)

**GitHub Actions** (`.github/workflows/deploy.yml`) triggers on push to `main`:
1. Builds multi-stage Docker image (`hugomods/hugo:exts` → `nginx:alpine`)
2. Pushes to Docker Hub as `DOCKER_USERNAME/kevin-blog:latest` and `:GIT_SHA`
3. SSHes into ECS, writes `docker-compose.yml`, runs `docker compose up -d`

**Required GitHub Secrets:**

| Secret | Value |
|--------|-------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token |
| `ECS_HOST` | Alibaba Cloud ECS public IP |
| `ECS_USER` | SSH username (`root` or `ubuntu`) |
| `ECS_SSH_KEY` | ECS SSH private key contents |

**First-time ECS setup** — run once on the server:
```bash
bash scripts/setup-ecs.sh
```

**Local Docker test** (before pushing):
```bash
docker build -t kevin-blog .
docker run -p 8080:80 kevin-blog
# open http://localhost:8080
```

**Nginx** config is baked into the image (`nginx.conf` → `/etc/nginx/conf.d/default.conf`). Logs go to Docker stdout/stderr (`docker logs <container>`).

### Configuration

`hugo.toml` — key settings to update before going live:
- `baseURL` — set to your actual domain
- `params.avatar` — place your photo at `static/images/avatar.jpg`
- `params.github`, `params.email`, `params.author` — your info
