# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS ui-build
WORKDIR /src

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV COREPACK_INTEGRITY_KEYS=0

COPY .git ./.git
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY bin/package.json ./bin/package.json
COPY ui ./ui
COPY public ./public

RUN corepack enable \
  && corepack prepare pnpm@10.4.1 --activate \
  && pnpm install --frozen-lockfile \
  && pnpm --dir ui/.build install --frozen-lockfile --ignore-workspace \
  && pnpm --dir ui/.build exec node --experimental-strip-types --no-warnings src/main.ts --prod --no-install

FROM sbtscala/scala-sbt:eclipse-temurin-21.0.6_7_1.10.11_3.6.4 AS build
WORKDIR /src

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY build.sbt ./
COPY project ./project
COPY app ./app
COPY conf ./conf
COPY public ./public
COPY translation ./translation
COPY bin ./bin
COPY LICENSE COPYING.md README.md ./
COPY --from=ui-build /src/public ./public

RUN sbt stage

FROM eclipse-temurin:21-jre
WORKDIR /opt/lila

RUN useradd --system --create-home --home-dir /opt/lila --shell /usr/sbin/nologin lila \
  && mkdir -p /opt/lila \
  && chown -R lila:lila /opt/lila

COPY --from=build /src/target/universal/stage /opt/lila

USER lila

EXPOSE 9663
CMD ["bin/lila", "-Dconfig.file=conf/application.conf.default"]
