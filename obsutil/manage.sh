#!/bin/bash

# obsutil profile management utility
# Handles add, list, edit, delete profiles with transparent encryption

PROFILES_FILE="$HOME/.obsutil/profiles.yaml.gpg"
PROFILES_PLAIN="$HOME/.obsutil/profiles.yaml.tmp"
CONFIG_DIR="$HOME/.obsutil"
GPG_PASSPHRASE="" # Session-scoped passphrase cache (in memory, not in shell history)

# Ensure config directory exists
# -p: create parent directories if needed, don't error if directory exists
mkdir -p "$CONFIG_DIR"

# Get or prompt for GPG passphrase (once per shell session)
# Passphrase is cached in $GPG_PASSPHRASE variable for the duration of the session
_ensure_passphrase() {
  if [ -n "$GPG_PASSPHRASE" ]; then
    # Passphrase already cached in this session, return success
    return 0
  fi

  # Passphrase not yet cached, prompt user
  if [ ! -f "$PROFILES_FILE" ]; then
    # First time - setting up new encryption
    echo "Setting up GPG encryption for profiles..."
    read -sp "Enter a passphrase to protect your profiles: " pass1
    echo
    read -sp "Confirm passphrase: " pass2
    echo

    # Verify passphrases match
    if [ "$pass1" != "$pass2" ]; then
      echo "Error: Passphrases do not match"
      return 1
    fi

    if [ -z "$pass1" ]; then
      echo "Error: Passphrase cannot be empty"
      return 1
    fi

    GPG_PASSPHRASE="$pass1"
  else
    # Profiles exist - unlock with existing passphrase
    read -sp "Enter passphrase to unlock profiles: " GPG_PASSPHRASE
    echo
  fi

  if [ -z "$GPG_PASSPHRASE" ]; then
    echo "Error: Passphrase required"
    return 1
  fi

  return 0
}

# Helper: decrypt profiles
# Reads encrypted GPG file and outputs plaintext
# Uses cached session passphrase (prompted once per session)
decrypt_profiles() {
  if [ ! -f "$PROFILES_FILE" ]; then
    return 1
  fi

  # Ensure we have a passphrase (prompts if not cached)
  _ensure_passphrase || return 1

  # Decrypt using cached passphrase
  # --quiet: suppress GPG metadata and warnings
  # --decrypt: decrypt the file and output to stdout
  # --pinentry-mode loopback: use stdin for passphrase instead of interactive prompt
  # --passphrase-fd 0: read passphrase from file descriptor 0 (stdin)
  # 2>/dev/null: suppress error messages (sent to stderr) if decryption fails
  echo "$GPG_PASSPHRASE" | gpg --quiet --decrypt --pinentry-mode loopback --passphrase-fd 0 "$PROFILES_FILE" 2>/dev/null
}

# Helper: encrypt and save profiles
# Takes plaintext YAML content as argument and encrypts it with GPG
# Uses cached session passphrase (prompted once per session)
encrypt_profiles() {
  local content="$1"
  local temp_file="/tmp/obsutil_profiles_$$.tmp"

  # Ensure we have a passphrase (prompts if not cached)
  _ensure_passphrase || return 1

  # Write content to temporary file
  echo "$content" >"$temp_file"

  # Encrypt using cached passphrase
  # --quiet: suppress GPG metadata/info messages
  # --symmetric: use symmetric encryption (password-based) instead of public key
  # --cipher-algo AES256: use AES256 encryption algorithm (military-grade)
  # --pinentry-mode loopback: use stdin for passphrase instead of interactive prompt
  # --passphrase-fd 0: read passphrase from file descriptor 0 (stdin)
  # --output "$PROFILES_FILE": write encrypted output to file (not stdout)
  # $temp_file: input file to encrypt (instead of stdin)
  # 2>/dev/null: suppress any GPG error/warning messages to stderr
  echo "$GPG_PASSPHRASE" | gpg --quiet --symmetric --cipher-algo AES256 --pinentry-mode loopback --passphrase-fd 0 --output "$PROFILES_FILE" "$temp_file" 2>/dev/null
  local result=$?

  # Clean up temporary file (overwrite first for security)
  # dd: disk duplicator - used here to overwrite file with zeros for security
  # if=: input file (random data)
  # of=: output file (target temp file)
  # bs=: block size (1 byte at a time)
  # count=: number of blocks (size of file)
  dd if=/dev/zero of="$temp_file" bs=1 count=$(stat -f%z "$temp_file") 2>/dev/null
  rm -f "$temp_file"

  if [ $result -eq 0 ]; then
    # $? captures exit code of previous command (0 = success)
    return 0
  else
    echo "Error: Failed to encrypt profiles"
    return 1
  fi
}

