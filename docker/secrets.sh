#!/bin/bash
# secrets.sh — generate individual Docker secret files from .env.secrets

ENV_FILE=".env.secrets"

if [[ ! -f $ENV_FILE ]]; then
  echo "❌ File $ENV_FILE not found."
  exit 1
fi

echo "🔐 Generating Docker secrets from $ENV_FILE..."

while IFS='=' read -r key value; do
  key_trimmed=$(echo "$key" | xargs)
  value_trimmed=$(echo "$value" | xargs)

  # Skip comments and empty lines
  if [[ -z "$key_trimmed" || "$key_trimmed" =~ ^# ]]; then
    continue
  fi

  echo -n "$value_trimmed" > "$key_trimmed"
  echo "✅ Created secret: $key_trimmed"
done < "$ENV_FILE"

echo "✅ All secrets written."
