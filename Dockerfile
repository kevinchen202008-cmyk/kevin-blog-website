# ── Stage 1: Build Hugo site ──────────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

ARG HUGO_VERSION=0.161.1
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin hugo && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /site
COPY . .
RUN hugo --minify

# ── Stage 2: Serve with Nginx ─────────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /site/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
