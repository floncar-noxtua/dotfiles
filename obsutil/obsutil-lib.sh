#!/bin/bash

# Shared constants, credential-parsing, and output helpers for the obsutil
# scripts. Sourced by obsutil-init.sh, obsutil-manage, obsutil-preview, and
# obsutil-bucket.sh.
#
# Naming convention:
# - Public "pseudo-commands" meant to be typed interactively are kebab-case:
#   obsutil-default-profile and obsutil-bucket/obsket (functions, defined in
#   obsutil-init.sh), obsutil-manage and obsutil-preview (plain executables
#   on $PATH).
# - Internal helper functions (everything else, including in this file) are
#   snake_case.

OBSUTIL_CONFIG_DIR="$HOME/.obsutil"
OBSUTIL_BIN="/Users/fran/Code/obsutil_darwin_amd64_5.8.3/obsutil"

info() {
  echo "$*"
}

success() {
  echo "✓ $*"
}

error() {
  echo "Error: $*" >&2
}

# Extract one field's value for a profile out of decrypted profiles.yaml
# content. Relies on the 2-space-per-level YAML indentation the profiles
# file is always written with.
extract_profile_field() {
  local content="$1" profile="$2" field="$3"
  echo "$content" | sed -n "/^  $profile:/,/^  [a-z]/p" | grep "$field:" | awk '{print $2}'
}
