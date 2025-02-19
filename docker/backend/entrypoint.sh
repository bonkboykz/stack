#!/bin/bash

set -e

# Start socat to forward port 32202 for mock-oauth-server if enabled
if [ "$STACK_FORWARD_MOCK_OAUTH_SERVER" = "true" ]; then
  socat TCP-LISTEN:32202,fork,reuseaddr TCP:host.docker.internal:32202 &
fi

export STACK_SEED_INTERNAL_PROJECT_PUBLISHABLE_CLIENT_KEY=$(openssl rand -base64 32)
export STACK_SEED_INTERNAL_PROJECT_SECRET_SERVER_KEY=$(openssl rand -base64 32)
export STACK_SEED_INTERNAL_PROJECT_SUPER_SECRET_ADMIN_KEY=$(openssl rand -base64 32)

export NEXT_PUBLIC_STACK_PROJECT_ID=internal
export NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY=${STACK_SEED_INTERNAL_PROJECT_PUBLISHABLE_CLIENT_KEY}
export STACK_SECRET_SERVER_KEY=${STACK_SEED_INTERNAL_PROJECT_SECRET_SERVER_KEY}
export STACK_SUPER_SECRET_ADMIN_KEY=${STACK_SEED_INTERNAL_PROJECT_SUPER_SECRET_ADMIN_KEY}

if [ -z "${NEXT_PUBLIC_STACK_SVIX_SERVER_URL}" ]; then
  export NEXT_PUBLIC_STACK_SVIX_SERVER_URL=${STACK_SVIX_SERVER_URL}
fi

if [ "$STACK_SKIP_MIGRATIONS" = "true" ]; then
  echo "Skipping migrations."
else
  echo "Running migrations..."
  prisma migrate deploy --schema=./apps/backend/prisma/schema.prisma
fi

if [ "$STACK_SKIP_SEED_SCRIPT" = "true" ]; then
  echo "Skipping seed script."
else
  echo "Running seed script..."
  cd apps/backend
  node seed.js
  cd ../..
fi

echo "Starting backend on port $PORT..."
HOSTNAME=0.0.0.0 node apps/backend/server.js
