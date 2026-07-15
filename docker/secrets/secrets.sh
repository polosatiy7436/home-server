#!/bin/bash
# secrets.sh — generate individual Docker secret files from sources/*.env

cd "$(dirname "$0")" || exit 1

SOURCES_DIR="sources"

if ! compgen -G "$SOURCES_DIR/*.env" > /dev/null; then
  echo "❌ No .env files found in $SOURCES_DIR/."
  exit 1
fi

for env_file in "$SOURCES_DIR"/*.env; do
  echo "🔐 Generating Docker secrets from $env_file..."

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    # split on the FIRST '=' only; never mangle '=' inside the value (base64!)
    key="${line%%=*}"
    value="${line#*=}"
    # trim surrounding whitespace
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value" > "$key"
    echo "✅ Created secret: $key"
  done < "$env_file"
done

echo "✅ All secrets written."
