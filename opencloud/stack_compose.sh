#!/bin/bash

###########################################################################
# Generates a unified docker compose file for OpenCloud
# that can be used directly with Portainer
#
# In order, it merges the base OpenCloud compose files from the github repo,
REPO_FOLDER=./_opencloud-compose
#
# The following base compose files are merged (order-sensitive)!
BASE_FILES=("${REPO_FOLDER}/docker-compose.yml")
# BASE_FILES+=("_opencloud-compose/weboffice/euro-office.yml")
# BASE_FILES+=("_opencloud-compose/external-proxy/euro-office-exposed.yml")
BASE_FILES+=("${REPO_FOLDER}/search/tika.yml")
BASE_FILES+=("${REPO_FOLDER}/antivirus/clamav.yml")
#
# After that, it merges your custom YAML overrides,
CUSTOM_FILE="stack_custom.yml"
# and all ${VAR} placeholders from your stack configuration,
ENV_FILE="stack.env"
#
# The resulting compose stack is saved here:
TIMESTAMP=$(date +"%y%m%dT%H%M")
OUTPUT="opencloud-compose_${TIMESTAMP}.yml"
DEBUG="${OUTPUT}_DEBUG.yml"
###########################################################################

# Build the repeated "-f <file>" arguments for docker compose.
COMPOSE_ARGS=()
for f in "${BASE_FILES[@]}"; do
  COMPOSE_ARGS+=("-f" "$f")
done

# Sanity check to confirm that all inputs exist
missing=()
for f in "$CUSTOM_FILE" "$ENV_FILE" "${BASE_FILES[@]}"; do
  [[ -f "$f" ]] || missing+=("$f")
done
if (( ${#missing[@]} > 0 )); then
  echo "Error: required file(s) not found:" >&2
  for f in "${missing[@]}"; do
    printf '  %s\n' "$f" >&2
  done
  exit 1
fi

echo "Resolving compose files..."

# Debug build
#if ! docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" config > "$DEBUG"; then
#  echo "Error: failed to generate $DEBUG (see stderr above)." >&2
#  exit 1
#fi

# Final build
if ! docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" -f "$CUSTOM_FILE" config > "$OUTPUT"; then
  echo "Error: failed to generate $OUTPUT (see stderr above)." >&2
  exit 1
fi

# Fix readability
sed -i '/^  clamav:/i\\'     "$OUTPUT"
sed -i '/^  euro-office:/i\\' "$OUTPUT"
sed -i '/^  opencloud:/i\\'   "$OUTPUT"
sed -i '/^  tika:/i\\'       "$OUTPUT"
sed -i '/^networks:/i\\'     "$OUTPUT"
sed -i '/^volumes:/i\\'      "$OUTPUT"

echo "Saved unified stack at: $OUTPUT"
