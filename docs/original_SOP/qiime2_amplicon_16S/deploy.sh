#!/usr/bin/env bash
# Purpose: rsync this qiime2_amplicon folder to a server directory.
# Usage: bash deploy.sh user@server:/path/to/project/qiime2
# Example: bash deploy.sh user@server:/home/user/qiime2_project/qiime2
# The script excludes results/, work/, .DS_Store, and logs so you deploy a clean copy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  echo "Usage: bash deploy.sh user@server:/path/to/dir" >&2
  exit 1
fi
exec rsync -av --delete \
  --exclude 'results/' --exclude 'work/' --exclude '.DS_Store' \
  --exclude 'config.local.sh' \
  "${SCRIPT_DIR}/" "${TARGET}/"
