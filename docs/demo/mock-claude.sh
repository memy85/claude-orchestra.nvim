#!/usr/bin/env bash
# Stand-in for the `claude` CLI used by docs/demo/grid.tape.
# Picks one of three fake transcripts at random so the three demo
# tiles look distinct from each other.

set -u

CYAN=$'\033[1;36m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
MAGENTA=$'\033[1;35m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

header() {
  clear
  printf "%s●%s %sClaude Code (demo)%s\n" "$CYAN" "$RESET" "$DIM" "$RESET"
  printf "  Session ready.\n\n"
}

prompt_loop() {
  while IFS= read -r -p "$(printf '%s> %s' "$GREEN" "$RESET")" _line; do
    :
  done
}

variant_refactor() {
  header
  printf "%s>%s help me refactor the auth middleware\n\n" "$GREEN" "$RESET"
  sleep 0.2
  printf "%s●%s I'll take a look:\n\n" "$CYAN" "$RESET"
  printf "   %s• Reading lua/auth/middleware.lua%s\n" "$DIM" "$RESET"
  printf "   %s• Reading tests/auth_spec.lua%s\n\n" "$DIM" "$RESET"
  printf "   Three things stand out:\n"
  printf "   %s1.%s token validation is synchronous\n" "$YELLOW" "$RESET"
  printf "   %s2.%s the user record is re-fetched per request\n" "$YELLOW" "$RESET"
  printf "   %s3.%s no cache layer in front\n\n" "$YELLOW" "$RESET"
  prompt_loop
}

variant_flaky_test() {
  header
  printf "%s>%s why is %sTestStreamingTimeout%s flaky?\n\n" "$GREEN" "$RESET" "$BOLD" "$RESET"
  sleep 0.2
  printf "%s●%s Tracing the timing:\n\n" "$CYAN" "$RESET"
  printf "   %s• Reading server/stream_test.go%s\n" "$DIM" "$RESET"
  printf "   %s• Running with -race -count=20%s\n\n" "$DIM" "$RESET"
  printf "   The test races a %s100ms%s sleep against a real network\n" "$MAGENTA" "$RESET"
  printf "   dial. On a loaded CI runner the dial can exceed the\n"
  printf "   budget %s~1 in 8 runs%s. Fix is a fake clock.\n\n" "$YELLOW" "$RESET"
  prompt_loop
}

variant_rate_limit() {
  header
  printf "%s>%s add a token-bucket rate limiter to %s/v1/chat%s\n\n" "$GREEN" "$RESET" "$BOLD" "$RESET"
  sleep 0.2
  printf "%s●%s Plan:\n\n" "$CYAN" "$RESET"
  printf "   %s1.%s new package %sinternal/ratelimit%s\n" "$YELLOW" "$RESET" "$BOLD" "$RESET"
  printf "   %s2.%s middleware wraps the chat handler\n" "$YELLOW" "$RESET"
  printf "   %s3.%s 60 req/min/user, burst 10, Redis-backed\n\n" "$YELLOW" "$RESET"
  printf "   I'll start with the package and a unit test.\n"
  printf "   Shall I proceed? %s(y/n)%s\n\n" "$DIM" "$RESET"
  prompt_loop
}

VARIANTS=(variant_refactor variant_flaky_test variant_rate_limit)
COUNTER_FILE="${CO_DEMO_COUNTER:-/tmp/co-demo-counter}"
idx=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
printf '%s' "$(( (idx + 1) % ${#VARIANTS[@]} ))" > "$COUNTER_FILE"
"${VARIANTS[idx % ${#VARIANTS[@]}]}"
