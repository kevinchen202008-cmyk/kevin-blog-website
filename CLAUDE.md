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

**GitHub Actions** (`.github/workflows/deploy.yml`) triggers on push to `main`:
1. Builds with `hugo --minify`
2. rsyncs `public/` to the ECS server via SSH

**Required GitHub Secrets:**

| Secret | Value |
|--------|-------|
| `ECS_HOST` | Alibaba Cloud ECS public IP |
| `ECS_USER` | SSH username (e.g. `root` or `ubuntu`) |
| `ECS_SSH_KEY` | Private key content (the ECS key pair) |
| `DEPLOY_PATH` | Remote path, e.g. `/var/www/kevin-blog` |

**Nginx** (`nginx.conf`) — copy to `/etc/nginx/sites-available/kevin-blog` on the ECS, symlink to `sites-enabled/`, then `nginx -s reload`. Update `server_name` to your actual domain.

### Configuration

`hugo.toml` — key settings to update before going live:
- `baseURL` — set to your actual domain
- `params.avatar` — place your photo at `static/images/avatar.jpg`
- `params.github`, `params.email`, `params.author` — your info
