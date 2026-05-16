---
title: "Hugo 静态博客搭建指南"
date: 2024-02-01T09:00:00+08:00
draft: false
categories: ["技术"]
tags: ["Hugo", "博客", "静态网站"]
description: "从零开始搭建一个 Hugo 博客，包括本地开发、主题定制和部署到服务器的完整流程。"
---

Hugo 是目前最快的静态网站生成器之一，本文记录搭建流程。

## 安装 Hugo

在 macOS 上：

```bash
brew install hugo
```

在 Windows 上：

```powershell
winget install Hugo.Hugo.Extended
```

## 创建新站点

```bash
hugo new site my-blog
cd my-blog
```

## 目录结构

Hugo 项目的主要目录：

| 目录 | 说明 |
|------|------|
| `content/` | Markdown 文章 |
| `layouts/` | HTML 模板 |
| `static/` | 静态文件（CSS、图片） |
| `hugo.toml` | 站点配置 |

## 写新文章

```bash
hugo new posts/my-post.md
```

## 本地预览

```bash
hugo server -D
```

访问 `http://localhost:1313` 即可预览。

## 构建发布

```bash
hugo --minify
```

生成的静态文件在 `public/` 目录，上传到服务器即可。
