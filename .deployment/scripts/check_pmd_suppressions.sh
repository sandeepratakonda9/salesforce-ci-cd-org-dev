#!/usr/bin/env bash
set -euo pipefail

# PMD suppression gate for Apex during PRs / pushes.
# Fails if unapproved suppression markers are found in non-test Apex files.
#
# Blocks these patterns:
#   - @SuppressWarnings / @SuppressWarnings('PMD')
#   - // NOPMD
#   - // NOSONAR
#   - // PMD   (generic inline)
#
# Allow exceptions by listing exact file paths in:
#   .github/pmd-suppression-allowlist.txt
#
# Notes:
# - Only scans changed Apex files for PRs (base..head). For non-PR runs, scans full repo.
# - Skips files in test/mocks folders and files annotated with @IsTest.

ALLOWED_FILE=".github/pmd-suppression-allowlist.txt"
IGNORE_PATH_REGEX='(^|/)(test|tests|mock|mocks)/'
PATTERN_REGEX='@SuppressWarnings|NOPMD|NOSONAR|//[[:space:]]*PMD'

collect_changed_files() {
  local files
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_EVENT_PATH:-}" && -f "${GITHUB_EVENT_PATH}" ]]; then
    local base_sha head_sha
    base_sha="$(jq -r '.pull_request.base.sha' < "$GITHUB_EVENT_PATH")"
    head_sha="$(jq -r '.pull_request.head.sha' < "$GITHUB_EVENT_PATH")"
    # Restrict to apex-related files under typical Salesforce trees
    files=$(git diff --name-only "$base_sha" "$head_sha" -- 'force-app/**' '*.cls' '*.trigger' '*.apex')
  else
    files=$(git ls-files 'force-app/**' '*.cls' '*.trigger' '*.apex')
  fi
  # Filter to only existing files
  for f in $files; do
    [[ -f "$f" ]] && echo "$f"
  done | sort -u
}

is_allowed() {
  local f="$1"
  [[ -f "$ALLOWED_FILE" ]] && grep -Fxq "$f" "$ALLOWED_FILE"
}

main() {
  local files
  mapfile -t files < <(collect_changed_files)

  if (( ${#files[@]} == 0 )); then
    echo "No Apex files to check; skipping PMD suppression gate!!"
    exit 0
  fi

  echo "Scanning ${#files[@]} Apex file(s) for PMD suppression markers..."

  local violations=()
  for f in "${files[@]}"; do
    # Skip test/mocks by path
    if [[ "$f" =~ $IGNORE_PATH_REGEX ]]; then
      continue
    fi
    # Skip if file contains @IsTest (test classes)
    if grep -q -E '@IsTest' "$f"; then
      continue
    fi
    # Search for suppression patterns line-by-line
    if grep -nE "$PATTERN_REGEX" "$f" >/tmp/_hits 2>/dev/null; then
      if ! is_allowed "$f"; then
        while IFS= read -r line; do
          # Format: lineNumber:content
          violations+=("$f:$line")
        done < /tmp/_hits
      fi
    fi
  done

  if (( ${#violations[@]} > 0 )); then
    echo "❌ PMD suppression markers found (unapproved):"
    printf '%s\n' "${violations[@]}"
    echo ""
    echo "To justify a rare exception, add the file path to $ALLOWED_FILE with a JIRA reference and expiry, and explain in the PR."
    exit 1
  else
    echo "✅ No unapproved PMD suppressions detected."
  fi
}

main "$@"
