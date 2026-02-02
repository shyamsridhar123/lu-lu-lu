#!/bin/bash
# Agent and Skill Compliance Validator
# Run this to verify all agents and skills are properly configured

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GITHUB_DIR="$PROJECT_ROOT/.github"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "Agent & Skill Compliance Validator"
echo "=========================================="
echo ""

# Check required agents exist
echo "Checking required agents..."
REQUIRED_AGENTS=(
    "tatooine-orchestrator.agent.md"
    "tatooine-backend.agent.md"
    "tatooine-frontend.agent.md"
    "tatooine-agent-designer.agent.md"
    "tatooine-platform-architect.agent.md"
    "tatooine-devops.agent.md"
    "smolagents-developer.agent.md"
    "openenv-developer.agent.md"
    "microverse-agent.agent.md"
    "microverse-godot.agent.md"
    "microverse-llm.agent.md"
    "microverse-memory.agent.md"
)

for agent in "${REQUIRED_AGENTS[@]}"; do
    if [[ -f "$GITHUB_DIR/agents/$agent" ]]; then
        echo -e "  ${GREEN}✓${NC} $agent"
    else
        echo -e "  ${RED}✗${NC} $agent (MISSING)"
        ((ERRORS++))
    fi
done
echo ""

# Check required skills exist
echo "Checking required skills..."
REQUIRED_SKILLS=(
    "agent-personality-design"
    "azure-ai-foundry"
    "fastapi-backend"
    "microverse-ai-agents"
    "microverse-godot-practices"
    "microverse-llm-integration"
    "microverse-memory-systems"
    "nextjs-frontend"
    "openenv-framework"
    "smolagents-framework"
    "social-platform-design"
)

for skill in "${REQUIRED_SKILLS[@]}"; do
    if [[ -f "$GITHUB_DIR/skills/$skill/AGENTS.md" ]]; then
        echo -e "  ${GREEN}✓${NC} $skill/AGENTS.md"
    else
        echo -e "  ${RED}✗${NC} $skill/AGENTS.md (MISSING)"
        ((ERRORS++))
    fi
done
echo ""

# Check hooks are configured
echo "Checking hook configuration..."
HOOKS_FILE="$GITHUB_DIR/hooks/copilot-hooks.json"
if [[ -f "$HOOKS_FILE" ]]; then
    echo -e "  ${GREEN}✓${NC} copilot-hooks.json exists"
    
    # Validate JSON
    if command -v jq &> /dev/null; then
        if jq empty "$HOOKS_FILE" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} copilot-hooks.json is valid JSON"
            
            # Check required hooks
            REQUIRED_HOOKS=("sessionStart" "sessionEnd" "preToolUse" "postToolUse" "errorOccurred")
            for hook in "${REQUIRED_HOOKS[@]}"; do
                if jq -e ".hooks.$hook" "$HOOKS_FILE" > /dev/null 2>&1; then
                    echo -e "  ${GREEN}✓${NC} Hook: $hook"
                else
                    echo -e "  ${YELLOW}!${NC} Hook: $hook (not configured)"
                    ((WARNINGS++))
                fi
            done
        else
            echo -e "  ${RED}✗${NC} copilot-hooks.json is INVALID JSON"
            ((ERRORS++))
        fi
    else
        echo -e "  ${YELLOW}!${NC} jq not installed, skipping JSON validation"
        ((WARNINGS++))
    fi
else
    echo -e "  ${RED}✗${NC} copilot-hooks.json (MISSING)"
    ((ERRORS++))
fi
echo ""

# Check hook scripts are executable
echo "Checking hook scripts..."
HOOK_SCRIPTS=(
    "session-start.sh"
    "session-end.sh"
    "security-check.sh"
    "audit-tool-use.sh"
    "log-prompt.sh"
    "post-tool-metrics.sh"
    "error-handler.sh"
)

for script in "${HOOK_SCRIPTS[@]}"; do
    SCRIPT_PATH="$GITHUB_DIR/hooks/scripts/$script"
    if [[ -f "$SCRIPT_PATH" ]]; then
        if [[ -x "$SCRIPT_PATH" ]]; then
            echo -e "  ${GREEN}✓${NC} $script (executable)"
        else
            echo -e "  ${YELLOW}!${NC} $script (not executable)"
            ((WARNINGS++))
        fi
    else
        echo -e "  ${RED}✗${NC} $script (MISSING)"
        ((ERRORS++))
    fi
done
echo ""

# Check enforcement documents exist
echo "Checking enforcement documents..."
ENFORCEMENT_DOCS=(
    "$PROJECT_ROOT/AGENTS.md"
    "$GITHUB_DIR/copilot-instructions.md"
)

for doc in "${ENFORCEMENT_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo -e "  ${GREEN}✓${NC} $(basename "$doc")"
    else
        echo -e "  ${RED}✗${NC} $(basename "$doc") (MISSING)"
        ((ERRORS++))
    fi
done
echo ""

# Check project docs exist
echo "Checking project documentation..."
PROJECT_DOCS=(
    "$PROJECT_ROOT/PLATFORM_PLAN.md"
    "$PROJECT_ROOT/SIMPLIFIED_ARCHITECTURE.md"
    "$PROJECT_ROOT/POC_LIVE_AGENTS.md"
)

for doc in "${PROJECT_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo -e "  ${GREEN}✓${NC} $(basename "$doc")"
    else
        echo -e "  ${YELLOW}!${NC} $(basename "$doc") (not found)"
        ((WARNINGS++))
    fi
done
echo ""

# Validate skill content has required sections
echo "Validating skill content..."
for skill in "${REQUIRED_SKILLS[@]}"; do
    SKILL_FILE="$GITHUB_DIR/skills/$skill/AGENTS.md"
    if [[ -f "$SKILL_FILE" ]]; then
        # Check for required sections
        if grep -q "## " "$SKILL_FILE"; then
            if grep -qi "best practice\|pattern\|example\|structure" "$SKILL_FILE"; then
                echo -e "  ${GREEN}✓${NC} $skill has implementation patterns"
            else
                echo -e "  ${YELLOW}!${NC} $skill may be missing implementation patterns"
                ((WARNINGS++))
            fi
        else
            echo -e "  ${YELLOW}!${NC} $skill has no section headers"
            ((WARNINGS++))
        fi
    fi
done
echo ""

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}Failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    exit 1
fi
