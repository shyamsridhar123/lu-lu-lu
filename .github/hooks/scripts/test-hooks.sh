#!/bin/bash
# =============================================================================
# Copilot Hooks Test Script
# =============================================================================
# Tests all hooks to verify they work correctly.
# Run from repository root: bash .github/hooks/scripts/test-hooks.sh
# =============================================================================

set -e

HOOKS_DIR=".github/hooks"
SCRIPTS_DIR="$HOOKS_DIR/scripts"
LOGS_DIR="$HOOKS_DIR/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track test results
PASSED=0
FAILED=0

# Test helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

echo "=============================================="
echo "Copilot Hooks Test Suite"
echo "=============================================="
echo ""

# Check prerequisites
info "Checking prerequisites..."

if ! command -v jq &> /dev/null; then
    fail "jq is not installed (required for JSON processing)"
    echo "Install with: sudo apt install jq (Ubuntu) or brew install jq (macOS)"
    exit 1
else
    pass "jq is installed"
fi

# Check scripts exist and are executable
info "Checking scripts..."

SCRIPTS=(
    "session-start.sh"
    "session-end.sh"
    "security-check.sh"
    "audit-tool-use.sh"
    "log-prompt.sh"
    "post-tool-metrics.sh"
    "error-handler.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -x "$SCRIPTS_DIR/$script" ]; then
        pass "$script exists and is executable"
    else
        fail "$script is missing or not executable"
    fi
done

echo ""
info "Testing sessionStart hook..."

# Test session start
SESSION_START_INPUT='{"timestamp": 1704614400000, "cwd": "/test/project", "source": "new", "initialPrompt": "Test prompt"}'
echo "$SESSION_START_INPUT" | "$SCRIPTS_DIR/session-start.sh"

if [ -f "$LOGS_DIR/sessions.jsonl" ]; then
    if grep -q '"event": "session_start"' "$LOGS_DIR/sessions.jsonl" 2>/dev/null || \
       grep -q '"event":"session_start"' "$LOGS_DIR/sessions.jsonl" 2>/dev/null; then
        pass "sessionStart hook logged correctly"
    else
        fail "sessionStart hook did not log expected event"
    fi
else
    fail "sessions.jsonl was not created"
fi

echo ""
info "Testing userPromptSubmitted hook..."

# Test prompt logging
PROMPT_INPUT='{"timestamp": 1704614500000, "cwd": "/test/project", "prompt": "Fix the authentication bug in the login component"}'
echo "$PROMPT_INPUT" | "$SCRIPTS_DIR/log-prompt.sh"

if [ -f "$LOGS_DIR/prompts.jsonl" ]; then
    pass "userPromptSubmitted hook logged correctly"
else
    fail "prompts.jsonl was not created"
fi

echo ""
info "Testing preToolUse hooks..."

# Test security check - should allow safe command
SAFE_TOOL_INPUT='{"timestamp": 1704614600000, "cwd": "/test", "toolName": "read_file", "toolArgs": "{\"path\": \"src/main.py\"}"}'
RESULT=$(echo "$SAFE_TOOL_INPUT" | "$SCRIPTS_DIR/security-check.sh")

if [ -z "$RESULT" ]; then
    pass "Security check allows safe read operation"
else
    fail "Security check unexpectedly blocked safe operation"
fi

# Test security check - should block dangerous command
DANGEROUS_TOOL_INPUT='{"timestamp": 1704614600000, "cwd": "/test", "toolName": "bash", "toolArgs": "{\"command\": \"rm -rf /\"}"}'
RESULT=$(echo "$DANGEROUS_TOOL_INPUT" | "$SCRIPTS_DIR/security-check.sh")

if echo "$RESULT" | grep -q "deny"; then
    pass "Security check blocks dangerous rm -rf /"
else
    fail "Security check failed to block dangerous command"
fi

# Test audit logging
AUDIT_INPUT='{"timestamp": 1704614600000, "cwd": "/test", "toolName": "edit", "toolArgs": "{\"path\": \"src/file.py\"}"}'
echo "$AUDIT_INPUT" | "$SCRIPTS_DIR/audit-tool-use.sh"

if [ -f "$LOGS_DIR/audit.jsonl" ]; then
    pass "Audit tool use hook logged correctly"
else
    fail "audit.jsonl was not created"
fi

echo ""
info "Testing postToolUse hook..."

# Test post-tool metrics
POST_TOOL_INPUT='{"timestamp": 1704614700000, "cwd": "/test", "toolName": "bash", "toolArgs": "{\"command\": \"npm test\"}", "toolResult": {"resultType": "success", "textResultForLlm": "All tests passed"}}'
echo "$POST_TOOL_INPUT" | "$SCRIPTS_DIR/post-tool-metrics.sh"

if [ -f "$LOGS_DIR/tool-metrics.jsonl" ]; then
    pass "postToolUse hook logged correctly"
else
    fail "tool-metrics.jsonl was not created"
fi

echo ""
info "Testing errorOccurred hook..."

# Test error handler
ERROR_INPUT='{"timestamp": 1704614800000, "cwd": "/test", "error": {"message": "Connection timeout", "name": "TimeoutError", "stack": "TimeoutError: Connection timeout at..."}}'
echo "$ERROR_INPUT" | "$SCRIPTS_DIR/error-handler.sh"

if [ -f "$LOGS_DIR/errors.jsonl" ]; then
    pass "errorOccurred hook logged correctly"
else
    fail "errors.jsonl was not created"
fi

echo ""
info "Testing sessionEnd hook..."

# Test session end
SESSION_END_INPUT='{"timestamp": 1704618000000, "cwd": "/test/project", "reason": "complete"}'
echo "$SESSION_END_INPUT" | "$SCRIPTS_DIR/session-end.sh"

if grep -q '"event": "session_end"' "$LOGS_DIR/sessions.jsonl" 2>/dev/null || \
   grep -q '"event":"session_end"' "$LOGS_DIR/sessions.jsonl" 2>/dev/null; then
    pass "sessionEnd hook logged correctly"
else
    fail "sessionEnd hook did not log expected event"
fi

echo ""
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
