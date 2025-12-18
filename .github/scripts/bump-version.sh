#!/usr/bin/env bash
# bump-version.sh - Bump jemalloc version using git tags as source of truth
# Usage: ./bump-version.sh [major|minor|patch|X.Y.Z]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Files to update
CHANGELOG_FILE="$REPO_ROOT/ChangeLog"
VCPKG_JSON="$REPO_ROOT/ports/jemalloc/vcpkg.json"

# Print functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate input
if [ $# -ne 1 ]; then
    print_error "Usage: $0 [major|minor|patch|X.Y.Z]"
    exit 1
fi

BUMP_TYPE="$1"

# Read current version from git tags
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "")

if [ -z "$CURRENT_VERSION" ]; then
    # Fallback to vcpkg.json if no tags
    if [ -f "$VCPKG_JSON" ]; then
        CURRENT_VERSION=$(grep '"version-string"' "$VCPKG_JSON" | cut -d'"' -f4)
        print_warn "No git tags found, using vcpkg.json version: $CURRENT_VERSION"
    else
        print_error "No git tags found and vcpkg.json not found"
        exit 1
    fi
fi

print_info "Current version: $CURRENT_VERSION"

# Validate current version format
if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid current version format: $CURRENT_VERSION"
    exit 1
fi

# Extract version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Calculate next version
calculate_next_version() {
    case "$BUMP_TYPE" in
        major)
            echo "$((MAJOR + 1)).0.0"
            ;;
        minor)
            echo "${MAJOR}.$((MINOR + 1)).0"
            ;;
        patch)
            echo "${MAJOR}.${MINOR}.$((PATCH + 1))"
            ;;
        [0-9]*.[0-9]*.[0-9]*)
            # Validate provided version
            if ! [[ "$BUMP_TYPE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                print_error "Invalid version format: $BUMP_TYPE"
                exit 1
            fi
            echo "$BUMP_TYPE"
            ;;
        *)
            print_error "Invalid bump type: $BUMP_TYPE"
            print_error "Use: major, minor, patch, or X.Y.Z"
            exit 1
            ;;
    esac
}

NEW_VERSION=$(calculate_next_version)
print_info "New version: $NEW_VERSION"

# Confirmation prompt
read -p "Proceed with version bump from $CURRENT_VERSION to $NEW_VERSION? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warn "Version bump cancelled"
    exit 0
fi

# Update vcpkg.json
if [ -f "$VCPKG_JSON" ]; then
    print_info "Updating vcpkg.json..."
    sed -i.bak "s/\"version-string\": \".*\"/\"version-string\": \"${NEW_VERSION}\"/" "$VCPKG_JSON"
    rm -f "$VCPKG_JSON.bak"
    print_info "✓ vcpkg.json updated"
else
    print_warn "vcpkg.json not found, skipping"
fi

# Update ChangeLog
print_info "Updating ChangeLog..."
CURRENT_DATE=$(date "+%B %d, %Y")
TEMP_CHANGELOG=$(mktemp)

# Create new ChangeLog entry
cat > "$TEMP_CHANGELOG" << EOF
* ${NEW_VERSION} (${CURRENT_DATE})

  This release [describe the release here].

  New features:
  - [Add new features here]

  Portability improvements:
  - [Add portability improvements here]

  Bug fixes:
  - [Add bug fixes here]

  Optimizations:
  - [Add optimizations here]

EOF

# Append existing ChangeLog
cat "$CHANGELOG_FILE" >> "$TEMP_CHANGELOG"
mv "$TEMP_CHANGELOG" "$CHANGELOG_FILE"
print_info "✓ ChangeLog updated with template entry"

# Summary
print_info ""
print_info "═══════════════════════════════════════════════════════"
print_info "Version bump complete!"
print_info "═══════════════════════════════════════════════════════"
print_info "Old version: $CURRENT_VERSION"
print_info "New version: $NEW_VERSION"
print_info ""
print_info "Files updated:"
print_info "  - ports/jemalloc/vcpkg.json"
print_info "  - ChangeLog"
print_info ""
print_warn "Next steps:"
print_warn "  1. Review and edit the ChangeLog entry"
print_warn "  2. Commit changes: git add ports/jemalloc/vcpkg.json ChangeLog"
print_warn "  3. Create commit: git commit -m 'chore: bump version to ${NEW_VERSION}'"
print_warn "  4. Create tag: git tag -a v${NEW_VERSION} -m 'Release v${NEW_VERSION}'"
print_warn "  5. Push: git push && git push --tags"
print_info "═══════════════════════════════════════════════════════"

exit 0