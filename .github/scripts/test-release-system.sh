#!/usr/bin/env bash
# test-release-system.sh - Quick test of release automation system
# This script runs all safe tests without modifying the repository

set -uo pipefail  # Removed -e to continue on errors

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "$1"
    echo "════════════════════════════════════════════════════════"
}

print_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    ((TESTS_PASSED++)) || true
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC} $1"
    ((TESTS_FAILED++)) || true
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

print_header "Release System Tests"
echo "Repository: $REPO_ROOT"
echo "Running safe tests (no modifications)..."

# Test 1: Check files exist
print_test "1. Checking required files exist"
if [ -f "VERSION" ] && [ -f ".github/scripts/bump-version.sh" ] && [ -f ".github/workflows/release.yml" ]; then
    print_pass "All required files exist"
else
    print_fail "Missing required files"
fi

# Test 2: Check script is executable
print_test "2. Checking bump-version.sh is executable"
if [ -x ".github/scripts/bump-version.sh" ]; then
    print_pass "Script is executable"
else
    print_fail "Script is not executable"
fi

# Test 3: VERSION file format
print_test "3. Checking VERSION file format"
VERSION_CONTENT=$(cat VERSION)
if [[ "$VERSION_CONTENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+-0-g[0-9a-f]{40}$ ]]; then
    print_pass "VERSION file format is correct: $VERSION_CONTENT"
else
    print_fail "VERSION file format is incorrect: $VERSION_CONTENT"
fi

# Test 4: Extract current version
print_test "4. Extracting current version"
CURRENT_VERSION=$(cat VERSION | cut -d'-' -f1)
if [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_pass "Current version: $CURRENT_VERSION"
else
    print_fail "Could not extract valid version: $CURRENT_VERSION"
    CURRENT_VERSION="5.5.0"  # Fallback for remaining tests
fi

# Test 5: Test patch version calculation
print_test "5. Testing patch version calculation"
PATCH_OUTPUT=$(echo "n" | ./.github/scripts/bump-version.sh patch 2>&1 || true)
PATCH_VERSION=$(echo "$PATCH_OUTPUT" | grep "New version:" | cut -d: -f2 | xargs || echo "")
IFS='.' read -r MAJ MIN PAT <<< "$CURRENT_VERSION"
EXPECTED_PATCH="${MAJ}.${MIN}.$((PAT + 1))"
if [ "$PATCH_VERSION" == "$EXPECTED_PATCH" ]; then
    print_pass "Patch: $CURRENT_VERSION → $PATCH_VERSION"
else
    print_fail "Expected $EXPECTED_PATCH, got '$PATCH_VERSION'"
fi

# Test 6: Test minor version calculation
print_test "6. Testing minor version calculation"
MINOR_OUTPUT=$(echo "n" | ./.github/scripts/bump-version.sh minor 2>&1 || true)
MINOR_VERSION=$(echo "$MINOR_OUTPUT" | grep "New version:" | cut -d: -f2 | xargs || echo "")
EXPECTED_MINOR="${MAJ}.$((MIN + 1)).0"
if [ "$MINOR_VERSION" == "$EXPECTED_MINOR" ]; then
    print_pass "Minor: $CURRENT_VERSION → $MINOR_VERSION"
else
    print_fail "Expected $EXPECTED_MINOR, got '$MINOR_VERSION'"
fi

# Test 7: Test major version calculation
print_test "7. Testing major version calculation"
MAJOR_OUTPUT=$(echo "n" | ./.github/scripts/bump-version.sh major 2>&1 || true)
MAJOR_VERSION=$(echo "$MAJOR_OUTPUT" | grep "New version:" | cut -d: -f2 | xargs || echo "")
EXPECTED_MAJOR="$((MAJ + 1)).0.0"
if [ "$MAJOR_VERSION" == "$EXPECTED_MAJOR" ]; then
    print_pass "Major: $CURRENT_VERSION → $MAJOR_VERSION"
else
    print_fail "Expected $EXPECTED_MAJOR, got '$MAJOR_VERSION'"
fi

# Test 8: Test specific version
print_test "8. Testing specific version (6.0.0)"
SPECIFIC_OUTPUT=$(echo "n" | ./.github/scripts/bump-version.sh 6.0.0 2>&1 || true)
SPECIFIC_VERSION=$(echo "$SPECIFIC_OUTPUT" | grep "New version:" | cut -d: -f2 | xargs || echo "")
if [ "$SPECIFIC_VERSION" == "6.0.0" ]; then
    print_pass "Specific version: $CURRENT_VERSION → $SPECIFIC_VERSION"
else
    print_fail "Expected 6.0.0, got '$SPECIFIC_VERSION'"
fi

# Test 9: Test invalid version type
print_test "9. Testing invalid version type handling"
if ! echo "n" | ./.github/scripts/bump-version.sh invalid >/dev/null 2>&1; then
    print_pass "Invalid version type properly rejected (exit code 1)"
else
    print_fail "Invalid version type not properly rejected"
fi

# Test 10: Check ChangeLog exists and has current version
print_test "10. Checking ChangeLog"
if [ -f "ChangeLog" ] && grep -q "^\* $CURRENT_VERSION" ChangeLog; then
    print_pass "ChangeLog exists and has current version entry"
else
    print_fail "ChangeLog missing or doesn't have current version"
fi

# Test 11: Test ChangeLog extraction
print_test "11. Testing ChangeLog extraction"
NOTES_FILE=$(mktemp)
awk -v ver="$CURRENT_VERSION" '
  /^\* [0-9]+\.[0-9]+\.[0-9]+/ {
    if (in_section) exit;
    if ($0 ~ ver) {
      in_section=1;
      next;
    }
  }
  in_section { print }
' ChangeLog > "$NOTES_FILE" 2>/dev/null || true

if [ -s "$NOTES_FILE" ]; then
    LINE_COUNT=$(wc -l < "$NOTES_FILE")
    print_pass "Extracted $LINE_COUNT lines of release notes"
else
    print_fail "Could not extract release notes"
fi
rm -f "$NOTES_FILE"

# Test 12: Check workflow YAML syntax (if actionlint is available)
print_test "12. Validating workflow YAML"
if command -v actionlint &> /dev/null; then
    if actionlint .github/workflows/release.yml 2>&1 | grep -q -E "(no error|no problem)"; then
        print_pass "Workflow YAML is valid"
    else
        print_fail "Workflow YAML has issues"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC} actionlint not installed (optional)"
fi

# Test 13: Check documentation exists
print_test "13. Checking documentation"
if [ -f "RELEASING.adoc" ] && [ -f "TESTING_RELEASE.adoc" ]; then
    print_pass "Documentation files exist"
else
    print_fail "Documentation files missing"
fi

# Summary
print_header "Test Summary"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo "Total tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo "Failed: 0"
fi

echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the test output above"
    echo "  2. See TESTING_RELEASE.adoc for more thorough testing"
    echo "  3. See RELEASING.adoc for usage instructions"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Please review the failures above and fix any issues."
    exit 1
fi