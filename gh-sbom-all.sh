#!/bin/zsh

# SBOM Collection Script for GitHub Repositories
# Usage: ./gh-sbom-all.sh <repo-owner>
# Generates SBOM for all repositories owned by the specified GitHub user/organization

set -uo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
REPO_OWNER=""
OUTPUT_DIR="sbom-output"
LOG_FILE=""
CURRENT_DATE=""
TOTAL_REPOS=0
SUCCESSFUL_SBOMS=0
FAILED_SBOMS=0
SKIPPED_SBOMS=0
PROCESSED_REPOS=0
START_TIME=""

# Logging functions
log_info() {
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 <repo-owner>

Generate SBOM (Software Bill of Materials) for all repositories owned by a GitHub user or organization.

Arguments:
  repo-owner    GitHub username or organization name

Examples:
  $0 microsoft
  $0 octocat
  $0 my-org-name

Requirements:
  - GitHub CLI (gh) must be installed and authenticated
  - Sufficient permissions to access repositories
  - Network connectivity to GitHub

Output:
  - SBOMs saved as: {repo-name}-YYYY-MM-DD.json
  - Log file: sbom-generation-log-YYYY-MM-DD.txt
EOF
}

# Validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Please install it first:"
        log_error "  brew install gh"
        exit 1
    fi
    
    # Check if gh CLI is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Please run:"
        log_error "  gh auth login"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Validate input arguments
