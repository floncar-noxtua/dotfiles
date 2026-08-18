# obsutil Profile Manager

Encrypted profile management for obsutil with password protection.

## Setup

All files are in `~/.obsutil/`:
- `profiles.yaml.gpg` - Your encrypted profiles (created on first use)
- `init.sh` - Initialization script (sourced from ~/.zshrc)
- `manage.sh` - Profile management CLI
- `README.md` - This file

Your `~/.zshrc` now sources `init.sh` automatically on shell startup.

## Quick Start

### 1. Add your first profile

```bash
obsutil-manage add sk
# Interactive prompts for:
# - Access Key ID
# - Secret Key (hidden input)
# - Endpoint
# - Bucket name (optional)
```

### 2. Configure a profile (set as current)

```bash
obsutil-default-profile sk
# You'll be prompted for your GPG passphrase
# ✓ Connected to profile: sk
#   Endpoint: data-ai-internal.obs.eu-de.otc.t-systems.com
```

### 3. Use obsutil-bucket (recommended)

```bash
# Use current profile (no passphrase needed)
obsket sk ls
# or with alias:
obsket sk cp local-file.txt obs://

# Switch to different profile temporarily (one-time use)
obsket other-profile ls
# Prompts for passphrase, doesn't change ./obsutil config
```

### 4. Or use ./obsutil directly

```bash
# All credentials are now configured
./obsutil ls
./obsutil cp local-file.txt obs://bucket-name/
```

## Commands

### obsutil-bucket (alias: `obsket`)

Smart wrapper that intelligently manages bucket access with different profiles.

**Syntax:**
```bash
obsutil-bucket [-p=profile-name] <command> [args...]
# Alias: obsket [-p=profile-name] <command> [args...]
```

**Supported commands:**
- `ls` — List objects in bucket
- `cp` — Copy objects to/from bucket
- `rm` — Remove objects
- `stat` — Get object statistics
- `restore` — Restore archived objects
- `sign-url` — Generate signed URLs
- *(any obsutil command)*

**Examples:**
```bash
# Use current connected profile (no -p flag needed)
obsket ls obs://data-beck-sk
obsket cp local-file.txt obs://data-beck-sk/remote-path
obsket rm obs://data-beck-sk/file.txt

# With full command name
obsutil-bucket ls obs://data-beck-sk

# Switch to different profile (one-time, doesn't change ./obsutil config)
obsket -p=prod-bucket ls obs://prod-bucket
# Prompts for passphrase (if not cached), uses prod-bucket's credentials

# Back to original profile (no passphrase prompt, uses config)
obsket ls obs://data-beck-sk
```

**Smart Behavior:**
- ✅ **No -p flag**: Uses current profile's credentials from `./obsutil config` (no decryption needed)
- ✅ **-p matches current**: Uses credentials from `./obsutil config` (no decryption needed)
- ✅ **-p differs from current**: Prompts for passphrase, injects those credentials temporarily
- ✅ **Never modifies config**: Temporary switching, doesn't affect `./obsutil config` or `current-profile.conf`
- ✅ **Explicit bucket required**: You must specify the bucket path (e.g., `obs://bucket-name`)
- ✅ **Short alias**: Use `obsket` for quick access

**How it works:**
1. `obsutil-default-profile beck-sk` → runs `./obsutil config -i=... -k=... -e=...` and saves "beck-sk:bucket-name" to `~/.obsutil/current-profile.conf`
2. `obsket ls obs://data-beck-sk` → checks if "beck-sk" == current profile → YES → uses credentials from config (no passphrase needed!)
3. `obsket -p=other-profile ls obs://other-bucket` → checks if profile matches current → NO → prompts for passphrase, injects temp credentials

### obsutil-manage

```bash
# List all profiles
obsutil-manage list
obsutil-manage ls

# Add a new profile (interactive)
obsutil-manage add <profile-name>

# Edit existing profile (interactive)
obsutil-manage edit <profile-name>

# Delete a profile
obsutil-manage delete <profile-name>
obsutil-manage remove <profile-name>

# Show help
obsutil-manage
```

### obsutil-default-profile

Sets the default profile for `./obsutil` commands and profile-aware operations.

**Syntax:**
```bash
obsutil-default-profile <profile-name>
```

**What it does:**
1. Prompts for passphrase to decrypt profiles
2. Reads the profile's credentials (key, secret, endpoint, bucket)
3. Configures `./obsutil` with those credentials (updates `~/.obsutilconfig`)
4. Saves profile info to unencrypted `~/.obsutil/current-profile.conf` file

**Examples:**
```bash
# Set profile as default
obsutil-default-profile data-ai-internal
# Enter passphrase to unlock profiles: ••••••••
# ✓ Connected to profile: data-ai-internal
#   Endpoint: https://obs.eu-de.otc.t-systems.com

# Now ./obsutil uses those credentials automatically
./obsutil ls

# Switch to different profile
obsutil-default-profile prod-bucket
# Prompts for passphrase again

# Show available profiles (if profile not found)
obsutil-default-profile
# Lists all available profiles
```

**What gets saved:**
```bash
# ~/.obsutil/current-profile.conf contains (unencrypted):
# profile-name:bucket-name
# Example: ai-internal:data-ai-internal

# ~/.obsutilconfig contains (readable by obsutil):
# endpoint, ak (access key), sk (secret key), and other config
```

### obsutil-profiles

```bash
# Quick shortcut to list profiles
obsutil-profiles
```

## Security

