#!/bin/bash
cd "$(dirname "$0")"
git add -A
git pull --rebase
git commit -m "deploy $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || echo "Nothing new to commit."
git push
echo ""
echo "Done! Cloudflare will deploy in ~30 seconds."
echo "Press any key to close."
read -n 1
