#!/bin/bash

# obsutil initialization script
# Source this file from ~/.zshrc or ~/.bashrc to set up all obsutil functions
# This is the ONLY file you need to source - it loads all utilities
#
# obsutil-manage and obsutil-preview are plain executables on $PATH (see
# ~/.obsutil added to PATH in zshrc) and need no wrapper here. Only
# obsutil-default-profile and obsutil-bucket/obsket are defined as functions,
# since the former exports vars into this session and can't do that as a
# subprocess.

source "$HOME/.obsutil/obsutil-lib.sh"

# obsutil-default-profile: Set the default profile for obsutil operations
# Usage: obsutil-default-profile <profile-name>
# After running:
# - ./obsutil config is updated with the profile's credentials
# - Current profile name is saved to ~/.obsutil/current-profile.conf
# - All subsequent ./obsutil commands use those credentials
obsutil-default-profile() {
  local profile=$1

  if [[ -z "$profile" ]]; then
    info "Usage: obsutil-default-profile <profile>"
    info ""
    "$OBSUTIL_CONFIG_DIR/obsutil-manage" list
    return 1
  fi

  # Decrypt config and extract the specific profile
  local config
  if ! config=$(gpg --quiet --decrypt "$OBSUTIL_CONFIG_DIR/profiles.yaml.gpg" 2>/dev/null); then
    error "Could not decrypt profiles (file not found or wrong passphrase)"
    return 1
  fi

  # Extract key, secret, and endpoint for the requested profile
  local key secret endpoint bucket
  key=$(extract_profile_field "$config" "$profile" "key")
  secret=$(extract_profile_field "$config" "$profile" "secret")
  endpoint=$(extract_profile_field "$config" "$profile" "endpoint")

  if [[ -z "$key" ]]; then
    error "Profile '$profile' not found"
    return 1
  fi

  if [[ ! -f "$OBSUTIL_BIN" ]]; then
    error "obsutil binary not found at $OBSUTIL_BIN"
    return 1
  fi

  # Configure obsutil with this profile's credentials, updating ~/.obsutilconfig
  if ! "$OBSUTIL_BIN" config -i="$key" -k="$secret" -e="$endpoint" >/dev/null 2>&1; then
    error "Failed to update obsutil config with profile credentials"
    return 1
  fi

  # Extract bucket name from profile if available
  bucket=$(extract_profile_field "$config" "$profile" "bucket")

  # Save current profile and bucket to unencrypted file
  # Format: profile_name:bucket_name
  # This allows obsutil-bucket to use current profile without decrypting
  if [[ -n "$bucket" ]]; then
    echo "$profile:$bucket" >"$OBSUTIL_CONFIG_DIR/current-profile.conf"
  else
    echo "$profile" >"$OBSUTIL_CONFIG_DIR/current-profile.conf"
  fi

  # Export variables for this session (for shell functions)
  export OBSUTIL_KEY="$key"
  export OBSUTIL_SECRET="$secret"
  export OBSUTIL_ENDPOINT="$endpoint"
  export OBSUTIL_CURRENT_PROFILE="$profile"

  success "Connected to profile: $profile"
  info "  Endpoint: $endpoint"
}

# obsutil-bucket: Smart bucket wrapper
# Usage: obsutil-bucket [-p=profile-name] <command> [args...]
#
# Behavior:
# - If -p is omitted: uses current profile's credentials from ./obsutil config
# - If -p matches current: uses credentials from ./obsutil config (already set up)
# - If -p differs: prompts for passphrase, loads that profile's credentials (one-time)
# - Never modifies ./obsutil config or current-profile.conf
# - Bucket must be specified explicitly (e.g., obs://bucket-name)
obsutil-bucket() {
  # Export variables needed by wrapper script
  export OBSUTIL_KEY="$OBSUTIL_KEY"
  export OBSUTIL_SECRET="$OBSUTIL_SECRET"
  export OBSUTIL_ENDPOINT="$OBSUTIL_ENDPOINT"

  "$OBSUTIL_CONFIG_DIR/obsutil-bucket.sh" "$@"
}

# obsket: short name for obsutil-bucket, defined as a real function (not a
# shell alias) so it behaves consistently wherever functions are expected
obsket() {
  obsutil-bucket "$@"
}

# Export the config directory path in case scripts need it
export OBSUTIL_CONFIG_DIR
