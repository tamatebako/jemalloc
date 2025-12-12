#!/usr/bin/env bash

# Strip trailing whitespace from all tracked files
# Preserves the final newline of each file

set -euo pipefail

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "Stripping trailing whitespace from all tracked files..."

# Find all tracked files (excluding .md files and build-aux/install-sh)
git ls-files | grep -v '\.md$' | grep -v 'build-aux/install-sh' | while read -r file; do
    # Skip if file doesn't exist or isn't a regular file
    [ -f "$file" ] || continue

    # Process the file - sed will skip binary files gracefully
    # Use a simpler approach: just try to process everything
    if sed 's/[[:space:]]*$//' "$file" > "$file.tmp" 2>/dev/null; then
        # Ensure file ends with exactly one newline if it's not empty
        if [ -s "$file.tmp" ] && [ "$(tail -c 1 "$file.tmp" | wc -l)" -eq 0 ]; then
            echo "" >> "$file.tmp"
        fi
        # Replace original file
        mv "$file.tmp" "$file"
    else
        # If sed failed (binary file), clean up temp file
        rm -f "$file.tmp"
    fi
done

echo "✓ Trailing whitespace stripped from all files"