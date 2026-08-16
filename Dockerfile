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

# /app is created here (not implicitly by WORKDIR) so it is www-owned before
# anything writes into it.
RUN addgroup --system www \
 && adduser --system --ingroup www --home /www --shell /usr/sbin/nologin www \
 && mkdir -p /www /app \
 && chown -R www:www /www /app /var/lib/nginx /var/log/nginx

RUN npm --no-update-notifier --no-fund --global install pnpm@10.6.1 pm2

WORKDIR /app

# Source arrives already owned by www, and the install/build run AS www, so
# every file pnpm and nx create is www-owned at creation time.
#
# This replaces a `RUN chown -R www:www /app` that used to sit after the build.
# On overlayfs, chown of a file in a lower layer forces a full copy-up of that
# file, so that one line copied the entire node_modules + dist + .next tree
# (several GB, ~180k files) into a fresh layer: >30 min on deb and roughly
# double the image size, for a pure metadata change. Same ownership result,
# no copy. Runtime still needs write access under /app for pm2 state, pnpm dlx
# (prisma db push) and app caches -- that still holds, it is just granted at
# creation instead of retrofitted.
#
# Unprivileged runtime is unchanged: nginx listens on 5000 (no
# CAP_NET_BIND_SERVICE needed) and pm2/node never bind below 1024.
COPY --chown=www:www . /app
COPY var/docker/nginx.conf /etc/nginx/nginx.conf

USER www

RUN pnpm install
RUN NODE_OPTIONS="--max-old-space-size=4096" pnpm run build

CMD ["sh", "-c", "nginx && pnpm run pm2"]
