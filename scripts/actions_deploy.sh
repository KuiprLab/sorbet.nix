#!/usr/bin/env bash

nixos-rebuild switch --flake "github:KuiprLab/sorbet.nix#sorbet" > /tmp/deploy.log 2>&1
EXIT=$?


if [ $EXIT -eq 0 ]; then
  MSG="✅ **sorbet deploy succeeded**"
else
  MSG="❌ **sorbet deploy FAILED** (exit $EXIT)\n\`\`\`$(tail -20 /tmp/deploy.log)\`\`\`"
fi

WEBHOOK=$(cat /run/secrets/deploy_webhook)
curl -s -X POST "$WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"$MSG\"}"
