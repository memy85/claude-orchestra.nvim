#!/usr/bin/env bash
# Writes fake Claude transcripts for the resume-picker screenshot.
# Usage: fake-history.sh <fake-home> <cwd>
# The picker reads <fake-home>/.claude/projects/<encoded-cwd>/*.jsonl.

set -eu

home="$1"
cwd="$2"
dir="$home/.claude/projects/$(printf '%s' "$cwd" | sed 's/[^A-Za-z0-9]/-/g')"
rm -rf "$home/.claude"
mkdir -p "$dir"

# id | minutes ago | /rename title (or empty) | first user message | assistant reply
while IFS='|' read -r id ago title first reply; do
  f="$dir/$id.jsonl"
  {
    printf '{"type":"user","cwd":"%s","message":{"role":"user","content":"%s"}}\n' "$cwd" "$first"
    printf '{"type":"assistant","cwd":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$cwd" "$reply"
    if [ -n "$title" ]; then
      printf '{"type":"custom-title","customTitle":"%s","sessionId":"%s"}\n' "$title" "$id"
    fi
  } > "$f"
  touch -d "-$ago minutes" "$f"
done <<'ROWS'
1b0d6c3e-0001-4000-8000-000000000001|12|auth-refactor|help me refactor the auth middleware|Three things stand out: token validation is synchronous, the user record is re-fetched per request, and there is no cache layer in front.
1b0d6c3e-0002-4000-8000-000000000002|95||why is TestStreamingTimeout flaky?|The test races a 100ms sleep against a real network dial. On a loaded CI runner the dial can exceed the budget about 1 in 8 runs. Fix is a fake clock.
1b0d6c3e-0003-4000-8000-000000000003|240|rate-limiter|add a token-bucket rate limiter to /v1/chat|Plan: new package internal/ratelimit, middleware wraps the chat handler, 60 req/min/user with burst 10.
1b0d6c3e-0004-4000-8000-000000000004|1500||write a migration that backfills user.created_at|I will add a batched migration that reads from the audit log and fills missing timestamps 1000 rows at a time.
1b0d6c3e-0005-4000-8000-000000000005|3000|release-notes|draft release notes for v0.3.0|Here is a first draft grouped into Features and Fixes.
ROWS
