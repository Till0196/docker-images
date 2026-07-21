#!/usr/bin/env bash

set -euo pipefail

readonly LOCALE="${1:-ja}"
readonly LANG_PACK_PREFIX="ms-ceintl.vscode-language-pack-"

log() { echo "[setup-code-server-locale] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

find_extensions_dir() {
  local candidates=()

  if [ -n "${CODE_SERVER_DATA_DIR:-}" ]; then
    candidates+=("${CODE_SERVER_DATA_DIR}/extensions")
  fi

  candidates+=(
    "${HOME}/.local/share/code-server/extensions"
    "${HOME}/.cache/code-server/extensions"
  )

  local dir
  for dir in "${candidates[@]}"; do
    if [ -d "$dir" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done

  return 1
}

EXTENSIONS_DIR="$(find_extensions_dir || true)"
[ -n "$EXTENSIONS_DIR" ] || die \
  "Extensions directory not found. Checked: ${CODE_SERVER_DATA_DIR:-<unset>}/extensions, ${HOME}/.local/share/code-server/extensions, ${HOME}/.cache/code-server/extensions"

readonly EXTENSIONS_DIR
readonly CODE_SERVER_DATA_DIR="$(dirname "$EXTENSIONS_DIR")"
readonly EXTENSIONS_JSON="${EXTENSIONS_DIR}/extensions.json"
readonly USER_DIR="${CODE_SERVER_DATA_DIR}/User"
readonly LANGUAGE_PACKS_JSON="${CODE_SERVER_DATA_DIR}/languagepacks.json"
readonly ARGV_JSON="${USER_DIR}/argv.json"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Command '$1' not found."
}

require_cmd jq
require_cmd md5sum
require_cmd find

[ -f "$EXTENSIONS_JSON" ] || die "extensions.json not found: ${EXTENSIONS_JSON}"

find_language_pack_dir() {
  find "$EXTENSIONS_DIR" -maxdepth 1 -type d \
    -name "${LANG_PACK_PREFIX}${LOCALE}-*" 2>/dev/null | head -n1
}

LANG_PACK_DIR="$(find_language_pack_dir)"
[ -n "$LANG_PACK_DIR" ] || die \
  "Language pack extension '${LANG_PACK_PREFIX}${LOCALE}' not found. " \
  "Run 'code-server --install-extension ${LANG_PACK_PREFIX}${LOCALE}' first."
[ -f "${LANG_PACK_DIR}/package.json" ] || die "package.json not found: ${LANG_PACK_DIR}/package.json"

log "Language pack detected: ${LANG_PACK_DIR}"

compute_hash() {
  jq -r --arg path "$LANG_PACK_DIR" \
    '.[] | select(.location.path == $path) | .identifier.uuid + .version' \
    "$EXTENSIONS_JSON" | md5sum | cut -c1-32
}

HASH="$(compute_hash)"
[ -n "$HASH" ] || die "No matching extension entry found in extensions.json: ${LANG_PACK_DIR}"

generate_config() {
  jq -c \
    --arg path "$LANG_PACK_DIR" \
    --arg hash "$HASH" \
    --slurpfile pkg "${LANG_PACK_DIR}/package.json" '
    ($pkg[0].contributes.localizations[0]) as $loc |
    (.[] | select(.location.path == $path)) as $entry |
    {
      languagePacks: {
        ($loc.languageId): {
          hash: $hash,
          label: $loc.localizedLanguageName,
          extensions: [{
            extensionIdentifier: { id: $entry.identifier.id, uuid: $entry.identifier.uuid },
            version: $entry.version
          }],
          translations: ($loc.translations | map({ (.id): "\($path)/\(.path)" }) | add)
        }
      },
      argv: { locale: $loc.languageId }
    }' "$EXTENSIONS_JSON"
}

CONFIG_JSON="$(generate_config)"
[ -n "$CONFIG_JSON" ] && [ "$CONFIG_JSON" != "null" ] || \
  die "Failed to generate configuration JSON (check package.json contributes.localizations)."

mkdir -p "$USER_DIR"

echo "$CONFIG_JSON" | jq '.languagePacks' > "$LANGUAGE_PACKS_JSON"
echo "$CONFIG_JSON" | jq '.argv'          > "$ARGV_JSON"

log "Write complete: ${LANGUAGE_PACKS_JSON}"
log "Write complete: ${ARGV_JSON}"
log "Locale '${LOCALE}' configuration completed."