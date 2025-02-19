#!/bin/bash

set -e

export NEXT_PUBLIC_STACK_PROJECT_ID=internal
export NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY=${STACK_SEED_INTERNAL_PROJECT_PUBLISHABLE_CLIENT_KEY}


export NEXT_PUBLIC_CLIENT_STACK_DASHBOARD_URL=${NEXT_PUBLIC_STACK_DASHBOARD_URL}
export NEXT_PUBLIC_SERVER_STACK_DASHBOARD_URL="http://localhost:8101"
export NEXT_PUBLIC_CLIENT_STACK_API_URL=${NEXT_PUBLIC_STACK_API_URL}
export NEXT_PUBLIC_SERVER_STACK_API_URL="http://localhost:8102"

export USE_INLINE_ENV_VARS=true

if [ -z "${NEXT_PUBLIC_STACK_SVIX_SERVER_URL}" ]; then
  export NEXT_PUBLIC_STACK_SVIX_SERVER_URL=${STACK_SVIX_SERVER_URL}
fi

# Find all files in /app/apps that contain a STACK_ENV_VAR_SENTINEL and extract the unique sentinel strings.
unhandled_sentinels=$(find /app/apps -type f -exec grep -l "STACK_ENV_VAR_SENTINEL" {} + | \
  xargs grep -h "STACK_ENV_VAR_SENTINEL" | \
  grep -o "STACK_ENV_VAR_SENTINEL[A-Z_]*" | \
  sort -u | grep -v "^STACK_ENV_VAR_SENTINEL$")

# Choose an uncommon delimiter – here, we use the ASCII Unit Separator (0x1F)
delimiter=$(printf '\037')

for sentinel in $unhandled_sentinels; do
  # The sentinel is like "STACK_ENV_VAR_SENTINEL_MY_VAR", so extract the env var name.
  env_var=${sentinel#STACK_ENV_VAR_SENTINEL_}
  
  # Get the corresponding environment variable value.
  value="${!env_var}"
  
  # If the env var is not set, skip replacement.
  if [ -z "$value" ]; then
    continue
  fi

  # Although the sentinel only contains [A-Z_] we still escape it for any regex meta-characters.
  escaped_sentinel=$(printf '%s\n' "$sentinel" | sed -e 's/\\/\\\\/g' -e 's/[][\/.^$*]/\\&/g')

  # For the replacement value, first escape backslashes, then escape any occurrence of
  # the chosen delimiter and the '&' (which has special meaning in sed replacements).
  escaped_value=$(printf '%s\n' "$value" | sed -e 's/\\/\\\\/g' -e "s/[${delimiter}&]/\\\\&/g")

  # Now replace the sentinel with the (properly escaped) value in all files.
  find /app/apps -type f -exec sed -i "s${delimiter}${escaped_sentinel}${delimiter}${escaped_value}${delimiter}g" {} +
done


echo "Starting dashboard on port $PORT..."
PORT=$PORT HOSTNAME=0.0.0.0 node apps/dashboard/server.js &
