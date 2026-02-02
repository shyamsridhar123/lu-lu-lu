# Copilot Coding Agent Hooks

This directory contains hooks for extending GitHub Copilot coding agent behavior in the Tatooine Holonet project.

## Overview

Hooks execute custom shell commands at strategic points in an agent's workflow:

| Hook Type | When It Runs | Can Block? |
|-----------|--------------|------------|
| `sessionStart` | Agent session begins/resumes | No |
| `sessionEnd` | Agent session completes | No |
| `userPromptSubmitted` | User submits a prompt | No |
| `preToolUse` | Before any tool executes | **Yes** |
| `postToolUse` | After tool completes | No |
| `errorOccurred` | When an error occurs | No |

## Configuration

The main configuration file is [copilot-hooks.json](copilot-hooks.json).

## Scripts

### Bash Scripts (Linux/macOS)

| Script | Hook Type | Purpose |
|--------|-----------|---------|
| `session-start.sh` | sessionStart | Initialize environment, validate project state, log session |
| `session-end.sh` | sessionEnd | Cleanup resources, archive logs, generate summary |
| `security-check.sh` | preToolUse | **Block dangerous commands**, enforce security policies |
| `audit-tool-use.sh` | preToolUse | Log all tool usage for compliance |
| `log-prompt.sh` | userPromptSubmitted | Log prompts for usage analysis |
| `post-tool-metrics.sh` | postToolUse | Track execution results and metrics |
| `error-handler.sh` | errorOccurred | Categorize and log errors |

### PowerShell Scripts (Windows)

All bash scripts have PowerShell equivalents with the same functionality.

## Security Features

The `security-check.sh` hook blocks:

### Critical Patterns (Always Blocked)
- `rm -rf /` - Destructive filesystem operations
- `mkfs` - Disk formatting
- `dd if=/dev/zero` - Disk overwrite
- Fork bombs
- Remote script execution via wget/curl

### Sensitive Patterns (Flagged in Strict Mode)
- `sudo` / `su -` commands
- SQL injection patterns (`DROP TABLE`, etc.)
- Access to credential files (`.env`, `.ssh/`, etc.)
- Force pushing to git

### Protected Paths
- `.env*` files
- `secrets/` directory
- SSH keys and certificates

## Logs

Logs are written to [logs/](logs/) directory:

| Log File | Content |
|----------|---------|
| `sessions.jsonl` | Session start/end events |
| `prompts.jsonl` | User prompts |
| `audit.jsonl` | Tool usage audit trail |
| `tool-metrics.jsonl` | Execution results |
| `security.jsonl` | Security events |
| `errors.jsonl` | Error events |
| `daily-stats.csv` | Aggregated statistics |

⚠️ **Logs are gitignored** - they may contain sensitive information.

## Setup

### Requirements

- `jq` for JSON processing (bash scripts)
- Bash 4.0+ (Linux/macOS)
- PowerShell 5.0+ (Windows)

### Make Scripts Executable (Linux/macOS)

```bash
chmod +x .github/hooks/scripts/*.sh
```

### Verify Installation

```bash
# Test session start hook
echo '{"timestamp": 1704614400000, "cwd": "/test", "source": "new"}' | .github/hooks/scripts/session-start.sh

# Check log was created
cat .github/hooks/logs/sessions.jsonl
```

## Testing Hooks

### Test Security Check (should allow)

```bash
echo '{"toolName": "read_file", "toolArgs": "{\"path\": \"src/main.py\"}"}' | \
  .github/hooks/scripts/security-check.sh
# No output = allowed
```

### Test Security Check (should block)

```bash
echo '{"toolName": "bash", "toolArgs": "{\"command\": \"rm -rf /\"}"}' | \
  .github/hooks/scripts/security-check.sh
# Output: {"permissionDecision":"deny","permissionDecisionReason":"BLOCKED: ..."}
```

## Customization

### Adding Custom Security Rules

Edit `scripts/security-check.sh` to add patterns:

```bash
# Add to CRITICAL_PATTERNS array
CRITICAL_PATTERNS=(
    ...
    "your_pattern_here"
)
```

### Enabling Alerts

Set environment variable in `copilot-hooks.json`:

```json
{
  "env": {
    "ALERT_ENABLED": "true"
  }
}
```

### Adjusting Timeouts

For slow operations, increase `timeoutSec`:

```json
{
  "type": "command",
  "bash": "./scripts/slow-script.sh",
  "timeoutSec": 120
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_NAME` | tatooine-holonet | Project identifier for logs |
| `LOG_LEVEL` | INFO | Set to DEBUG for verbose output |
| `STRICT_MODE` | true | Enable strict security checks |
| `ALERT_ENABLED` | false | Enable alerting on critical errors |

## Performance

Hooks run synchronously and block agent execution. Best practices:

- Keep execution time under 5 seconds
- Use asynchronous logging (append to files)
- Cache expensive computations
- Set appropriate timeouts

## References

- [About Hooks](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-hooks)
- [Hooks Configuration Reference](https://docs.github.com/en/copilot/reference/hooks-configuration)
- [Using Hooks with Copilot Agents](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/use-hooks)
