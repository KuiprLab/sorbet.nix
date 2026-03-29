#!/usr/bin/env bash

nixos-rebuild switch --flake "github:KuiprLab/sorbet.nix#sorbet" > /tmp/deploy.log 2>&1
EXIT=$?

# Read the webhook URL from the sops secret
WEBHOOK=$(cat /run/secrets/gh_runner/deploy_webhook)

if [ $EXIT -eq 0 ]; then
  MSG="✅ **sorbet deploy succeeded**"
  rm -f /tmp/deploy.log
else
  MSG="❌ **sorbet deploy FAILED** (exit $EXIT)\n\`\`\`$(tail -20 /tmp/deploy.log)\`\`\`"
  curl -s -X POST "$WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MSG\"}"
fi

