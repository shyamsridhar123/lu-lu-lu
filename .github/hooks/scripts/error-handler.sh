#!/bin/bash
# =============================================================================
# Tatooine Holonet - Error Handler Hook (errorOccurred)
# =============================================================================
# Handles errors that occur during agent execution.
# Logs errors, categorizes them, and can send alerts for critical issues.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
ERROR_LOG="${LOG_DIR}/errors.jsonl"
STATE_FILE="${LOG_DIR}/.session-state"
ALERT_ENABLED="${ALERT_ENABLED:-false}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Parse error details
ERROR_MESSAGE=$(echo "$INPUT" | jq -r '.error.message // "Unknown error"')
ERROR_NAME=$(echo "$INPUT" | jq -r '.error.name // "Error"')
ERROR_STACK=$(echo "$INPUT" | jq -r '.error.stack // empty' | head -c 1000)

# Get session ID from state file
SESSION_ID="unknown"
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(cat "$STATE_FILE")
fi

# Convert timestamp to human-readable
if [ -n "$TIMESTAMP" ]; then
    TIMESTAMP_SEC=$((TIMESTAMP / 1000))
    HUMAN_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
else
    TIMESTAMP=$(date +%s%3N)
    HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
fi

# =============================================================================
# Categorize Error
# =============================================================================

categorize_error() {
    local name="$1"
    local message="$2"
    
    local category="unknown"
    local severity="error"
    
    # By error name
    case "$name" in
        "TimeoutError")
            category="timeout"
            severity="warning"
            ;;
        "NetworkError"|"FetchError"|"ConnectionError")
            category="network"
            severity="warning"
            ;;
        "AuthenticationError"|"AuthorizationError")
            category="auth"
            severity="error"
            ;;
        "ValidationError"|"ParseError"|"SyntaxError")
            category="validation"
            severity="warning"
            ;;
        "RateLimitError")
            category="rate_limit"
            severity="warning"
            ;;
        "OutOfMemoryError"|"MemoryError")
            category="resources"
            severity="critical"
            ;;
        *)
            # Try to categorize by message content
            if echo "$message" | grep -qiE "timeout|timed out"; then
                category="timeout"
                severity="warning"
            elif echo "$message" | grep -qiE "network|connection|socket|dns"; then
                category="network"
                severity="warning"
            elif echo "$message" | grep -qiE "permission|access denied|unauthorized|forbidden"; then
                category="auth"
                severity="error"
            elif echo "$message" | grep -qiE "not found|missing|undefined"; then
                category="not_found"
                severity="warning"
            elif echo "$message" | grep -qiE "rate limit|too many requests|429"; then
                category="rate_limit"
                severity="warning"
            elif echo "$message" | grep -qiE "memory|out of|exceeded"; then
                category="resources"
                severity="critical"
            elif echo "$message" | grep -qiE "azure|openai|ai service"; then
                category="ai_service"
                severity="error"
            else
                category="general"
                severity="error"
            fi
            ;;
    esac
    
    echo "$category|$severity"
}

CATEGORIZATION=$(categorize_error "$ERROR_NAME" "$ERROR_MESSAGE")
CATEGORY=$(echo "$CATEGORIZATION" | cut -d'|' -f1)
SEVERITY=$(echo "$CATEGORIZATION" | cut -d'|' -f2)

# =============================================================================
# Check for Known Patterns and Provide Hints
# =============================================================================

get_resolution_hint() {
    local category="$1"
    local message="$2"
    
    case "$category" in
        "timeout")
            echo "Consider increasing timeout or breaking task into smaller steps"
            ;;
        "network")
            echo "Check network connectivity; may need to retry"
            ;;
        "auth")
            echo "Verify API keys and credentials in .env file"
            ;;
        "rate_limit")
            echo "Implement backoff; wait before retrying"
            ;;
        "resources")
            echo "Reduce batch size or complexity of operation"
            ;;
        "ai_service")
            echo "Check Azure AI Foundry deployment status and quotas"
            ;;
        "not_found")
            echo "Verify file paths and resource existence"
            ;;
        *)
            echo ""
            ;;
    esac
}

HINT=$(get_resolution_hint "$CATEGORY" "$ERROR_MESSAGE")

# =============================================================================
# Write Error Log Entry
# =============================================================================

jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg error_name "$ERROR_NAME" \
    --arg error_message "$ERROR_MESSAGE" \
    --arg error_stack "$ERROR_STACK" \
    --arg category "$CATEGORY" \
    --arg severity "$SEVERITY" \
    --arg hint "$HINT" \
    --arg cwd "$CWD" \
    --arg user "${USER:-unknown}" \
    '{
        event: "error_occurred",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        error: {
            name: $error_name,
            message: $error_message,
            stack: (if $error_stack == "" then null else $error_stack end)
        },
        category: $category,
        severity: $severity,
        resolution_hint: (if $hint == "" then null else $hint end),
        cwd: $cwd,
        user: $user
    }' >> "$ERROR_LOG"

# =============================================================================
# Track Error Frequency
# =============================================================================

ERROR_TRACKER="${LOG_DIR}/.error-tracker"
HOUR=$(date "+%Y-%m-%d-%H")

# Count errors in current hour
if [ -f "$ERROR_TRACKER" ]; then
    TRACKED_HOUR=$(head -1 "$ERROR_TRACKER")
    if [ "$TRACKED_HOUR" = "$HOUR" ]; then
        ERROR_COUNT=$(tail -1 "$ERROR_TRACKER")
        ERROR_COUNT=$((ERROR_COUNT + 1))
    else
        ERROR_COUNT=1
    fi
else
    ERROR_COUNT=1
fi

# Save tracker
printf "%s\n%d" "$HOUR" "$ERROR_COUNT" > "$ERROR_TRACKER"

# =============================================================================
# Alert on Critical Errors or High Frequency
# =============================================================================

should_alert=false

if [ "$SEVERITY" = "critical" ]; then
    should_alert=true
fi

if [ "$ERROR_COUNT" -ge 10 ]; then
    should_alert=true
fi

if [ "$should_alert" = "true" ] && [ "$ALERT_ENABLED" = "true" ]; then
    # Log alert (in production, this could send to Slack, email, etc.)
    jq -n -c \
        --arg session_id "$SESSION_ID" \
        --arg timestamp "$TIMESTAMP" \
        --arg error_name "$ERROR_NAME" \
        --arg category "$CATEGORY" \
        --arg severity "$SEVERITY" \
        --argjson error_count "$ERROR_COUNT" \
        '{
            event: "error_alert",
            session_id: $session_id,
            timestamp: ($timestamp | tonumber),
            error_name: $error_name,
            category: $category,
            severity: $severity,
            errors_this_hour: $error_count,
            alert_reason: (if $severity == "critical" then "critical_error" else "high_frequency" end)
        }' >> "$ERROR_LOG"
    
    # Example: Send to webhook (uncomment and configure as needed)
    # WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
    # if [ -n "$WEBHOOK_URL" ]; then
    #     curl -X POST "$WEBHOOK_URL" \
    #         -H 'Content-Type: application/json' \
    #         -d "{\"text\":\"[Tatooine] Error Alert: $ERROR_NAME ($CATEGORY) - $ERROR_MESSAGE\"}" \
    #         --silent --output /dev/null || true
    # fi
fi

exit 0
