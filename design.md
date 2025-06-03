# SBOM Collection Script Design

## Requirements Analysis

### Functional Requirements
1. **Input**: Accept a repository owner (organization or user) as a command-line argument
2. **Repository Discovery**: Use GitHub CLI to fetch all repositories for the given owner
3. **SBOM Generation**: Generate SBOM (Software Bill of Materials) for each repository
4. **File Naming**: Save each SBOM as `{repo-name}-YYYY-MM-DD.json` format
5. **Error Handling**: Handle cases where SBOM generation fails or repositories are inaccessible

### Technical Requirements
1. **GitHub CLI**: Utilize `gh` command-line tool for GitHub API interactions
2. **Shell Script**: Bash compatible script for macOS environment
3. **Date Formatting**: Use current date in ISO format (YYYY-MM-DD)
4. **Output Directory**: Save all SBOM files in a structured manner

## Design Approach

### Script Structure
```
gh-sbom-all.sh
├── Input validation (repo owner argument)
├── Repository listing (gh repo list)
├── SBOM generation loop
│   ├── For each repository
│   ├── Generate SBOM (gh sbom)
│   ├── Save with formatted filename
│   └── Error handling
└── Summary report
```

### Key Components

#### 1. Input Validation
- Check if repository owner argument is provided
- Validate that the owner exists on GitHub
- Display usage information if invalid

#### 2. Repository Discovery
- Use `gh repo list OWNER --limit 1000` to get all repositories
- Handle pagination if owner has more than 1000 repos
- Filter out archived/disabled repositories (optional)

#### 3. SBOM Generation
- Use `gh api repos/OWNER/REPO/dependency-graph/sbom` command for each repository
- Handle different repository types (public/private)
- Manage rate limiting and API quotas

#### 4. File Management
- Create output directory if it doesn't exist
- Generate filename: `{repo-name}-$(date +%Y-%m-%d).json`
- Handle filename conflicts and special characters

#### 5. Error Handling
- Repository access denied
- SBOM generation failures
- Network connectivity issues
- Disk space and file permission errors

### GitHub CLI Commands Used
```bash
# List repositories for an owner
gh repo list OWNER --limit 1000 --json name

# Generate SBOM for a repository
gh api repos/OWNER/REPO/dependency-graph/sbom

# Check authentication status
gh auth status
```

### Expected Output Structure
```
sbom-output/
├── repo1-2025-06-04.json
├── repo2-2025-06-04.json
├── repo3-2025-06-04.json
└── sbom-generation-log.txt
```

### Usage Example
```bash
./gh-sbom-all.sh microsoft
./gh-sbom-all.sh octocat
./gh-sbom-all.sh my-org-name
```

## Implementation Considerations

### Performance
- Parallel processing for multiple repositories (with rate limit respect)
- Progress indicators for long-running operations
- Resume capability for interrupted runs

### Security
- Ensure GitHub CLI is authenticated
- Handle private repository access appropriately
- Secure storage of generated SBOMs

### Compatibility
- macOS zsh environment
- GitHub CLI version compatibility
- JSON output format validation

### Logging and Monitoring
- Progress tracking
- Error logging
- Summary statistics (successful/failed generations)
- Execution time tracking

## Next Steps
1. Implement basic script structure
2. Add repository discovery functionality
3. Implement SBOM generation loop
4. Add comprehensive error handling
5. Add logging and progress reporting
6. Test with various repository owners
7. Add documentation and usage examples
