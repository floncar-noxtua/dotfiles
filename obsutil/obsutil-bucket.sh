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

OBSUTIL_CONFIG_DIR="$HOME/.obsutil"
OBSUTIL_BIN="/Users/fran/Code/obsutil_darwin_amd64_5.8.3/obsutil"
CURRENT_PROFILE_FILE="$OBSUTIL_CONFIG_DIR/current-profile.conf"

# Helper: read profile and extract credentials
read_profile() {
  local profile_name=$1

  # Decrypt profiles
  local config=$(gpg --quiet --decrypt --pinentry-mode loopback --passphrase-fd 0 "$OBSUTIL_CONFIG_DIR/profiles.yaml.gpg" 2>/dev/null << EOF
$GPG_PASSPHRASE
EOF
)

  if [ $? -ne 0 ]; then
    return 1
  fi

  # Extract values using sed/grep/awk
  # sed -n "/^  $profile_name:/,/^  [a-z]/p" : range from profile to next profile
  # grep "field:" : filter to specific field
  # awk '{print $2}' : extract value (second whitespace-separated field)
  local key=$(echo "$config" | sed -n "/^  $profile_name:/,/^  [a-z]/p" | grep "key:" | awk '{print $2}')
  local secret=$(echo "$config" | sed -n "/^  $profile_name:/,/^  [a-z]/p" | grep "secret:" | awk '{print $2}')
  local endpoint=$(echo "$config" | sed -n "/^  $profile_name:/,/^  [a-z]/p" | grep "endpoint:" | awk '{print $2}')
  local bucket=$(echo "$config" | sed -n "/^  $profile_name:/,/^  [a-z]/p" | grep "bucket:" | awk '{print $2}')

  if [ -z "$key" ] || [ -z "$secret" ] || [ -z "$endpoint" ]; then
    return 1
  fi

  # Output as environment-compatible format
  echo "KEY=$key"
  echo "SECRET=$secret"
  echo "ENDPOINT=$endpoint"
  echo "BUCKET=$bucket"
}

# Helper: get currently connected profile name and bucket
# Returns: profile_name:bucket_name or just profile_name if bucket not stored
get_current_profile() {
  if [ -f "$CURRENT_PROFILE_FILE" ]; then
    cat "$CURRENT_PROFILE_FILE"
  fi
}

# Helper: parse profile:bucket format
parse_profile_bucket() {
  local profile_bucket=$1
  # Extract profile name (before colon)
  echo "$profile_bucket" | cut -d: -f1
}

parse_bucket() {
  local profile_bucket=$1
  # Extract bucket name (after colon, if present)
  if [[ "$profile_bucket" == *:* ]]; then
    echo "$profile_bucket" | cut -d: -f2
  fi
}

# Main script
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
  local current_profile_data=$(get_current_profile)
  local current_profile=$(parse_profile_bucket "$current_profile_data")

  # Determine if we're using current profile or overriding
  local is_current_profile=false
  local target_key="$OBSUTIL_KEY"
  local target_secret="$OBSUTIL_SECRET"
  local target_endpoint="$OBSUTIL_ENDPOINT"

  if [ -z "$profile_name" ]; then
    # No profile specified - use current profile credentials from config
    is_current_profile=true
  elif [ "$profile_name" = "$current_profile" ]; then
    # Profile matches current - credentials already in ./obsutil config
    is_current_profile=true
  else
    # Different profile - need to decrypt to get credentials
    # Prompt for passphrase only when switching profiles
    if [ -z "$GPG_PASSPHRASE" ]; then
      read -sp "Enter passphrase to unlock profiles: " GPG_PASSPHRASE
      echo
    fi

    # Read the profile to get credentials
    local profile_data=$(read_profile "$profile_name")
    if [ $? -ne 0 ]; then
      echo "Error: Could not read profile '$profile_name'"
      return 1
    fi

    # Parse profile data
    eval "$profile_data"
    target_key="$KEY"
    target_secret="$SECRET"
    target_endpoint="$ENDPOINT"
  fi

  # Remaining arguments are obsutil command and args
  if [ $# -eq 0 ]; then
    echo "Usage: obsutil-bucket [-p=profile-name] <obsutil-command> [args...]"
    echo ""
    echo "Examples:"
    echo "  obsutil-bucket ls obs://data-ai-internal              # Use current profile"
    echo "  obsutil-bucket -p=other-profile ls obs://data-ai      # Use different profile"
    echo "  obsutil-bucket -p=prod cp file obs://bucket/path      # One-time use of prod profile"
    echo ""
    echo "Note:"
    echo "  - If -p is skipped: uses current profile's credentials from ./obsutil config"
    echo "  - If -p matches current profile: uses credentials from ./obsutil config"
    echo "  - If -p differs: uses that profile's credentials (temporary, doesn't change current)"
    echo "  - Bucket must be specified explicitly (e.g., obs://bucket-name)"
    return 1
  fi

  # Use provided arguments as-is
  obsutil_cmd="$1"
  shift
  obsutil_args=("$@")

  # Build and execute the command
  # IMPORTANT: obsutil expects flags AFTER the command, not before
  if [ "$is_current_profile" = true ]; then
    # Same profile or no profile specified - don't pass credentials, ./obsutil config has them
    "$OBSUTIL_BIN" "$obsutil_cmd" "${obsutil_args[@]}"
  else
    # Different profile - inject full credentials AFTER the command
    # Flags must come after the command: ./obsutil command -i=... -k=... -e=...
    "$OBSUTIL_BIN" "$obsutil_cmd" -i="$target_key" -k="$target_secret" -e="$target_endpoint" "${obsutil_args[@]}"
  fi
}

main "$@"
