#!/usr/bin/env bash
# PreToolUse hook (Bash): blocks `git commit` / `git push` when versioned content looks sensitive.
#   commit -> scans the index and the working tree (what can end up in the commit)
#   push   -> scans every commit not yet on a remote (the whole history gets published)
#
# Project-specific terms (company names, internal domains, ...) go in
# .claude/sensitive-patterns.local: one extended regex per line, case-insensitive.
# That file is git-ignored, so the terms themselves are never published.
#
# Exit 2 blocks the command and shows the findings to Claude. Anything else lets it run.

input="$(cat)"

git_cmd='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
mode=""
printf '%s' "$input" | grep -Eq "${git_cmd}commit" && mode="commit"
printf '%s' "$input" | grep -Eq "${git_cmd}push" && mode="${mode:+$mode+}push"
[ -n "$mode" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

patterns=(
  -e 'arn:aws[a-z-]*:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:'  # ARN with a real account ID
  -e '[0-9]{12}\.dkr\.ecr\.'                             # ECR registry host with account ID
  -e '(AKIA|ASIA)[0-9A-Z]{16}'                           # AWS access key ID
  -e '-----BEGIN [A-Z ]*PRIVATE KEY-----'                # Private key
  -e 'dt0[a-z][0-9]{2}\.[A-Z0-9]{24}'                    # Dynatrace token
  -e '(vpc|subnet|sg)-[0-9a-f]{8}([0-9a-f]{9})?'         # AWS VPC / subnet / security group ID
  -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'    # E-mail address
)

# Matches that are fine to publish. Each finding line ends with the matched text.
# AWS ID placeholders use "x" (vpc-xxxxxxxxxxxxxxxxx), so any hexadecimal ID is treated as real.
allowed='@example\.(com|org|net)$|@users\.noreply\.github\.com$|:git@github\.com$'

local_patterns=".claude/sensitive-patterns.local"

scan() { # $@: what to scan (--cached, --untracked or a revision)
  git grep -I -n -o -E "${patterns[@]}" "$@" -- . 2>/dev/null
  if [ -s "$local_patterns" ]; then
    git grep -I -n -o -i -E -f "$local_patterns" "$@" -- . 2>/dev/null
  fi
}

findings=""
case "$mode" in
  *commit*) findings+="$(scan --cached; scan --untracked)"$'\n' ;;
esac
case "$mode" in
  *push*)
    for rev in $(git rev-list HEAD --not --remotes 2>/dev/null); do
      findings+="$(scan "$rev")"$'\n'
    done
    ;;
esac

findings="$(printf '%s' "$findings" | grep -v '^$' | grep -Ev "$allowed" | sort -u)"
[ -z "$findings" ] && exit 0

{
  echo "Blocked ($mode): possible sensitive data in versioned content:"
  printf '%s\n' "$findings" | head -n 30
  echo "Replace real values with placeholders (see CLAUDE.md)."
  echo "False positive? Adjust the patterns in .claude/hooks/check-sensitive.sh."
} >&2
exit 2
