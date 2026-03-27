#!/bin/bash
# agent-dev-workflow installer
# Copies skill files to .claude/skills/ in the target project

set -e

TARGET="${1:-.}"  # Default to current directory

echo "Installing agent-dev-workflow to $TARGET/.claude/skills/"

mkdir -p "$TARGET/.claude/skills/dev"
mkdir -p "$TARGET/.claude/skills/dev-tune"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cp "$SCRIPT_DIR/skills/dev/SKILL.md" "$TARGET/.claude/skills/dev/SKILL.md"
cp "$SCRIPT_DIR/skills/dev-tune/SKILL.md" "$TARGET/.claude/skills/dev-tune/SKILL.md"

echo ""
echo "Installed! Next steps:"
echo "1. Copy templates/CLAUDE.md.example content into your CLAUDE.md"
echo "2. Copy templates/AGENTS.md.example as your AGENTS.md"
echo "3. Customize both files for your project's tech stack"
echo "4. Run /dev <your requirement> to start!"
