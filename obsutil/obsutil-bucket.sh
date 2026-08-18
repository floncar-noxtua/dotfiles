#!/bin/bash

# obsutil-bucket: Intelligent wrapper for obsutil with bucket management
#
# Usage: obsutil-bucket [-p=profile-name] [obsutil-command] [args...]
#
# Behavior:
# - If -p is skipped: use credentials from current profile in config
# - If -p matches current profile: use credentials from ./obsutil config
# - If -p differs: use that profile's credentials (temporary, doesn't change current profile)
# - Bucket must be specified explicitly in commands (e.g., obsutil-bucket ls obs://data-ai-internal)
# - Never modifies ./obsutil config - only temporary command execution

source "$HOME/.obsutil/obsutil-lib.sh"

CURRENT_PROFILE_FILE="$OBSUTIL_CONFIG_DIR/current-profile.conf"

# Decrypt profiles and print the requested profile's key, secret, and
# endpoint, one per line (in that order). Caller reads them positionally.
read_profile() {
  local profile_name=$1

  local config
  if ! config=$(gpg --quiet --decrypt --pinentry-mode loopback --passphrase-fd 0 "$OBSUTIL_CONFIG_DIR/profiles.yaml.gpg" 2>/dev/null <<EOF
$GPG_PASSPHRASE
EOF
  ); then
    return 1
  fi

  local key secret endpoint
  key=$(extract_profile_field "$config" "$profile_name" "key")
  secret=$(extract_profile_field "$config" "$profile_name" "secret")
  endpoint=$(extract_profile_field "$config" "$profile_name" "endpoint")

  if [[ -z "$key" ]] || [[ -z "$secret" ]] || [[ -z "$endpoint" ]]; then
    return 1
  fi

  printf '%s\n' "$key" "$secret" "$endpoint"
}

# Get currently connected profile name and bucket.
# Returns: profile_name:bucket_name or just profile_name if bucket not stored
get_current_profile() {
  if [[ -f "$CURRENT_PROFILE_FILE" ]]; then
    cat "$CURRENT_PROFILE_FILE"
  fi
}

parse_profile_bucket() {
  local profile_bucket=$1
  echo "$profile_bucket" | cut -d: -f1
}

parse_bucket() {
  local profile_bucket=$1
  if [[ "$profile_bucket" == *:* ]]; then
    echo "$profile_bucket" | cut -d: -f2
  fi
}

main() {
  local profile_name=""
  local obsutil_cmd=""
  local obsutil_args=()

  # Parse -p flag if provided
  if [[ "$1" == -p=* ]]; then
    profile_name="${1#-p=}"
    shift
  fi

  # Get current profile from unencrypted file
  local current_profile_data current_profile
  current_profile_data=$(get_current_profile)
  current_profile=$(parse_profile_bucket "$current_profile_data")

  # Determine if we're using current profile or overriding
  local is_current_profile=false
  local target_key="$OBSUTIL_KEY"
  local target_secret="$OBSUTIL_SECRET"
  local target_endpoint="$OBSUTIL_ENDPOINT"

  if [[ -z "$profile_name" ]]; then
    # No profile specified - use current profile credentials from config
    is_current_profile=true
  elif [[ "$profile_name" == "$current_profile" ]]; then
    # Profile matches current - credentials already in ./obsutil config
    is_current_profile=true
  else
    # Different profile - prompt for passphrase only when switching profiles
    if [[ -z "$GPG_PASSPHRASE" ]]; then
      read -sp "Enter passphrase to unlock profiles: " GPG_PASSPHRASE
      echo
    fi

    local profile_data
    if ! profile_data=$(read_profile "$profile_name"); then
      error "Could not read profile '$profile_name'"
      return 1
    fi

    {
      IFS= read -r target_key
      IFS= read -r target_secret
      IFS= read -r target_endpoint
    } <<<"$profile_data"
  fi

  # Remaining arguments are obsutil command and args
  if [[ $# -eq 0 ]]; then
    info "Usage: obsutil-bucket [-p=profile-name] <obsutil-command> [args...]"
    info ""
    info "Examples:"
    info "  obsutil-bucket ls obs://data-ai-internal              # Use current profile"
    info "  obsutil-bucket -p=other-profile ls obs://data-ai      # Use different profile"
    info "  obsutil-bucket -p=prod cp file obs://bucket/path      # One-time use of prod profile"
    info ""
    info "Note:"
    info "  - If -p is skipped: uses current profile's credentials from ./obsutil config"
    info "  - If -p matches current profile: uses credentials from ./obsutil config"
    info "  - If -p differs: uses that profile's credentials (temporary, doesn't change current)"
    info "  - Bucket must be specified explicitly (e.g., obs://bucket-name)"
    return 1
  fi

  obsutil_cmd="$1"
  shift
  obsutil_args=("$@")

  # Build and execute the command
  # IMPORTANT: obsutil expects flags AFTER the command, not before
  if [[ "$is_current_profile" == true ]]; then
    # Same profile or no profile specified - don't pass credentials, ./obsutil config has them
    "$OBSUTIL_BIN" "$obsutil_cmd" "${obsutil_args[@]}"
  else
    # Different profile - inject full credentials AFTER the command
    "$OBSUTIL_BIN" "$obsutil_cmd" -i="$target_key" -k="$target_secret" -e="$target_endpoint" "${obsutil_args[@]}"
  fi
}

main "$@"
