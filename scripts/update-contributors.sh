#!/usr/bin/env bash
#
# Update Contributors Table in README.md
# 
# This script queries the GitHub Contributors API and regenerates the 
# contributors table in README.md between the CONTRIBUTORS_START and 
# CONTRIBUTORS_END markers.
#
# Usage: ./scripts/update-contributors.sh [owner] [repo]
#   Default: timlinux nixmywindows

set -euo pipefail

# Configuration
OWNER="${1:-timlinux}"
REPO="${2:-nixmywindows}"
README_FILE="README.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Please install jq."
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    log_error "curl is required but not installed. Please install curl."
    exit 1
fi

# Check if README.md exists
if [ ! -f "$README_FILE" ]; then
    log_error "README.md not found in current directory"
    exit 1
fi

# Check for markers in README
if ! grep -q "<!-- CONTRIBUTORS_START -->" "$README_FILE"; then
    log_error "CONTRIBUTORS_START marker not found in README.md"
    exit 1
fi

if ! grep -q "<!-- CONTRIBUTORS_END -->" "$README_FILE"; then
    log_error "CONTRIBUTORS_END marker not found in README.md"
    exit 1
fi

log_info "Fetching contributors from GitHub API..."

# Fetch contributors from GitHub API
# Use GITHUB_TOKEN if available for higher rate limits
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
else
    AUTH_HEADER=""
fi

# Fetch all contributors (paginated)
PAGE=1
ALL_CONTRIBUTORS="[]"

while true; do
    log_info "Fetching page $PAGE..."
    
    if [ -n "$AUTH_HEADER" ]; then
        RESPONSE=$(curl -s -H "$AUTH_HEADER" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/$OWNER/$REPO/contributors?per_page=100&page=$PAGE")
    else
        RESPONSE=$(curl -s \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/$OWNER/$REPO/contributors?per_page=100&page=$PAGE")
    fi
    
    # Check if response is empty or has error
    if [ "$RESPONSE" = "[]" ] || [ -z "$RESPONSE" ]; then
        break
    fi
    
    # Check for API errors
    if echo "$RESPONSE" | jq -e 'has("message")' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"')
        log_error "GitHub API error: $ERROR_MSG"
        # If it's a rate limit or network issue, exit gracefully
        if echo "$RESPONSE" | jq -e 'has("documentation_url")' > /dev/null 2>&1; then
            log_warn "This might be a rate limit issue. Try again later or use GITHUB_TOKEN."
        fi
        exit 1
    fi
    
    # Verify response is valid JSON array
    if ! echo "$RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
        log_error "Invalid response from GitHub API (not an array)"
        exit 1
    fi
    
    # Merge with existing contributors
    ALL_CONTRIBUTORS=$(echo "$ALL_CONTRIBUTORS" "$RESPONSE" | jq -s '.[0] + .[1]')
    
    # Check if we got less than 100 results (last page)
    COUNT=$(echo "$RESPONSE" | jq 'length')
    if [ "$COUNT" -lt 100 ]; then
        break
    fi
    
    PAGE=$((PAGE + 1))
done

CONTRIBUTOR_COUNT=$(echo "$ALL_CONTRIBUTORS" | jq 'length')
log_info "Found $CONTRIBUTOR_COUNT contributors"

if [ "$CONTRIBUTOR_COUNT" -eq 0 ]; then
    log_warn "No contributors found"
    exit 0
fi

# Generate markdown table
log_info "Generating contributors table..."

TABLE_HEADER="| Avatar | GitHub | Contributions |"
TABLE_SEPARATOR="|--------|--------|---------------|"
TABLE_ROWS=""

# Process each contributor using process substitution to avoid subshell
while IFS= read -r contributor; do
    LOGIN=$(echo "$contributor" | jq -r '.login')
    AVATAR_URL=$(echo "$contributor" | jq -r '.avatar_url')
    CONTRIBUTIONS=$(echo "$contributor" | jq -r '.contributions')
    PROFILE_URL=$(echo "$contributor" | jq -r '.html_url')

    # Skip bots if desired (optional)
    # if [[ "$LOGIN" == *"[bot]"* ]]; then
    #     continue
    # fi

    ROW="| <img src=\"$AVATAR_URL\" width=\"64\" height=\"64\" alt=\"$LOGIN\"> | [$LOGIN]($PROFILE_URL) | $CONTRIBUTIONS |"
    TABLE_ROWS="${TABLE_ROWS}${ROW}\n"
done < <(echo "$ALL_CONTRIBUTORS" | jq -c '.[]')

# Construct the full table
NEW_CONTENT="<!-- CONTRIBUTORS_START -->\n"
NEW_CONTENT="${NEW_CONTENT}${TABLE_HEADER}\n"
NEW_CONTENT="${NEW_CONTENT}${TABLE_SEPARATOR}\n"
NEW_CONTENT="${NEW_CONTENT}${TABLE_ROWS}"
NEW_CONTENT="${NEW_CONTENT}<!-- CONTRIBUTORS_END -->"

# Create temporary file with updated content
TEMP_FILE=$(mktemp)

# Extract content before and after markers
awk '/<!-- CONTRIBUTORS_START -->/ {exit} {print}' "$README_FILE" > "$TEMP_FILE"
echo -e "$NEW_CONTENT" >> "$TEMP_FILE"
awk '/<!-- CONTRIBUTORS_END -->/ {found=1; next} found {print}' "$README_FILE" >> "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$README_FILE"

log_info "✓ Contributors table updated successfully!"
log_info "Updated $CONTRIBUTOR_COUNT contributors in $README_FILE"