# List all profiles with nice formatting
list_profiles() {
  local content=$(decrypt_profiles)
  if [ $? -ne 0 ]; then
    # $? -ne 0: if decryption failed (file doesn't exist or user cancelled passphrase)
    echo "No profiles found. Use 'obsutil-manage add <name>' to create one."
    return 0
  fi

  echo "Available profiles:"
  # Pipeline explanation:
  # | grep "^  [a-z]" : match lines starting with 2 spaces followed by lowercase letter (profile names)
  #   ^ = start of line, [a-z] = lowercase letters only
  # | sed 's/:$//' : remove trailing colons (:) from end of line ($ = end of line)
  # | sed 's/^  /  ✓ /' : replace leading 2 spaces with checkmark (✓) for visual indicator
  echo "$content" | grep "^  [a-z]" | sed 's/:$//' | sed 's/^  /  ✓ /'
}

# Add new profile (interactive)
add_profile() {
  local name=$1

  if [ -z "$name" ]; then
    # -z checks if string is empty/zero length
    # -p: prompt prefix (text shown before input)
    # read command stores input in variable after -p
    read -p "Profile name: " name
  fi

  if [ -z "$name" ]; then
    echo "Error: Profile name cannot be empty"
    return 1
  fi

  # Validate name (alphanumeric, dash, underscore only)
  # [[ ]] is bash extended test construct (allows regex matching with =~)
  # =~ operator performs regex match (returns 0 if matches)
  # ! negates the result (0 becomes 1, 1 becomes 0)
  # ^[a-zA-Z0-9_-]+$ regex breakdown:
  #   ^ = start of string
  #   [a-zA-Z0-9_-]+ = one or more chars from this set (letters, digits, underscore, dash)
  #   $ = end of string
  if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Profile name can only contain letters, numbers, dash, and underscore"
    return 1
  fi

  # -p: prompt prefix shown before input cursor
  read -p "Access Key ID: " key

  # -s (silent): don't echo typed characters to terminal (hides password)
  # -p: prompt prefix shown before input cursor
  read -sp "Secret Key (hidden): " secret

  # newline after silent input (user doesn't see their return key press)
  echo

  read -p "Endpoint: " endpoint

  # -p: prompt prefix shown before input cursor
  # Optional: bucket name for this profile (can be empty if not using obsutil-bucket wrapper)
  read -p "Bucket name (optional): " bucket

  # || is OR operator: execute if previous command fails (returns non-zero)
  # -z tests if string is empty
  if [ -z "$key" ] || [ -z "$secret" ] || [ -z "$endpoint" ]; then
    echo "Error: All fields are required"
    return 1
  fi

  # Get existing config or create new
  local content=$(decrypt_profiles)
  if [ $? -ne 0 ]; then
    # If decryption fails (file doesn't exist), start with empty YAML structure
    content="profiles:"
  fi

  # Check if profile already exists
  # | grep -q "^  $name:" explanation:
  #   | pipe: pass content to grep
  #   -q (quiet): suppress output, just return exit code (0=match found, 1=no match)
  #   ^ = line must start with these characters
  #   ^  $ = 2 spaces followed by the profile name variable ($name) followed by colon
  if echo "$content" | grep -q "^  $name:"; then
    echo "Error: Profile '$name' already exists. Use 'obsutil-manage edit $name' to modify."
    return 1
  fi

  # Add new profile to existing content
  # String concatenation in bash: "string1\nstring2"
  # The \n creates a literal newline in the string
  # YAML indentation must be exactly 2 spaces per level
  content="$content
  $name:
    key: $key
    secret: $secret
    endpoint: $endpoint"

  # Only add bucket field if provided (optional)
  if [ -n "$bucket" ]; then
    content="$content
    bucket: $bucket"
  fi

  encrypt_profiles "$content"
  if [ $? -eq 0 ]; then
    echo "✓ Profile '$name' added successfully"
  fi
}

