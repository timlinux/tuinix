#!/usr/bin/env python3
"""
Generate contributors table for README.md

This script fetches contributors from GitHub API and generates a formatted
Markdown table that is inserted between markers in README.md.

Usage:
    python3 generate_contributors.py [owner] [repo]
    python3 generate_contributors.py --dry-run [owner] [repo]

Environment Variables:
    GITHUB_TOKEN: Optional GitHub token for authenticated requests (higher rate limits)

The script is idempotent - it only modifies README.md if the content has changed.
"""

import argparse
import html
import os
import shutil
import sys
import tempfile
from typing import Dict, List, Optional

try:
    import requests
except ImportError:
    print(
        "Error: requests library is required. Install with: pip install requests",
        file=sys.stderr,
    )
    sys.exit(1)


# Markers for the contributors section in README.md
START_MARKER = "<!-- CONTRIBUTORS_START -->"
END_MARKER = "<!-- CONTRIBUTORS_END -->"
README_FILE = "README.md"


def log(message: str) -> None:
    """Print a log message to stderr."""
    print(f"[INFO] {message}", file=sys.stderr)


def error(message: str) -> None:
    """Print an error message to stderr."""
    print(f"[ERROR] {message}", file=sys.stderr)


def fetch_contributors(
    owner: str, repo: str, token: Optional[str] = None
) -> List[Dict]:
    """
    Fetch all contributors from GitHub API with pagination.

    Args:
        owner: Repository owner
        repo: Repository name
        token: Optional GitHub token for authentication

    Returns:
        List of contributor dictionaries

    Raises:
        SystemExit: On API errors or rate limit issues
    """
    contributors = []
    page = 1
    per_page = 100

    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "nixmywindows-contributors-generator",
    }

    if token:
        headers["Authorization"] = f"Bearer {token}"
        log("Using authenticated requests with GITHUB_TOKEN")
    else:
        log("Using unauthenticated requests (lower rate limits)")

    base_url = f"https://api.github.com/repos/{owner}/{repo}/contributors"

    while True:
        url = f"{base_url}?per_page={per_page}&page={page}"
        log(f"Fetching page {page} from {url}")

        try:
            response = requests.get(url, headers=headers, timeout=30)

            # Check for rate limiting
            if response.status_code == 403:
                rate_limit_remaining = response.headers.get(
                    "X-RateLimit-Remaining", "unknown"
                )
                if rate_limit_remaining == "0" or rate_limit_remaining == 0:
                    error("GitHub API rate limit exceeded!")
                    error(
                        "Please set GITHUB_TOKEN environment variable for higher rate limits."
                    )
                    error(
                        f"Rate limit resets at: {response.headers.get('X-RateLimit-Reset', 'unknown')}"
                    )
                    sys.exit(1)

            if response.status_code == 429:
                error("GitHub API rate limit exceeded (429 Too Many Requests)!")
                error(
                    "Please wait before retrying or set GITHUB_TOKEN for higher rate limits."
                )
                retry_after = response.headers.get("Retry-After", "unknown")
                error(f"Retry after: {retry_after} seconds")
                sys.exit(1)

            # Check for other HTTP errors
            if response.status_code != 200:
                error(f"GitHub API request failed with status {response.status_code}")
                error(f"Response: {response.text}")
                sys.exit(1)

            page_contributors = response.json()

            # Empty page or less than per_page means we're done
            if not page_contributors:
                log(f"No more contributors (empty page {page})")
                break

            contributors.extend(page_contributors)
            log(f"Fetched {len(page_contributors)} contributors from page {page}")

            # If we got less than per_page, we're on the last page
            if len(page_contributors) < per_page:
                log(f"Last page reached (got {len(page_contributors)} < {per_page})")
                break

            page += 1

        except requests.exceptions.RequestException as e:
            error(f"Request failed: {e}")
            sys.exit(1)

    log(f"Total contributors fetched: {len(contributors)}")
    return contributors