validate_input() {
    if [[ $# -eq 0 ]]; then
        log_error "Repository owner argument is required"
        show_usage
        exit 1
    fi
    
    if [[ $# -gt 1 ]]; then
        log_error "Too many arguments provided"
        show_usage
        exit 1
    fi
    
    REPO_OWNER="$1"
    
    # Basic validation of repo owner format
    if [[ ! "$REPO_OWNER" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        log_error "Invalid repository owner format: $REPO_OWNER"
        exit 1
    fi
    
    log_info "Repository owner: $REPO_OWNER"
}

# Validate that the repository owner exists
validate_repo_owner() {
    log_info "Validating repository owner exists..."
    
    if ! gh api "/users/$REPO_OWNER" &> /dev/null; then
        log_error "Repository owner '$REPO_OWNER' not found on GitHub"
        exit 1
    fi
    
    log_success "Repository owner '$REPO_OWNER' validated"
}

# Setup output directory and logging
setup_environment() {
    CURRENT_DATE=$(date +%Y-%m-%d)
    LOG_FILE="$OUTPUT_DIR/sbom-generation-log-$CURRENT_DATE.txt"
    START_TIME=$(date +%s)
    
    # Create output directory
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "Created output directory: $OUTPUT_DIR"
    fi
    
    # Initialize log file
    echo "SBOM Generation Log - $(date)" > "$LOG_FILE"
    echo "Repository Owner: $REPO_OWNER" >> "$LOG_FILE"
    echo "=================================" >> "$LOG_FILE"
    
    log_info "Environment setup complete"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Log file: $LOG_FILE"
}

# Get list of repositories for the owner
get_repositories() {
    log_info "Fetching repositories for '$REPO_OWNER'..."
    
    local repos_json
    local temp_file=$(mktemp)
    
    # Get repositories with error handling
    if ! repos_json=$(gh repo list "$REPO_OWNER" --limit 1000 --json name,isArchived 2>"$temp_file"); then
        log_error "Failed to fetch repositories:"
        cat "$temp_file" | tee -a "$LOG_FILE"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
    
    # Filter out archived repositories
    local active_repos
    active_repos=$(echo "$repos_json" | jq -r '.[] | select(.isArchived == false) | .name')
    
    if [[ -z "$active_repos" ]]; then
        log_warning "No active repositories found for '$REPO_OWNER'"
        exit 0
    fi
    
    # Convert to array
    repos_array=()
    while IFS= read -r repo; do
        [[ -n "$repo" ]] && repos_array+=("$repo")
    done <<< "$active_repos"
    
    TOTAL_REPOS=${#repos_array[@]}
    log_info "Found $TOTAL_REPOS active repositories"
}

# Sanitize filename by removing/replacing problematic characters
sanitize_filename() {
    local filename="$1"
    # Replace problematic characters with underscores
    echo "$filename" | tr '/' '_' | tr ' ' '_' | tr '<>:"|?*' '_'
}

# Generate SBOM for a single repository
generate_repo_sbom() {
    local repo_name="$1"
    local repo_full_name="$REPO_OWNER/$repo_name"
    local sanitized_name=$(sanitize_filename "$repo_name")
    local output_file="$OUTPUT_DIR/${sanitized_name}-${CURRENT_DATE}.json"
    
    ((PROCESSED_REPOS++))
    log_info "Processing repository: $repo_name ($PROCESSED_REPOS/$TOTAL_REPOS)"
    
    # Check if SBOM file already exists
    if [[ -f "$output_file" ]]; then
        log_warning "SBOM file already exists: $output_file (skipping)"
        ((SKIPPED_SBOMS++))
        return 0
    fi
    
    # Generate SBOM using GitHub API with error handling
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    if gh api "repos/$repo_full_name/dependency-graph/sbom" > "$temp_file" 2>"$error_file"; then
        # Validate JSON output
        if jq . "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$output_file"
            log_success "Generated SBOM: $output_file"
            ((SUCCESSFUL_SBOMS++))
        else
            log_error "Invalid JSON output for $repo_name"
            cat "$error_file" | tee -a "$LOG_FILE"
            ((FAILED_SBOMS++))
        fi
    else
        local error_msg=$(cat "$error_file")
        if [[ "$error_msg" == *"not found"* ]] || [[ "$error_msg" == *"404"* ]]; then
            log_warning "Repository not accessible or SBOM not available: $repo_name"
        elif [[ "$error_msg" == *"rate limit"* ]] || [[ "$error_msg" == *"403"* ]]; then
            log_warning "Rate limit reached. Waiting 60 seconds..."
            sleep 60
            # Retry once
            if gh api "repos/$repo_full_name/dependency-graph/sbom" > "$temp_file" 2>"$error_file"; then
                mv "$temp_file" "$output_file"
                log_success "Generated SBOM (retry): $output_file"
                ((SUCCESSFUL_SBOMS++))
            else
                log_error "Failed to generate SBOM for $repo_name (after retry)"
                cat "$error_file" | tee -a "$LOG_FILE"
                ((FAILED_SBOMS++))
            fi
        else
            log_error "Failed to generate SBOM for $repo_name:"
            echo "$error_msg" | tee -a "$LOG_FILE"
            ((FAILED_SBOMS++))
        fi
    fi
    
    # Cleanup temporary files
    rm -f "$temp_file" "$error_file"
}

# Process all repositories
process_repositories() {
    log_info "Starting SBOM generation for $TOTAL_REPOS repositories..."
    
    local repo_count=0
    for repo in "${repos_array[@]}"; do
        ((repo_count++))
        log_info "DEBUG: About to process repo #$repo_count: $repo"
        
        if ! generate_repo_sbom "$repo"; then
            log_error "Failed to process repository: $repo"
        fi
        
        log_info "DEBUG: Completed processing repo #$repo_count: $repo"
        
        # Add a small delay to be respectful to GitHub's API
        sleep 1
    done
    
    log_info "DEBUG: Finished processing all repositories"
}

# Generate summary report
generate_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    echo ""
    log_info "================ SUMMARY ================"
    log_info "Repository Owner: $REPO_OWNER"
    log_info "Total Repositories: $TOTAL_REPOS"
    log_info "Processed Repositories: $PROCESSED_REPOS"
    log_info "Successful SBOMs: $SUCCESSFUL_SBOMS"
    log_info "Failed SBOMs: $FAILED_SBOMS"
    log_info "Skipped SBOMs: $SKIPPED_SBOMS"
    log_info "Execution Time: $duration_formatted"
    log_info "Output Directory: $OUTPUT_DIR"
    log_info "Log File: $LOG_FILE"
    log_info "========================================"
    
    # Write summary to log file
    {
        echo ""
        echo "================ FINAL SUMMARY ================"
        echo "Completion Time: $(date)"
        echo "Repository Owner: $REPO_OWNER"
        echo "Total Repositories: $TOTAL_REPOS"
        echo "Processed Repositories: $PROCESSED_REPOS"
        echo "Successful SBOMs: $SUCCESSFUL_SBOMS"
        echo "Failed SBOMs: $FAILED_SBOMS"
        echo "Skipped SBOMs: $SKIPPED_SBOMS"
        echo "Success Rate: $(( TOTAL_REPOS > 0 ? (SUCCESSFUL_SBOMS * 100) / TOTAL_REPOS : 0 ))%"
        echo "Execution Time: $duration_formatted"
        echo "=============================================="
    } >> "$LOG_FILE"
}

# Signal handler for graceful shutdown
cleanup() {
    log_warning "Script interrupted. Generating partial summary..."
    generate_summary
    exit 130
}

# Main execution function
main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Validate input and prerequisites
    validate_input "$@"
    check_prerequisites
    validate_repo_owner
    
    # Setup environment
    setup_environment
    
    # Get repositories and process them
    get_repositories
    process_repositories
    
    # Generate final summary
    generate_summary
    
    # Exit with appropriate code
    if [[ $FAILED_SBOMS -eq 0 ]]; then
        log_success "All SBOMs generated successfully!"
        exit 0
    elif [[ $SUCCESSFUL_SBOMS -gt 0 ]]; then
        log_warning "Some SBOMs failed to generate. Check log file for details."
        exit 1
    else
        log_error "All SBOM generations failed."
        exit 2
    fi
}

# Declare repos_array as global
declare -a repos_array

# Run main function with all arguments
main "$@"