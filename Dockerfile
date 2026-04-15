# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS ui-build
WORKDIR /src

ENV COREPACK_INTEGRITY_KEYS=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g corepack@latest

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY bin/package.json bin/package.json
COPY ui/.build/package.json ui/.build/package.json
COPY ui/ ui/

RUN find ui -mindepth 2 -maxdepth 2 -type f ! -name package.json -delete \
 && find ui -mindepth 1 -maxdepth 1 -type f ! -name build -delete

RUN corepack enable \
 && corepack prepare pnpm@10.4.1 --activate \
 && pnpm install --no-frozen-lockfile

COPY . .

RUN corepack enable \
 && corepack prepare pnpm@10.4.1 --activate \
 && pnpm -C ui/.build install --no-frozen-lockfile --ignore-workspace \
 && ui/build

FROM eclipse-temurin:21-jdk-jammy AS sbt-build
WORKDIR /src

ENV COREPACK_INTEGRITY_KEYS=0
ENV SBT_OPTS="-Xms512M -Xmx2G -XX:+UseG1GC -Dfile.encoding=UTF-8"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    npm \
    nodejs \
    unzip \
    xz-utils \
  && npm install -g corepack@latest \
  && rm -rf /var/lib/apt/lists/*

COPY . .
COPY --from=ui-build /src/public /src/public
COPY --from=ui-build /src/ui /src/ui

RUN chmod +x /src/lila.sh /src/ui/build \
 && /src/lila.sh -batch "clean;compile;stage"

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

RUN useradd --system --uid 10001 --home-dir /app --shell /usr/sbin/nologin lila

COPY --from=sbt-build /src/target/universal/stage/ /app/

RUN chown -R lila:lila /app
USER lila

EXPOSE 9663

ENV JAVA_OPTS="-Xms256m -Xmx1024m"
CMD ["/app/bin/lila", "-Dconfig.file=/app/conf/application.conf"]
