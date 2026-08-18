#!/bin/bash

# Download a file from Huawei Cloud OBS and open it in nvim
# Preserves original file extension, overrides existing files

OBS_URI=${1:-}
OUTPUT_DIR="/Users/fran/Code/legal-data/tmp"

if [ -z "$OBS_URI" ]; then
  echo "Usage: $0 <obs://bucket/path/to/file> [custom-output-name]"
  echo ""
  echo "Examples:"
  echo "  $0 obs://data-ai-internal/fran-test/slovakia/output/sample/2026-07-24-4/file.xml"
  echo "  $0 obs://my-bucket/documents/report.json my-report.json"
  echo ""
  echo "If custom-output-name is not provided, defaults to: obsfile.<original-extension>"
  exit 1
fi

# Remove obs:// prefix and parse bucket/path
OBS_PATH="${OBS_URI#obs://}"
BUCKET="${OBS_PATH%%/*}"
FILE_PATH="${OBS_PATH#*/}"

# Extract file extension from original path
EXTENSION="${FILE_PATH##*.}"

# Use custom name if provided, otherwise use obsfile.<ext>
if [ -z "$2" ]; then
  OUTPUT_NAME="obsfile.${EXTENSION}"
else
  OUTPUT_NAME="$2"
fi

OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"

echo "Downloading from obs://${BUCKET}/${FILE_PATH}"
echo "Saving to: ${OUTPUT_PATH}"

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Download with force overwrite using obsutil-bucket.sh (quiet mode to skip key prompt)
$HOME/.obsutil/obsutil-bucket.sh cp "obs://${BUCKET}/${FILE_PATH}" "${OUTPUT_PATH}" -f

if [ $? -eq 0 ]; then
  echo "✓ File downloaded successfully"
  echo "Opening in nvim..."
  nvim "${OUTPUT_PATH}"
else
  echo "✗ Failed to download file"
  exit 1
fi
