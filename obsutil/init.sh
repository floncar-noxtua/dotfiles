#!/bin/bash

# obsutil initialization script
# Source this file from ~/.zshrc or ~/.bashrc to set up all obsutil functions
# This is the ONLY file you need to source - it loads all utilities

OBSUTIL_CONFIG_DIR="$HOME/.obsutil"

# obsutil-default-profile: Set the default profile for obsutil operations
# Usage: obsutil-default-profile <profile-name>
# After running:
# - ./obsutil config is updated with the profile's credentials
# - Current profile name is saved to ~/.obsutil/current-profile.conf
# - All subsequent ./obsutil commands use those credentials
obsutil-default-profile() {
  local profile=$1

  if [ -z "$profile" ]; then
    echo "Usage: obsutil-default-profile <profile>"
    echo ""
    "$OBSUTIL_CONFIG_DIR/manage.sh" list
    return 1
  fi

  # Decrypt config and extract the specific profile
  local config=$(gpg --quiet --decrypt "$OBSUTIL_CONFIG_DIR/profiles.yaml.gpg" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error: Could not decrypt profiles (file not found or wrong passphrase)"
    return 1
  fi

  # Extract key, secret, and endpoint for the requested profile
  # sed explanation:
  #   -n: suppress automatic printing
  #   /^  $profile:/,/^  [a-z]/p: print range from profile name to next profile
  #   grep: filter to specific field
  #   awk: extract the value (second field)
  local key=$(echo "$config" | sed -n "/^  $profile:/,/^  [a-z]/p" | grep "key:" | awk '{print $2}')
  local secret=$(echo "$config" | sed -n "/^  $profile:/,/^  [a-z]/p" | grep "secret:" | awk '{print $2}')
  local endpoint=$(echo "$config" | sed -n "/^  $profile:/,/^  [a-z]/p" | grep "endpoint:" | awk '{print $2}')

  if [ -z "$key" ]; then
    echo "Error: Profile '$profile' not found"
    return 1
  fi

  # Find obsutil binary
  local obsutil_bin="/Users/fran/Code/obsutil_darwin_amd64_5.8.3/obsutil"
  if [ ! -f "$obsutil_bin" ]; then
    echo "Error: obsutil binary not found at $obsutil_bin"
    return 1
  fi

  # Configure obsutil with this profile's credentials, updating ~/.obsutilconfig
  "$obsutil_bin" config -i="$key" -k="$secret" -e="$endpoint" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error: Failed to update obsutil config with profile credentials"
    return 1
  fi

  # Extract bucket name from profile if available
  local bucket=$(echo "$config" | sed -n "/^  $profile:/,/^  [a-z]/p" | grep "bucket:" | awk '{print $2}')

  # Save current profile and bucket to unencrypted file
  # Format: profile_name:bucket_name
  # This allows obsutil-bucket to use current profile without decrypting
  if [ -n "$bucket" ]; then
    echo "$profile:$bucket" >"$OBSUTIL_CONFIG_DIR/current-profile.conf"
  else
    echo "$profile" >"$OBSUTIL_CONFIG_DIR/current-profile.conf"
  fi

  # Export variables for this session (for shell functions)
  export OBSUTIL_KEY="$key"
  export OBSUTIL_SECRET="$secret"
  export OBSUTIL_ENDPOINT="$endpoint"
  export OBSUTIL_CURRENT_PROFILE="$profile"

  echo "✓ Connected to profile: $profile"
  echo "  Endpoint: $endpoint"
}

# obsutil-manage: Profile management wrapper
# Usage: obsutil-manage [add|edit|delete|list] [profile-name]
obsutil-manage() {
  "$OBSUTIL_CONFIG_DIR/manage.sh" "$@"
}

# obsutil-profiles: Quick list profiles shortcut
obsutil-profiles() {
  "$OBSUTIL_CONFIG_DIR/manage.sh" list
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

# Export the config directory path in case scripts need it
export OBSUTIL_CONFIG_DIR
