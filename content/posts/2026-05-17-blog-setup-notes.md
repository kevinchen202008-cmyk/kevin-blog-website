---
title: "用 Hugo + Docker + 阿里云 ECS 搭建个人博客全记录"
date: 2026-05-17T18:00:00+08:00
draft: false
categories: ["技术"]
tags: ["Hugo", "Docker", "GitHub Actions", "阿里云", "Watchtower", "博客"]
description: "从零搭建这个博客的完整过程：技术选型、自定义主题、Docker 容器化、CI/CD 自动部署，以及一路踩过的坑。"
---

这篇文章记录了搭建本博客的全过程。从选型到上线，中间踩了不少坑，一并写下来，希望对有类似需求的人有参考价值。

## 技术选型

目标很简单：一个干净的中文技术博客，能低成本长期维护，写文章体验好。

最终选型：

| 层次 | 技术 |
|------|------|
| 静态站点生成 | Hugo |
| 容器化 | Docker（多阶段构建） |
| 镜像仓库 | GitHub Container Registry（ghcr.io） |
| CI/CD | GitHub Actions |
| 自动部署 | Watchtower |
| 服务器 | 阿里云 ECS（Ubuntu 24.04）|
| Web 服务 | Nginx（运行在容器内）|

**为什么选 Hugo 而不是 Hexo / Jekyll？**

Hugo 用 Go 编写，构建速度极快，一个有几百篇文章的站点通常在 1 秒内构建完毕。文章用 Markdown 写，版本控制天然友好。相比 Jekyll 不需要 Ruby 环境，比 Hexo 少很多 Node.js 依赖。

**为什么自己写主题而不是用现成的？**