- **Encryption**: AES256 (military-grade encryption)
- **Passphrase**: Set when first encrypting (GPG will prompt)
- **Storage**: `~/.obsutil/profiles.yaml.gpg` is encrypted
- **Session-scoped**: Credentials loaded in memory per session, not stored in shell history

## Workflow Example

### With obsutil-bucket wrapper (recommended)

```bash
# Session 1: Connect to a profile (sets up ./obsutil config)
$ obsutil-default-profile data-ai-internal
Enter passphrase to unlock profiles: ••••••••
✓ Connected to profile: data-ai-internal
  Endpoint: https://obs.eu-de.otc.t-systems.com

# Now ./obsutil config has credentials stored
# Use obsutil-bucket with current profile (no passphrase needed, no -p flag)
$ obsutil-bucket ls obs://data-ai-internal
# Lists objects in data-ai-internal bucket
# Uses credentials from ./obsutil config (already set up)

$ obsutil-bucket cp local-file.txt obs://data-ai-internal/remote-path
# Uploads to data-ai-internal bucket

# Switch to different bucket temporarily (prompts for passphrase, one-time use)
$ obsutil-bucket -p=other-profile ls obs://other-bucket
Enter passphrase to unlock profiles: ••••••••
# Lists objects in other-bucket
# ./obsutil config is NOT changed

# Back to original profile (no passphrase prompt)
$ obsutil-bucket ls obs://data-ai-internal
# Uses credentials from ./obsutil config (still has data-ai-internal credentials)
# Lists objects in data-ai-internal bucket
```

### Profile with bucket field

When adding profiles, you can optionally specify the bucket:

```bash
$ obsutil-manage add my-profile
Access Key ID: ...
Secret Key (hidden): ...
Endpoint: https://obs.eu-de.otc.t-systems.com
Bucket name (optional): my-bucket-name
```

The profile YAML will look like:
```yaml
profiles:
  my-profile:
    key: access-key-123
    secret: secret-key-456
    endpoint: https://obs.eu-de.otc.t-systems.com
    bucket: my-bucket-name
```

## Manage Profiles

```bash
# Add multiple profiles
$ obsutil-manage add sk
$ obsutil-manage add bk
$ obsutil-manage add prod

# List them
$ obsutil-manage list
Available profiles:
  ✓ sk
  ✓ bk
  ✓ prod

# Edit a profile (only change fields you want to update)
$ obsutil-manage edit sk
Access Key ID [current-key]: [press enter to keep]
Secret Key [current-secret] (hidden): [new-secret]
Endpoint [current-endpoint]: [press enter to keep]

# Delete a profile
$ obsutil-manage delete old-profile
Are you sure you want to delete profile 'old-profile'? (yes/no): yes
```

## Files Overview

```
~/.obsutil/
├── README.md              # This file
├── init.sh               # Initialization - loads functions & aliases
├── manage.sh             # Profile management CLI tool
├── obsutil-bucket.sh     # Smart bucket wrapper script
├── profiles.yaml.gpg     # Your encrypted profiles (created on first use)
└── current-profile.conf  # Unencrypted: stores current profile name and bucket
                          # Format: profile-name:bucket-name
                          # Example: ai-internal:data-ai-internal

~/.obsutilconfig (in home directory)
└── Generated by ./obsutil config command
    Contains credentials (endpoint, ak, sk, etc) for current profile
```

**Key files explained:**
- **profiles.yaml.gpg** — All your profiles encrypted with AES256 + passphrase
- **current-profile.conf** — Currently configured profile (readable, not encrypted)
- **~/.obsutilconfig** — Generated by obsutil, contains credentials for quick access

## Environment Variables

After running `obsutil-default-profile <profile>`, these are set for the session:

```bash
OBSUTIL_KEY="..."           # Access Key ID
OBSUTIL_SECRET="..."        # Secret Key
OBSUTIL_ENDPOINT="..."      # Endpoint URL
```

An alias `obsutil` is also created that includes these credentials automatically.

## When to Use Each Tool

| Tool | Purpose | Example |
|------|---------|---------|
| **obsutil-manage** | Add/edit/delete profiles | `obsutil-manage add prod` |
| **obsutil-default-profile** | Set which profile obsutil uses | `obsutil-default-profile prod` |
| **obsutil-bucket (obsket)** | Run commands with explicit bucket path | `obsket ls obs://prod-bucket` |
| **./obsutil** | Direct access (credentials from config) | `./obsutil ls` |

**Workflow:**
1. Create profiles once: `obsutil-manage add prod`
2. Set default: `obsutil-default-profile prod`
3. Use bucket wrapper: `obsket ls obs://prod-bucket` (uses current profile, no -p needed)
4. Or switch temporarily: `obsket -p=other-profile ls obs://other-bucket` (different profile, prompts once)

---

## Troubleshooting

### "Profile not found"
Check available profiles:
```bash
obsutil-manage list
```

### "Could not decrypt profiles"
- GPG passphrase entry was cancelled
- Wrong passphrase entered
- File corrupted (restore from backup)

### "Profile already exists"
Use `obsutil-manage edit <name>` to modify instead of add.

### Symlink issues
If `~/.zshrc` isn't using the dotfiles version:
```bash
ln -sf ~/dotfiles/zshrc/zshrc ~/.zshrc
```

## Adding to Git

**DO NOT** add `profiles.yaml.gpg` to version control unless it's a separate encrypted repo. 
Add to `.gitignore`:
```bash
.obsutil/profiles.yaml.gpg
```

You can safely version control `init.sh` and `manage.sh` - they're generic.