def generate_markdown_table(contributors: List[Dict]) -> str:
    """
    Generate a Markdown table from contributors data.

    The table has columns: Avatar | GitHub | Contributions
    Contributors are sorted by contributions (descending), then by login (ascending).

    Args:
        contributors: List of contributor dictionaries from GitHub API

    Returns:
        Formatted Markdown table as string
    """
    # Sort contributors: by contributions descending, then by login ascending
    sorted_contributors = sorted(
        contributors,
        key=lambda c: (-c.get("contributions", 0), c.get("login", "").lower()),
    )

    # Build the table
    lines = []
    lines.append("| Avatar | GitHub | Contributions |")
    lines.append("|--------|--------|---------------|")

    for contrib in sorted_contributors:
        login = contrib.get("login", "unknown")
        avatar_url = contrib.get("avatar_url", "")
        profile_url = contrib.get("html_url", f"https://github.com/{login}")
        contributions = contrib.get("contributions", 0)

        # Escape values for HTML safety
        login_escaped = html.escape(login, quote=True)
        avatar_url_escaped = html.escape(avatar_url, quote=True)
        profile_url_escaped = html.escape(profile_url, quote=True)

        # Create avatar cell with image linking to profile
        avatar_cell = f'<a href="{profile_url_escaped}"><img src="{avatar_url_escaped}" width="50" height="50" alt="{login_escaped}"/></a>'

        # Create GitHub username cell with bold link
        github_cell = (
            f'<a href="{profile_url_escaped}"><strong>{login_escaped}</strong></a>'
        )

        # Contributions count
        contrib_cell = str(contributions)

        lines.append(f"| {avatar_cell} | {github_cell} | {contrib_cell} |")

    return "\n".join(lines)


def read_readme() -> Optional[str]:
    """
    Read README.md file.

    Returns:
        Content of README.md or None if file doesn't exist
    """
    if not os.path.exists(README_FILE):
        error(f"{README_FILE} not found in current directory")
        return None

    with open(README_FILE, "r", encoding="utf-8") as f:
        return f.read()


def update_readme_content(content: str, table: str) -> Optional[str]:
    """
    Replace content between markers in README with new table.

    Args:
        content: Original README content
        table: New contributors table

    Returns:
        Updated content or None if markers not found
    """
    if START_MARKER not in content or END_MARKER not in content:
        error(
            f"Could not find markers {START_MARKER} and {END_MARKER} in {README_FILE}"
        )
        error(
            f"Please add these markers to {README_FILE} where you want the contributors table."
        )
        return None

    # Find the marker positions
    start_idx = content.find(START_MARKER)
    end_idx = content.find(END_MARKER)

    if end_idx <= start_idx:
        error("END_MARKER appears before START_MARKER in README.md")
        return None

    # Build new content
    before = content[: start_idx + len(START_MARKER)]
    after = content[end_idx:]

    # Add newlines around the table for proper formatting
    new_content = f"{before}\n{table}\n{after}"

    return new_content


def write_readme_safely(content: str) -> bool:
    """
    Write content to README.md safely using a temporary file.

    Args:
        content: Content to write

    Returns:
        True if successful, False otherwise
    """
    tmp_filename = None
    try:
        # Create a temporary file in the same directory as README
        readme_dir = os.path.dirname(os.path.abspath(README_FILE))

        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=readme_dir,
            delete=False,
            prefix=".readme_tmp_",
            suffix=".md",
        ) as tmp_file:
            tmp_file.write(content)
            tmp_filename = tmp_file.name

        # Atomic replace
        shutil.move(tmp_filename, README_FILE)
        log(f"Successfully updated {README_FILE}")
        return True

    except Exception as e:
        error(f"Failed to write {README_FILE}: {e}")
        # Clean up temp file if it exists
        if tmp_filename and os.path.exists(tmp_filename):
            try:
                os.remove(tmp_filename)
            except Exception:
                pass
        return False


def main() -> int:
    """
    Main entry point.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Generate contributors table for README.md",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 generate_contributors.py
  python3 generate_contributors.py timlinux nixmywindows
  python3 generate_contributors.py --dry-run
  GITHUB_TOKEN=ghp_xxx python3 generate_contributors.py
        """,
    )

    parser.add_argument(
        "owner",
        nargs="?",
        default="timlinux",
        help="Repository owner (default: timlinux)",
    )

    parser.add_argument(
        "repo",
        nargs="?",
        default="nixmywindows",
        help="Repository name (default: nixmywindows)",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated table without modifying README.md",
    )

    args = parser.parse_args()

    log(f"Generating contributors for {args.owner}/{args.repo}")

    # Get GitHub token from environment
    token = os.environ.get("GITHUB_TOKEN")

    # Fetch contributors
    contributors = fetch_contributors(args.owner, args.repo, token)

    if not contributors:
        error("No contributors found")
        return 1

    # Generate table
    table = generate_markdown_table(contributors)

    if args.dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN - Generated contributors table:")
        print("=" * 60)
        print(table)
        print("=" * 60)
        log("Dry run complete - no files were modified")
        return 0

    # Read current README
    readme_content = read_readme()
    if readme_content is None:
        return 1

    # Update content
    new_content = update_readme_content(readme_content, table)
    if new_content is None:
        return 1

    # Check if content actually changed
    if new_content == readme_content:
        log("No changes needed - README.md is already up to date")
        return 0

    # Write the updated content
    if not write_readme_safely(new_content):
        return 1

    log("Contributors table updated successfully!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
