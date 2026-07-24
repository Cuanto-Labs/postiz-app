FROM node:22.20-bookworm-slim

ARG NEXT_PUBLIC_VERSION
ENV NEXT_PUBLIC_VERSION=$NEXT_PUBLIC_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    make \
    python3-pip \
    bash \
    nginx \
 && rm -rf /var/lib/apt/lists/*

RUN addgroup --system www \
 && adduser --system --ingroup www --home /www --shell /usr/sbin/nologin www \
 && mkdir -p /www \
 && chown -R www:www /www /var/lib/nginx /var/log/nginx

RUN npm --no-update-notifier --no-fund --global install pnpm@10.6.1 pm2

WORKDIR /app

COPY . /app
COPY var/docker/nginx.conf /etc/nginx/nginx.conf

RUN pnpm install
RUN NODE_OPTIONS="--max-old-space-size=4096" pnpm run build

# pnpm install/build ran as root, so /app is root-owned. Runtime needs write
# access for pm2's process files, pnpm dlx (prisma db push), and any app cache
# dirs under /app -- hand the whole tree to www before dropping privileges.
# Safe to run everything unprivileged: nginx listens on 5000 (unprivileged
# port, no CAP_NET_BIND_SERVICE needed) and pm2/node never bind <1024 either.
RUN chown -R www:www /app

USER www

CMD ["sh", "-c", "nginx && pnpm run pm2"]