# TODO: when secret key shouldn't be previewed
# Edit existing profile (interactive)
edit_profile() {
  local name=$1

  if [ -z "$name" ]; then
    read -p "Profile name to edit: " name
  fi

  local content=$(decrypt_profiles)
  if [ $? -ne 0 ]; then
    echo "Error: No profiles found"
    return 1
  fi

  if ! echo "$content" | grep -q "^  $name:"; then
    echo "Error: Profile '$name' not found"
    return 1
  fi

  # Extract current values from YAML
  # Pipeline: content | sed ... | grep ... | awk ...
  # sed explanation:
  #   -n: suppress automatic printing (only print what we explicitly ask for with 'p')
  #   /^  $name:/,/^  [a-z]/p : range from profile name to next profile
  #     /^  $name:/ = start of this profile (2 spaces + name + colon)
  #     ,/^  [a-z]/ = up to next profile line (starts with 2 spaces + lowercase letter)
  #     p = print matching lines
  # grep "key:" = filter to only lines containing "key:"
  # awk '{print $2}' = print second field (whitespace-separated), which is the value
  local current_key=$(echo "$content" | sed -n "/^  $name:/,/^  [a-z]/p" | grep "key:" | awk '{print $2}')
  local current_secret=$(echo "$content" | sed -n "/^  $name:/,/^  [a-z]/p" | grep "secret:" | awk '{print $2}')
  local current_endpoint=$(echo "$content" | sed -n "/^  $name:/,/^  [a-z]/p" | grep "endpoint:" | awk '{print $2}')
  local current_bucket=$(echo "$content" | sed -n "/^  $name:/,/^  [a-z]/p" | grep "bucket:" | awk '{print $2}')

  # Prompt with current value shown in square brackets
  read -p "Access Key ID [$current_key]: " key
  # ${variable:-default} = parameter expansion with default value
  # If $key is empty (user just pressed enter), use $current_key instead
  key=${key:-$current_key}

  # -s: silent mode (don't echo characters while typing)
  read -sp "Secret Key [$current_secret] (hidden): " secret
  echo
  secret=${secret:-$current_secret}

  read -p "Endpoint [$current_endpoint]: " endpoint
  # If user didn't enter anything, keep current value
  endpoint=${endpoint:-$current_endpoint}

  read -p "Bucket name [$current_bucket]: " bucket
  bucket=${bucket:-$current_bucket}

  # Remove old profile and add updated one
  # First sed command:
  #   /^  $name:/,/^  [a-z]/d = delete range from this profile to next profile
  #   d = delete matching lines
  # Second sed command:
  #   '$ s/$//' = on last line ($), substitute end-of-line (/) with nothing (//), removes trailing whitespace
  content=$(echo "$content" | sed "/^  $name:/,/^  [a-z]/d" | sed '$ s/$//')

  # Append updated profile to content
  content="$content
  $name:
    key: $key
    secret: $secret
    endpoint: $endpoint"

  # Only add bucket field if provided (optional)
  if [ -n "$bucket" ]; then
    content="$content
    bucket: $bucket"
  fi

  encrypt_profiles "$content"
  if [ $? -eq 0 ]; then
    echo "✓ Profile '$name' updated successfully"
  fi
}

# Delete profile with confirmation
delete_profile() {
  local name=$1

  if [ -z "$name" ]; then
    read -p "Profile name to delete: " name
  fi

  local content=$(decrypt_profiles)
  if [ $? -ne 0 ]; then
    echo "Error: No profiles found"
    return 1
  fi

  if ! echo "$content" | grep -q "^  $name:"; then
    echo "Error: Profile '$name' not found"
    return 1
  fi

  # Confirmation prompt before destructive operation
  read -p "Are you sure you want to delete profile '$name'? (yes/no): " confirm
  # != is "not equal" comparison operator
  if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    return 0
  fi

  # Remove profile (handles last profile and others)
  # First sed:
  #   /^  $name:/,/^  [a-z]*:/d = delete from this profile to next profile line (colon-terminated)
  #   [a-z]*: handles both "key:" type lines and profile names with colon
  #   d = delete matching lines
  # Second sed:
  #   /^  $/d = delete lines with only 2 spaces (empty profile section lines)
  # Third sed:
  #   '$ s/[[:space:]]*$//' = on last line, remove all trailing whitespace
  #   [[:space:]]* = regex character class for any whitespace (space, tab, etc.)
  #   * = zero or more of preceding character class
  #   $ = end of line
  content=$(echo "$content" | sed "/^  $name:/,/^  [a-z]*:/d" | sed '/^  $/d')
  content=$(echo "$content" | sed '$ s/[[:space:]]*$//')

  encrypt_profiles "$content"
  if [ $? -eq 0 ]; then
    echo "✓ Profile '$name' deleted successfully"
  fi
}

# Main command dispatcher
# case "$1" in ... esac: switch statement based on first argument
# "$1" = first command-line argument to this script
# | operator allows multiple patterns to match same case (e.g., delete|remove)
case "$1" in
add)
  # Call add_profile function with second argument ($2) as the profile name
  add_profile "$2"
  ;;
edit)
  edit_profile "$2"
  ;;
delete | remove)
  # | means "OR" - both "delete" and "remove" commands do the same thing
  delete_profile "$2"
  ;;
list | ls)
  # Both "list" and "ls" shortcuts work
  list_profiles
  ;;
"")
  # Empty string - if no argument provided, show list as default
  list_profiles
  ;;
*)
  # * is wildcard/default case - matches any unrecognized command
  echo "Usage: obsutil-manage [command] [args]"
  echo ""
  echo "Commands:"
  echo "  add [name]      Add a new profile (interactive)"
  echo "  edit [name]     Edit an existing profile"
  echo "  delete [name]   Delete a profile"
  echo "  list            List all profiles"
  echo ""
  echo "Examples:"
  echo "  obsutil-manage add sk"
  echo "  obsutil-manage edit bk"
  echo "  obsutil-manage delete old-profile"
  echo "  obsutil-manage list"
  ;;
esac
