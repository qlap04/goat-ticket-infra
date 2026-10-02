#!/usr/bin/env bash
set -euo pipefail

find . -name "*.bicep" | while read -r file; do
  echo "Linting: $file"
  az bicep build --file "$file" --stdout > /dev/null || exit 1
done
echo "All Bicep files passed lint."
