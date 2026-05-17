#!/bin/bash
# ECS Ubuntu 一键初始化脚本（首次部署前在服务器上运行一次）
# 用法：bash setup-ecs.sh
set -e

echo "==> 更新系统包"
apt-get update -y

echo "==> 安装 Docker"
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> 启动并设置 Docker 开机自启"
systemctl enable docker
systemctl start docker

echo "==> 创建部署目录"
mkdir -p /opt/kevin-blog

echo "==> Docker 版本"
docker --version
docker compose version

echo ""
echo "✅ 初始化完成。"
echo "   接下来在 GitHub 仓库的 Settings → Secrets → Actions 中添加："
echo "     DOCKER_USERNAME  你的 Docker Hub 用户名"
echo "     DOCKER_PASSWORD  你的 Docker Hub Access Token"
echo "     ECS_HOST         本服务器的公网 IP"
echo "     ECS_USER         SSH 用户名（如 root 或 ubuntu）"
echo "     ECS_SSH_KEY      SSH 私钥内容"
echo "   然后推送代码到 main 分支即可自动部署。"
