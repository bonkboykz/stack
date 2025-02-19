ARG NODE_VERSION=22.9.0

# Base
FROM node:${NODE_VERSION} AS base

WORKDIR /app

RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH

RUN corepack enable
RUN corepack prepare pnpm@10.0.0 --activate
RUN pnpm add -g turbo
RUN pnpm add -g tsx

# Prune stage
FROM base AS pruner

COPY . .

RUN tsx ./scripts/generate-from-template.ts

RUN turbo prune --scope=@stackframe/stack-backend --docker

# Build stage
FROM base AS builder

COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/pnpm-lock.yaml .
COPY .gitignore .
COPY pnpm-workspace.yaml .
COPY turbo.json .
# Fails on Railway
# RUN --mount=type=cache,id=pnpm,target=/pnpm/store STACK_SKIP_TEMPLATE_GENERATION=true pnpm install --frozen-lockfile
RUN STACK_SKIP_TEMPLATE_GENERATION=true pnpm install --frozen-lockfile

COPY --from=pruner /app/out/full/ .
COPY docs ./docs

ENV NEXT_CONFIG_OUTPUT=standalone

RUN pnpm turbo run docker-build --filter=@stackframe/stack-backend...

# Build the self-host seed script
RUN cd apps/backend && pnpm build-self-host-seed-script

# Final image
FROM node:${NODE_VERSION}-slim

WORKDIR /app

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y openssl socat && \
    rm -rf /var/lib/apt/lists

RUN npm i -g prisma

COPY --from=builder --chown=node:node /app/apps/backend/.next/standalone ./
COPY --from=builder --chown=node:node /app/apps/backend/.next/static ./apps/backend/.next/static
COPY --from=builder --chown=node:node /app/apps/backend/prisma ./apps/backend/prisma
COPY --from=builder --chown=node:node /app/apps/backend/dist/seed.js ./apps/backend

COPY ./docker/backend/entrypoint.sh .
RUN chmod +x entrypoint.sh

ENV NODE_ENV=production
ENV PORT=8102

USER node

ENTRYPOINT ["./entrypoint.sh"]
