#!/usr/bin/env bash

# Static analysis script for jemalloc using Clang static analyzer and CodeChecker
#
# Requirements:
#   - clang/clang++ (18+)
#   - bear (compilation database generator)
#   - CodeChecker (static analysis framework)
#   - jq (JSON processor)
#   - libunwind (for profiling support)
#
# Usage:
#   ./run_static_analysis.sh [output_dir] [github_output_file]
#
# Arguments:
#   output_dir:          Directory for HTML results (default: static_analysis_results)
#   github_output_file:  File for GitHub Actions outputs (default: /dev/null)
#
# Exit codes:
#   0: Analysis completed (with or without issues found)
#   1: Analysis failed to run

set -euo pipefail

# Colors for output (disabled in non-TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' #  No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Parse arguments
html_output_dir="${1:-static_analysis_results}"
github_output_file="${2:-/dev/null}"

log_info "Static Analysis Starting"
log_info "Output directory: $html_output_dir"

# Clean previous build artifacts
log_info "Cleaning previous build artifacts..."
# Configure git safe.directory for Docker environments where ownership may differ
git config --global --add safe.directory /work 2>/dev/null || true
git clean -Xfd

# Setup compiler environment
# Use CC/CXX from environment if already set (e.g. by Docker or install-llvm-action)
# Otherwise default to system clang
if [ -z "${CC:-}" ]; then
    export CC='clang'
fi
if [ -z "${CXX:-}" ]; then
    export CXX='clang++'
fi

log_info "Using CC=$CC"
log_info "Using CXX=$CXX"

# Verify required tools
log_info "Verifying required tools..."
for tool in bear jq CodeChecker "$CC" "$CXX"; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        log_error "Required tool not found: $tool"
        exit 1
    fi
done
log_success "All required tools found"

# Comprehensive compile-time malloc configuration for thorough analysis
compile_time_malloc_conf='background_thread:true,'\
'metadata_thp:auto,'\
'abort_conf:true,'\
'muzzy_decay_ms:0,'\
'zero_realloc:free,'\
'prof_unbias:false,'\
'prof_time_resolution:high'

# Extra warning flags for more thorough static analysis
extra_flags=(
    -Wmissing-prototypes
    -Wmissing-variable-declarations
    -Wstrict-prototypes
    -Wunreachable-code
    -Wunreachable-code-aggressive
    -Wunused-macros
)

# Configure and build with instrumentation
log_info "Configuring jemalloc with debug and profiling enabled..."
EXTRA_CFLAGS="${extra_flags[*]}" \
EXTRA_CXXFLAGS="${extra_flags[*]}" \
./autogen.sh \
    --with-private-namespace=jemalloc_ \
    --disable-cache-oblivious \
    --enable-prof \
    --enable-prof-libunwind \
    --with-malloc-conf="$compile_time_malloc_conf" \
    --enable-readlinkat \
    --enable-opt-safety-checks \
    --enable-uaf-detection \
    --enable-force-getenv \
    --enable-debug

log_info "Building with compilation database (bear)..."
bear -- make -s -j "$(nproc)"

# Deduplicate compilation database
# We end up with duplicate entries for each output type (.o, .d, .sym, etc.)
# CodeChecker's cross-translation-unit analysis requires exactly one entry per file
log_info "Deduplicating compilation database..."
if [ ! -f compile_commands.json ]; then
    log_error "compile_commands.json not generated"
    exit 1
fi

jq '[.[] | select(.output | test("/[^./]*\\.o$"))]' compile_commands.json > compile_commands.json.tmp
mv compile_commands.json.tmp compile_commands.json

entry_count=$(jq length compile_commands.json)
log_success "Compilation database ready with $entry_count entries"

# Create skipfile for system headers
# CodeChecker has a bug with process substitution, so use temporary file
skipfile=$(mktemp)
trap 'rm -f "$skipfile"' EXIT
echo '-**/stdlib.h' > "$skipfile"

# Run CodeChecker analysis
log_info "Running CodeChecker static analysis..."
log_info "This may take 10-15 minutes for full analysis"

CC_ANALYZERS_FROM_PATH=1 CodeChecker analyze \
    compile_commands.json \
    --jobs "$(nproc)" \
    --ctu \
    --compile-uniqueing strict \
    --output static_analysis_raw_results \
    --analyzers clangsa clang-tidy \
    --skip "$skipfile" \
    --enable readability-inconsistent-declaration-parameter-name \
    --enable performance-no-int-to-ptr \
    --disable clang-diagnostic-reserved-macro-identifier \
    --disable misc-header-include-cycle \
    --disable bugprone-switch-missing-default-case

log_success "Analysis complete"

# Export results to HTML
log_info "Generating HTML reports in $html_output_dir..."
if CodeChecker parse \
    --export html \
    --output "$html_output_dir" \
    static_analysis_raw_results
then
    log_success "No static analysis issues found"
    # Only write to github_output_file if it's writable (not /dev/null and parent dir exists)
    if [ "$github_output_file" != "/dev/null" ] && [ -n "$github_output_file" ]; then
        mkdir -p "$(dirname "$github_output_file")" 2>/dev/null || true
        echo "HAS_STATIC_ANALYSIS_RESULTS=0" >> "$github_output_file" 2>/dev/null || echo "HAS_STATIC_ANALYSIS_RESULTS=0"
    fi
else
    log_warning "Static analysis found issues"
    log_info "HTML report generated at: $html_output_dir/index.html"
    # Only write to github_output_file if it's writable (not /dev/null and parent dir exists)
    if [ "$github_output_file" != "/dev/null" ] && [ -n "$github_output_file" ]; then
        mkdir -p "$(dirname "$github_output_file")" 2>/dev/null || true
        echo "HAS_STATIC_ANALYSIS_RESULTS=1" >> "$github_output_file" 2>/dev/null || echo "HAS_STATIC_ANALYSIS_RESULTS=1"
    fi
fi

log_info "Static analysis complete"