参考了[阮一峰的网络日志](https://www.ruanyifeng.com/blog/)的风格——双栏布局、白底黑字、极度克制——市面上能找到的主题要么太花哨，要么依赖太多。从零写一个自定义主题，代码量不大（一个 CSS 文件 + 几个 HTML 模板），完全可控。

---

## 主题结构

Hugo 的模板系统很清晰，整个主题只用了这几个文件：

```
layouts/
  _default/
    baseof.html     # 主框架：HTML head + 双栏布局
    single.html     # 文章详情页
    list.html       # 分类/标签列表页
    archives.html   # 归档页（由 content/archives.md 驱动）
  partials/
    header.html     # 顶部导航
    footer.html     # 页脚
    sidebar.html    # 侧边栏（关于、最新文章、分类、标签云）
  index.html        # 首页文章列表（分页）
  404.html
static/
  css/style.css     # 全部样式
```

CSS 没有引入任何框架，手写约 400 行，主色用了 `#c0392b`（暗红），字体优先 `PingFang SC`、`Microsoft YaHei`，行高 1.8，阅读体验比较舒适。

---

## Docker 多阶段构建

把 Hugo 站点打包进 Docker 镜像，用了经典的多阶段构建：

```dockerfile
# Stage 1：构建 Hugo 站点
FROM debian:bookworm-slim AS builder

ARG HUGO_VERSION=0.161.1
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin hugo

WORKDIR /site
COPY . .
RUN hugo --minify

# Stage 2：用 Nginx 提供服务
FROM nginx:alpine
COPY --from=builder /site/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

最终镜像只有 Nginx + 静态文件，不含任何构建工具，体积很小。

**踩坑 1：不要用 `hugomods/hugo:exts` 作为构建镜像**

最初用的是 `hugomods/hugo:exts` 这个社区镜像，结果 CI 一直报错：

```
can't evaluate field Locale in type *langs.Language
```

原因是这个镜像内置的 Hugo 版本是 v0.154.5，而本地安装的是 v0.161.1。`.Site.Language.Locale` 这个 API 在 v0.155 才引入，旧版本没有。

解决方法：从 GitHub Releases 直接下载指定版本的 Hugo 二进制，彻底固定版本，本地和 CI 行为一致。

**踩坑 2：`paginate` 配置键已移除**

Hugo 在 v0.128.0 把顶层的 `paginate = 10` 移除了，改成：

```toml
[pagination]
  pagerSize = 10
```

旧写法在某些版本会静默失效，在某些版本直接报错退出。

---

## CI/CD 流程

GitHub Actions 的工作流很精简，只负责两件事：

```yaml
# .github/workflows/deploy.yml
- 登录 ghcr.io（用内置的 GITHUB_TOKEN，不需要额外配置 Secret）
- docker build + push → ghcr.io/kevinchen202008-cmyk/kevin-blog:latest
```

镜像推到 GHCR 之后，部署交给服务器上的 **Watchtower** 来完成。

---

## 部署：为什么用 Watchtower 而不是 SSH

原计划是 GitHub Actions 构建完镜像后，SSH 到 ECS 执行 `docker compose up`。工作流写好了，GitHub Secrets 也配好了，但 SSH 一直超时：

```
dial tcp ***.***.***.***:22: i/o timeout
```

阿里云的安全组已经开了 22 端口对 `0.0.0.0/0` 放行，但 GitHub Actions 的 runner 还是连不进来。根本原因至今没查清楚（可能是 VPC 层面的网络 ACL，或者是 Cloud Firewall），但找到了更优雅的替代方案——**Watchtower**。

Watchtower 是一个 Docker 容器，专门监听同一台机器上其他容器使用的镜像是否有更新。配置很简单：

```yaml
services:
  blog:
    image: ghcr.io/kevinchen202008-cmyk/kevin-blog:latest
    ports:
      - "80:80"
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"   # 标记此容器受 Watchtower 管理

  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 60 --cleanup --label-enable    # 每 60 秒轮询一次
    restart: unless-stopped
```

完整的部署链路变成：

```
git push main
    │
    ▼  GitHub Actions
 ① docker build（Hugo 构建 → Nginx 镜像）
 ② docker push → ghcr.io/...:latest
    │
    ↑  ECS 上的 Watchtower（每 60 秒）
 ③ 检测到新的 :latest → docker pull → 重启 blog 容器
```

这个方案的好处是**不需要任何入站端口**（除了 80），ECS 只有出站的 HTTPS 流量去拉镜像。即使将来换服务器，也只需要在新机器上启动这个 docker-compose，其余不用动。

唯一的延迟是最多 60 秒，对于博客来说完全可以接受。

---

## 一个低级失误：占位域名

`hugo.toml` 里的 `baseURL` 最初设的是 `https://yourdomain.com/`，作为上线前的占位符。

结果有用户反馈，点"阅读全文"会跳转到 `https://www.bedpage.com/404`。

原因很简单：`yourdomain.com` 这个域名是真实存在的，而且它做了 302 重定向，跳到了一个不相干的网站。Hugo 生成的所有内部链接都用 `baseURL` 拼接，所以每个"阅读全文"都变成了 `yourdomain.com/posts/...`，再被重定向走。

教训：**占位域名要用私有 IP 或 `localhost`，不要用看起来像真实域名的字符串。**

---

## 最终架构

```
┌─────────────────────────────────────────────────────────┐
│  开发者本地                                               │
│  hugo server -D  →  写文章  →  git push main            │
└──────────────────────────┬──────────────────────────────┘
                           │ push 触发
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions                                          │
│  docker build (debian + Hugo 0.161.1 → nginx:alpine)   │
│  docker push → ghcr.io/.../kevin-blog:latest            │
└──────────────────────────┬──────────────────────────────┘
                           │ 镜像更新
                           ▼
┌─────────────────────────────────────────────────────────┐
│  阿里云 ECS（Ubuntu 24.04）                              │
│  ┌──────────────────┐  ┌─────────────────────────────┐ │
│  │  blog 容器        │  │  watchtower 容器             │ │
│  │  nginx:alpine    │  │  每 60s 轮询 ghcr.io         │ │
│  │  :80 → 静态页面   │  │  有新镜像 → 重启 blog        │ │
│  └──────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

代码仓库：[github.com/kevinchen202008-cmyk/kevin-blog-website](https://github.com/kevinchen202008-cmyk/kevin-blog-website)

---

## 写新文章

```bash
# 创建文章
hugo new posts/YYYY-MM-DD-title.md

# 本地预览
hugo server -D

# 发布（推送后约 1 分钟自动上线）
git add . && git commit -m "post: 文章标题" && git push
```

就这样，博客搭好了。
