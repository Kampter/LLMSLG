#!/usr/bin/env bash
#
# PreToolUse hook (Bash matcher): block commands that look like they're
# attempting to read/write secrets, exfiltrate the env, or run a piped
# installer from the internet.
#
# Outputs JSON on stdout to block; otherwise exits 0 to allow.
# Spec: https://code.claude.com/docs/en/hooks (PreToolUse, Bash matcher)
set -uo pipefail

payload="$(cat || true)"

# Extract the command string. Defensive.
cmd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  cmd="$(printf '%s' "$payload" | jq -r '
    .tool_input.command
    // .toolInput.command
    // empty
  ' 2>/dev/null || true)"
fi
[ -z "$cmd" ] && cmd="${CLAUDE_TOOL_INPUT:-}"

# No command, nothing to check.
[ -z "$cmd" ] && exit 0

deny() {
  local reason="$1"
  # Block via the documented JSON shape.
  printf '{"decision":"block","reason":%s}\n' \
    "$(printf '%s' "$reason" | jq -Rs . 2>/dev/null || printf '"blocked"')"
  exit 0
}

# Patterns that should never run inside this repo.
case "$cmd" in
  *"curl "*"| sh"*|*"curl "*"| bash"*|*"wget "*"| sh"*|*"wget "*"| bash"*)
    deny "Refusing to pipe a remote script into a shell. Download, inspect, then run." ;;
  *"sudo "*)
    deny "sudo is not allowed from inside Claude Code in this repo." ;;
  *"rm -rf /"|*"rm -rf /*"|*"rm -rf ~"|*"rm -rf ~/"*)
    deny "Destructive filesystem command rejected." ;;
  *"git push --force"*|*"git push -f "*)
    deny "Force-push is denied. Use a regular push or open a PR." ;;
  *"git reset --hard"*)
    deny "git reset --hard is denied; investigate state before discarding." ;;
esac

# Heuristic: writing/reading a real .env file via shell.
# Token-level detection: split the command into shell tokens and check each
# one. A token is a "real dotenv" if it ends with `.env` or `.env.<suffix>`
# where the suffix is NOT in {example, sample, template}. This blocks
# bypasses like `cat .env.example .env` or `cp .env .env.example.bak` that
# the previous whole-string allowlist let through.
real_dotenv=$(printf '%s' "$cmd" | awk '
BEGIN { real = 0 }
{
  gsub(/[;|&<>]/, " ");
  n = split($0, tok, /[ \t]+/);
  for (i = 1; i <= n; i++) {
    t = tok[i];
    gsub(/["\047]/, "", t);
    if (match(t, /(^|\/)\.env(\.[A-Za-z0-9_-]+)?$/)) {
      tail = substr(t, RSTART, RLENGTH);
      sub(/^\//, "", tail);
      if (tail == ".env" ||
          (tail != ".env.example" && tail != ".env.sample" && tail != ".env.template")) {
        real = 1;
        exit;
      }
    }
  }
}
END { if (real) print 1 }')

if [ -n "$real_dotenv" ] \
  && printf '%s' "$cmd" \
  | grep -E -q '\b(cat|less|more|head|tail|bat|xxd|od|hexdump|grep|awk|sed|cp|mv|diff|rsync)\b|>>?[[:space:]]'; then
  deny "Refusing to read/write a real .env via shell (.env.example / .env.sample / .env.template are allowed). Use a real secrets tool for live values."
fi

# Heuristic: looks like a token literal landing in a command.
# Anthropic / OpenAI / GitHub PAT / Slack / AWS keys.
if printf '%s' "$cmd" | grep -E -q '(sk-[A-Za-z0-9_-]{16,}|sk-ant-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|xox[bspar]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})'; then
  deny "The command contains what looks like a real API key. Refusing to execute. If it's a placeholder, paraphrase it."
fi

exit 0
