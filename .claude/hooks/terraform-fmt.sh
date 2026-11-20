#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): runs `terraform fmt` on the edited .tf / .tfvars file.
# Never blocks: if terraform is missing or fmt fails, it exits 0 silently.

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  # Fallback without jq: first "file_path" value, JSON-unescaped backslashes (Windows paths)
  file="$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -e 's/^"file_path"[[:space:]]*:[[:space:]]*"//' -e 's/"$//' -e 's/\\\\/\\/g')"
fi

case "$file" in
  *.tf | *.tfvars) ;;
  *) exit 0 ;;
esac

command -v terraform >/dev/null 2>&1 || exit 0
terraform fmt "$file" >/dev/null 2>&1 || true
exit 0
