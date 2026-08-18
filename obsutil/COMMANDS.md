# obsutil Commands

Quick reference for common obsutil commands for Huawei Cloud OBS (Object Storage Service).

## View a Single File

### See file metadata/properties
```bash
obsutil stat obs://bucket-name/file-path
```

### Download and read a file
```bash
obsutil cp obs://bucket-name/file-path /local/path/
```

### With options
```bash
# Human-readable file sizes
obsutil stat obs://bucket-name/file-path -bf=human-readable

# Force overwrite
obsutil cp obs://bucket-name/file-path /local/path/ -f

# Verify MD5 checksums
obsutil cp obs://bucket-name/file-path /local/path/ -vmd5

# Verify file sizes
obsutil cp obs://bucket-name/file-path /local/path/ -vlength
```

## Explore Folders & Files

### List all objects in a bucket
```bash
obsutil ls obs://bucket-name
```

### List with folder structure (non-recursive)
```bash
obsutil ls obs://bucket-name -d
```

### List a specific folder/prefix
```bash
obsutil ls obs://bucket-name/folder-prefix
```

### Simplified output (names only)
```bash
obsutil ls obs://bucket-name -s
```

### Limit results
```bash
obsutil ls obs://bucket-name -limit=10
```

## Count Files/Folders

### Display file and folder counts
```bash
obsutil ls obs://bucket-name
```

Output example:
```
Total size of bucket: 200B
Folder number: 0
File number: 4
```

## Common ls Options

| Option | Description |
|--------|-------------|
| `-d` | Show only current directory contents (non-recursive) |
| `-s` | Simplified output (names only) |
| `-v` | Show all object versions |
| `-du` | Display disk usage information |
| `-limit=N` | Limit results to N items |

## References

- [Official Huawei Cloud obsutil Documentation](https://support.huaweicloud.com/intl/en-us/utiltg-obs/obs_11_0001.html)
- [Listing Objects](https://support.huaweicloud.com/intl/en-us/utiltg-obs/obs_11_0014.html)
- [Querying Object Properties](https://support.huaweicloud.com/intl/en-us/utiltg-obs/obs_11_0015.html)
- [Downloading Objects](https://support.huaweicloud.com/intl/en-us/utiltg-obs/obs_11_0018.html)
