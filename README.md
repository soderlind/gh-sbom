# GitHub SBOM Collection Script

A zsh script to generate Software Bill of Materials (SBOM) for all repositories owned by a GitHub user or organization using the GitHub CLI.

## Prerequisites

1. **GitHub CLI (gh)**: Install using Homebrew ([other platforms](https://github.com/cli/cli#installation) are also supported)
   ```bash
   brew install gh
   ```

2. **Authentication**: Login to GitHub CLI
   ```bash
   gh auth login
   ```

3. **jq**: JSON processor, usually pre-installed on macOS ([other platforms](https://jqlang.org/download/) are also supported)
   ```bash
   brew install jq  # if not available
   ```

## Usage

```bash
./gh-sbom-all.sh <repo-owner>
```

### Examples

```bash
# Generate SBOMs for Microsoft's repositories
./gh-sbom-all.sh microsoft

# Generate SBOMs for a specific user
./gh-sbom-all.sh octocat

# Generate SBOMs for your organization
./gh-sbom-all.sh my-org-name

# Run in background with progress monitoring
nohup ./gh-sbom-all.sh my-org-name > debug_run.log 2>&1 &
./monitor_progress.sh  # In a separate terminal
```

## Output

The script creates:

- **Output Directory**: `sbom-output/`
- **SBOM Files**: `{repo-name}-YYYY-MM-DD.json`
- **Log File**: `sbom-generation-log-YYYY-MM-DD.txt`

### Example Output Structure
```
sbom-output/
├── repo1-2025-06-04.json
├── repo2-2025-06-04.json
├── repo3-2025-06-04.json
├── sbom-generation-log-2025-06-04.txt
└── debug_run.log (when running with nohup)
```

## Files Created

| File | Description |
|------|-------------|
| `{repo-name}-YYYY-MM-DD.json` | Individual SBOM files for each repository |
| `sbom-generation-log-YYYY-MM-DD.txt` | Main execution log with timestamps |
| `debug_run.log` | Debug output when running script in background |
| `monitor_progress.sh` | Progress monitoring utility script |

## Features

- ✅ **Input Validation**: Validates repository owner exists
- ✅ **Prerequisites Check**: Verifies GitHub CLI installation and authentication
- ✅ **Repository Discovery**: Fetches all active (non-archived) repositories
- ✅ **SBOM Generation**: Creates SBOM for each repository using `gh sbom`
- ✅ **Error Handling**: Comprehensive error handling and retry logic
- ✅ **Progress Tracking**: Real-time progress indicators and logging
- ✅ **Rate Limiting**: Handles GitHub API rate limits gracefully
- ✅ **Filename Sanitization**: Safe filename generation for all repository names
- ✅ **Summary Report**: Detailed execution summary with statistics
- ✅ **Graceful Interruption**: Handles Ctrl+C with partial summary

## Script Behavior

### Repository Filtering
- Automatically excludes archived repositories
- Only processes accessible repositories

### Error Handling
- **Repository Not Found**: Logs warning and continues
- **Access Denied**: Logs error and continues
- **Rate Limiting**: Waits and retries automatically
- **Network Issues**: Logs error with details
- **Invalid JSON**: Validates SBOM output

### Logging Levels
- 🔵 **INFO**: General information and progress
- 🟢 **SUCCESS**: Successful operations
- 🟡 **WARNING**: Non-critical issues
- 🔴 **ERROR**: Critical errors

## Troubleshooting

### Common Issues

1. **"GitHub CLI is not authenticated"**
   ```bash
   gh auth login
   ```

2. **"Repository owner not found"**
   - Verify the username/organization exists
   - Check spelling and case sensitivity

3. **Rate Limiting**
   - Script automatically handles rate limits
   - For high-volume processing, consider running during off-peak hours

4. **Permission Denied**
   - Some repositories may not be accessible
   - Private repositories require appropriate permissions

### Checking GitHub CLI Status
```bash
# Check authentication
gh auth status

# Check available repositories
gh repo list YOUR-USERNAME --limit 5

# Test SBOM generation
gh api repos/YOUR-USERNAME/YOUR-REPO/dependency-graph/sbom
```

## Monitoring Progress

The script includes a progress monitoring utility to track execution status:

```bash
# Run the monitoring script in a separate terminal
./monitor_progress.sh
```

### Progress Monitoring Features
- Real-time progress updates every 30 seconds
- Shows current repository being processed (e.g., "Processing repository 72/145 (50%)")
- Automatically detects when the main script completes
- Runs independently of the main SBOM generation script

### Manual Progress Checking
```bash
# Check current progress in debug log
tail -5 debug_run.log

# View latest log entries
tail -10 sbom-output/sbom-generation-log-YYYY-MM-DD.txt

# Count completed repositories
ls sbom-output/*.json | wc -l
```

## Performance Considerations

- **Repository Count**: Script handles up to 1000 repositories per owner
- **Rate Limiting**: Built-in delays and retry logic
- **Execution Time**: Varies based on repository count and GitHub API response times
- **Disk Space**: Each SBOM file ranges from a few KB to several MB

## Security Notes

- SBOMs may contain sensitive dependency information
- Store generated files securely
- Review access permissions for private repositories
- Consider data retention policies for SBOM files

## Script Limitations

- Maximum 1000 repositories per owner (GitHub CLI limitation)
- Requires network connectivity throughout execution
- Dependent on GitHub API availability
- Some repositories may not have SBOM data available

## License

This script is provided as-is for educational and operational purposes.
