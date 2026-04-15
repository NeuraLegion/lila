FROM node:22.13.1-bookworm-slim

WORKDIR /app

ENV CI=true \
    NODE_ENV=production \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH

RUN corepack enable

COPY package.json pnpm-lock.yaml ./
COPY ui ./ui
COPY bin ./bin
COPY conf ./conf
COPY public ./public
COPY lila.sh ./

RUN pnpm install --frozen-lockfile

# Build steps for the frontend assets / TypeScript sources if available in this repo.
# The project is a Scala/Play app with a Node-based UI toolchain; runtime launch is via sbt.
RUN true

EXPOSE 9663

CMD ["sh", "-lc", "./lila.sh run"]
