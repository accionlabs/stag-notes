#!/bin/bash
# STAG - Strategy and Technology Advisory Group Documentation Management
# Simplified Auto-Sync Version
# Usage: ./stag.sh
# Automatically discovers and syncs all accessible STAG repositories

# Configuration
STAG_ORG="accionlabs"
SCRIPT_VERSION="3.0.0"
DOCS_DIR="_docs"
CONFIG_FILE=".stag-config.json"
TEAM_CONFIG_FILE=".stag-team.json"
CACHE_DURATION=3600  # 1 hour in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji shortcuts
SUCCESS="✅"
ERROR="❌" 
INFO="ℹ️"
WARNING="⚠️"
ROCKET="🚀"
FOLDER="📁"
SYNC="🔄"
LOCK="🔒"
DISCOVER="🔍"
CREATE="🆕"

# =============================================================================
# UTILITY FUNCTIONS  
# =============================================================================

log_info() {
    echo -e "${INFO} ${1}"
}

log_success() {
    echo -e "${SUCCESS} ${GREEN}${1}${NC}"
}

log_error() {
    echo -e "${ERROR} ${RED}${1}${NC}"
}

log_warning() {
    echo -e "${WARNING} ${YELLOW}${1}${NC}"
}

log_step() {
    echo -e "${ROCKET} ${BLUE}${1}${NC}"
}

log_discover() {
    echo -e "${DISCOVER} ${PURPLE}${1}${NC}"
}

log_create() {
    echo -e "${CREATE} ${CYAN}${1}${NC}"
}

check_github_cli() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not found. Please install it first."
        log_info "Install: https://cli.github.com/"
        return 1
    fi
    return 0
}

get_consultant_name() {
    local name=$(git config user.name 2>/dev/null)
    if [ -z "$name" ]; then
        log_error "Git user.name not set. Please configure it:"
        log_info "git config user.name 'Your Name'"
        return 1
    fi
    echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]'
}

load_team_config() {
    if [ ! -f "$TEAM_CONFIG_FILE" ]; then
        log_warning "Team configuration file not found: $TEAM_CONFIG_FILE"
        log_info "Create it with: {"team_members": {"name": "github-username", ...}}"
        return 1
    fi
    return 0
}

get_github_username() {
    local display_name=$1
    
    if ! load_team_config; then
        return 1
    fi
    
    local github_username=$(jq -r --arg name "$display_name" '.team_members[$name] // empty' "$TEAM_CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$github_username" ]; then
        log_error "Team member '$display_name' not found in team configuration"
        return 1
    fi
    
    echo "$github_username"
}

validate_team_members() {
    local team_members_json=$1
    local lead=$2
    local project_name=$3
    
    if ! load_team_config; then
        return 1
    fi
    
    local validation_failed=false
    
    # Validate lead
    if [ -n "$lead" ]; then
        if ! get_github_username "$lead" >/dev/null 2>&1; then
            log_error "Project $project_name: Lead '$lead' not found in team configuration"
            validation_failed=true
        fi
    fi
    
    # Validate team members
    echo "$team_members_json" | jq -r '.[]' 2>/dev/null | while read member; do
        if [ -n "$member" ]; then
            if ! get_github_username "$member" >/dev/null 2>&1; then
                log_error "Project $project_name: Team member '$member' not found in team configuration"
                validation_failed=true
            fi
        fi
    done
    
    if [ "$validation_failed" = true ]; then
        return 1
    fi
    
    return 0
}

get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

sync_project_permissions() {
    local project_name=$1
    local repo_name="stag-project-$project_name"
    local index_file="$DOCS_DIR/projects/$project_name/index.md"
    
    if [ ! -f "$index_file" ]; then
        log_warning "No index.md found for project: $project_name"
        return 0
    fi
    
    # Extract front matter using awk
    local front_matter=$(awk '/^---$/{if(++n==2) exit} n>=1' "$index_file")
    
    if [ -z "$front_matter" ]; then
        log_warning "No front matter found in $project_name/index.md"
        return 0
    fi
    
    # Parse team information from front matter
    local lead=$(echo "$front_matter" | grep "^lead:" | sed 's/lead: *//; s/["]//g' | tr -d '"' | xargs)
    local team_raw=$(echo "$front_matter" | grep "^team:" | sed 's/team: *//')
    
    # Convert team to JSON array if it's in YAML format
    local team_json="[]"
    if [ -n "$team_raw" ]; then
        # Handle both formats: team: ["user1", "user2"] and team: [user1, user2]
        team_json=$(echo "$team_raw" | sed 's/\[/["/; s/\]/"]/' | sed 's/, */", "/g' | sed 's/\["/["/; s/"\]/"]/')
        # Validate it's proper JSON
        if ! echo "$team_json" | jq . >/dev/null 2>&1; then
            team_json="[]"
        fi
    fi
    
    log_info "Syncing permissions for project: $project_name"
    if [ -n "$lead" ]; then
        log_info "  Lead: $lead"
    fi
    if [ "$team_json" != "[]" ]; then
        local team_display=$(echo "$team_json" | jq -r 'join(", ")')
        log_info "  Team: $team_display"
    fi
    
    # Validate team members exist in configuration
    if ! validate_team_members "$team_json" "$lead" "$project_name"; then
        log_error "Team validation failed for project: $project_name"
        return 1
    fi
    
    # Check if repository exists
    if ! gh repo view "$STAG_ORG/$repo_name" >/dev/null 2>&1; then
        log_create "Creating repository: $repo_name"
        if ! gh repo create "$STAG_ORG/$repo_name" --private --description "STAG project: $project_name"; then
            log_error "Failed to create repository: $repo_name"
            return 1
        fi
        
        # Initialize repository with basic structure
        local temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone "git@github.com:$STAG_ORG/$repo_name.git"
        cd "$repo_name"
        
        mkdir -p proposal research presentations deliverables
        echo "# $project_name Project" > README.md
        echo "" >> README.md
        echo "This repository was auto-created by STAG system." >> README.md
        echo "The team configuration is managed via the index.md file." >> README.md
        
        git add .
        git commit -m "Initial repository structure"
        git push
        
        cd ../../..
        rm -rf "$temp_dir"
    fi
    
    # Set lead permissions (admin)
    if [ -n "$lead" ]; then
        local lead_github=$(get_github_username "$lead")
        if [ -n "$lead_github" ]; then
            if gh api repos/"$STAG_ORG"/"$repo_name"/collaborators/"$lead_github" -X PUT -f permission=admin >/dev/null 2>&1; then
                log_success "  Set admin access for lead: $lead ($lead_github)"
            else
                log_warning "  Failed to set admin access for lead: $lead"
            fi
        fi
    fi
    
    # Set team member permissions (push)
    echo "$team_json" | jq -r '.[]' 2>/dev/null | while read member; do
        if [ -n "$member" ]; then
            local member_github=$(get_github_username "$member")
            if [ -n "$member_github" ]; then
                if gh api repos/"$STAG_ORG"/"$repo_name"/collaborators/"$member_github" -X PUT -f permission=push >/dev/null 2>&1; then
                    log_success "  Set push access for: $member ($member_github)"
                else
                    log_warning "  Failed to set push access for: $member"
                fi
            fi
        fi
    done
    
    return 0
}

is_cache_valid() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    local last_scan=$(jq -r '.last_scan // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$last_scan" ]; then
        return 1
    fi
    
    local last_epoch=$(date -d "$last_scan" +%s 2>/dev/null || echo 0)
    local current_epoch=$(date +%s)
    local age=$((current_epoch - last_epoch))
    
    [ $age -lt $CACHE_DURATION ]
}

# =============================================================================
# REPOSITORY DISCOVERY
# =============================================================================

discover_repositories() {
    local consultant=$(get_consultant_name)
    if [ -z "$consultant" ]; then
        return 1
    fi
    
    log_discover "Discovering accessible STAG repositories for: $consultant"
    
    if ! check_github_cli; then
        return 1
    fi
    
    # Initialize repository lists
    local private_repo="stag-private-$consultant"
    local shared_repo="stag-shared"
    local projects=()
    
    # Check if private repository exists, create if not
    log_discover "Checking private repository: $private_repo"
    if ! gh repo view "$STAG_ORG/$private_repo" >/dev/null 2>&1; then
        log_create "Creating private repository: $private_repo"
        if gh repo create "$STAG_ORG/$private_repo" --private --description "STAG private documentation for $consultant"; then
            log_success "Private repository created"
        else
            log_error "Failed to create private repository"
            return 1
        fi
    else
        log_info "Private repository found"
    fi
    
    # Check shared repository
    log_discover "Checking shared repository: $shared_repo"
    if gh repo view "$STAG_ORG/$shared_repo" >/dev/null 2>&1; then
        log_info "Shared repository found"
    else
        log_warning "Shared repository not found: $shared_repo"
        shared_repo=""
    fi
    
    # Discover project repositories
    log_discover "Scanning for accessible project repositories..."
    local repo_list=$(gh repo list "$STAG_ORG" --search "stag-project" --json name,name --jq '.[].name' 2>/dev/null || echo "")
    
    for repo in $repo_list; do
        if [[ "$repo" =~ ^stag-project-.+ ]]; then
            # Check if we have access to this repository
            if gh repo view "$STAG_ORG/$repo" >/dev/null 2>&1; then
                local project_name=$(echo "$repo" | sed 's/^stag-project-//')
                projects+=("$repo")
                log_info "Project found: $project_name"
            fi
        fi
    done
    
    # Create configuration
    local config=$(jq -n \
        --arg consultant "$consultant" \
        --arg timestamp "$(get_timestamp)" \
        --arg private "$private_repo" \
        --arg shared "$shared_repo" \
        --argjson projects "$(printf '%s\n' "${projects[@]}" | jq -R . | jq -s .)" \
        '{
            consultant: $consultant,
            last_scan: $timestamp,
            repositories: {
                private: $private,
                shared: ($shared | select(. != "")),
                projects: $projects
            }
        }')
    
    echo "$config" > "$CONFIG_FILE"
    
    log_success "Repository discovery completed"
    log_info "Found: 1 private, $([ -n "$shared_repo" ] && echo "1" || echo "0") shared, ${#projects[@]} projects"
    
    return 0
}

load_config() {
    if is_cache_valid; then
        log_info "Using cached repository configuration"
        return 0
    else
        log_step "Repository cache expired or missing, discovering repositories..."
        discover_repositories
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

initialize_docs() {
    local consultant=$(get_consultant_name)
    if [ -z "$consultant" ]; then
        return 1
    fi
    
    log_step "Initializing STAG documentation structure..."
    
    # Create main docs directory if it doesn't exist
    if [ ! -d "$DOCS_DIR" ]; then
        mkdir -p "$DOCS_DIR"
        cd "$DOCS_DIR"
        git init
        cd ..
        log_create "Created documentation directory"
    fi
    
    # Create subdirectories
    mkdir -p "$DOCS_DIR/private"
    mkdir -p "$DOCS_DIR/shared" 
    mkdir -p "$DOCS_DIR/projects"
    
    # Create main index if it doesn't exist
    if [ ! -f "$DOCS_DIR/index.md" ]; then
        cat > "$DOCS_DIR/index.md" << EOF
---
title: "${consultant^}'s STAG Documentation"
description: "Personal documentation and project workspace"
date: $(date +%Y-%m-%d)
---

# ${consultant^}'s STAG Documentation

## Quick Navigation

- [Private Notes](private/) - Personal methodologies and insights
- [Shared Resources](shared/) - STAG team resources
- [Active Projects](projects/) - Client work and engagements

## Usage

Run \`./stag.sh\` to automatically sync all repositories.

## Last Updated
$(date)

---
*Generated by STAG Documentation Management Tool v${SCRIPT_VERSION}*
EOF
        log_create "Created main index file"
    fi
    
    # Create private README if it doesn't exist
    if [ ! -f "$DOCS_DIR/private/README.md" ]; then
        cat > "$DOCS_DIR/private/README.md" << EOF
---
title: "Private Documentation"
description: "Personal methodologies and confidential notes"
date: $(date +%Y-%m-%d)
---

# Private Documentation

This folder contains your personal consulting methodologies and frameworks.

## Organization

Create folders and files as needed:
- **methodologies/** - Your unique approaches and techniques
- **insights/** - Industry insights and observations  
- **client-notes/** - Confidential client relationship notes

## Getting Started

- Document your unique approaches and techniques
- Keep client-specific insights confidential
- Changes are automatically synced to your private repository
EOF
        log_create "Created private documentation structure"
    fi
    
    log_success "Documentation structure initialized"
}

# =============================================================================
# REPOSITORY SYNCHRONIZATION
# =============================================================================

sync_repository() {
    local repo_type=$1
    local repo_name=$2
    local local_path=$3
    
    if [ -z "$repo_name" ]; then
        return 0
    fi
    
    local repo_url="git@github.com:$STAG_ORG/$repo_name.git"
    
    cd "$DOCS_DIR"
    
    # Check if local path exists and is a git subtree
    if [ -d "$local_path" ]; then
        # Try to sync existing subtree
        echo -n "${SYNC} Syncing $repo_type ($repo_name)... "
        
        # Pull changes from remote
        if git subtree pull --prefix="$local_path" "$repo_url" main --squash >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}conflicts${NC}"
            log_warning "Merge conflicts in $repo_type - attempting auto-resolve"
            
            # Auto-resolve conflicts by preferring remote changes
            git checkout --theirs "$local_path"
            git add "$local_path"
            git commit -m "Auto-resolved conflicts in $repo_type" >/dev/null 2>&1
            echo -e "  ${INFO} Auto-resolved conflicts"
        fi
        
        # Push local changes if any
        if ! git diff --quiet "$local_path" || ! git diff --cached --quiet "$local_path"; then
            git add "$local_path"
            git commit -m "Auto-sync: Updated $repo_type" >/dev/null 2>&1
            
            if git subtree push --prefix="$local_path" "$repo_url" main >/dev/null 2>&1; then
                echo -e "  ${SUCCESS} Pushed local changes"
            else
                echo -e "  ${WARNING} Failed to push local changes"
            fi
        fi
    else
        # Add new subtree
        echo -n "${SYNC} Adding $repo_type ($repo_name)... "
        
        if git subtree add --prefix="$local_path" "$repo_url" main --squash >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            log_error "Failed to add $repo_type repository"
        fi
    fi
    
    cd ..
}

sync_all_repositories() {
    log_step "Starting repository synchronization..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "No configuration found. Please run discovery first."
        return 1
    fi
    
    # Read configuration
    local private_repo=$(jq -r '.repositories.private // empty' "$CONFIG_FILE")
    local shared_repo=$(jq -r '.repositories.shared // empty' "$CONFIG_FILE")
    local projects=($(jq -r '.repositories.projects[]? // empty' "$CONFIG_FILE"))
    
    # Sync private repository
    if [ -n "$private_repo" ]; then
        sync_repository "private" "$private_repo" "private"
    fi
    
    # Sync shared repository
    if [ -n "$shared_repo" ]; then
        sync_repository "shared" "$shared_repo" "shared"
    fi
    
    # Sync project repositories
    for project_repo in "${projects[@]}"; do
        if [ -n "$project_repo" ]; then
            local project_name=$(echo "$project_repo" | sed 's/^stag-project-//')
            sync_repository "project" "$project_repo" "projects/$project_name"
        fi
    done
    
    log_success "Repository synchronization completed"
}

# =============================================================================
# STATUS REPORTING
# =============================================================================

show_status() {
    echo -e "${BLUE}📊 STAG Auto-Sync Status${NC}"
    echo "========================"
    
    local consultant=$(get_consultant_name)
    echo -e "${FOLDER} Consultant: ${CYAN}$consultant${NC}"
    echo -e "${FOLDER} Base repository: ${CYAN}$(basename $(pwd))${NC}"
    
    if [ -f "$CONFIG_FILE" ]; then
        local last_scan=$(jq -r '.last_scan // empty' "$CONFIG_FILE")
        echo -e "🕐 Last scan: ${CYAN}$last_scan${NC}"
        
        # Repository counts
        local private_repo=$(jq -r '.repositories.private // empty' "$CONFIG_FILE")
        local shared_repo=$(jq -r '.repositories.shared // empty' "$CONFIG_FILE")
        local project_count=$(jq -r '.repositories.projects | length' "$CONFIG_FILE" 2>/dev/null || echo 0)
        
        echo ""
        echo -e "${PURPLE}📊 Repository Summary:${NC}"
        echo -e "  🔒 Private: $([ -n "$private_repo" ] && echo "✓ $private_repo" || echo "❌ Not found")"
        echo -e "  📚 Shared: $([ -n "$shared_repo" ] && echo "✓ $shared_repo" || echo "❌ Not found")"
        echo -e "  📁 Projects: $project_count active"
        
        if [ "$project_count" -gt 0 ]; then
            echo ""
            echo -e "${GREEN}📁 Active Projects:${NC}"
            jq -r '.repositories.projects[]?' "$CONFIG_FILE" 2>/dev/null | while read project_repo; do
                if [ -n "$project_repo" ]; then
                    local project_name=$(echo "$project_repo" | sed 's/^stag-project-//')
                    echo -e "  ${LOCK} $project_name"
                fi
            done
        fi
    else
        echo -e "  ${WARNING} No configuration found - run ./stag.sh to initialize"
    fi
    
    # Local status
    echo ""
    echo -e "${YELLOW}📝 Local Status:${NC}"
    if [ -d "$DOCS_DIR" ]; then
        cd "$DOCS_DIR"
        if git status --porcelain 2>/dev/null | grep -q .; then
            echo -e "  ${INFO} Uncommitted changes detected"
            git status --short | head -5
            local change_count=$(git status --porcelain | wc -l)
            if [ "$change_count" -gt 5 ]; then
                echo -e "  ${INFO} ... and $((change_count - 5)) more files"
            fi
        else
            echo -e "  ✅ All changes synchronized"
        fi
        cd ..
    else
        echo -e "  ${WARNING} Documentation directory not found"
    fi
}

# =============================================================================
# HELP AND VERSION
# =============================================================================

show_help() {
    echo -e "${BLUE}STAG Auto-Sync Documentation Tool v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}Strategy and Technology Advisory Group${NC}"
    echo ""
    echo -e "${CYAN}USAGE:${NC}"
    echo "  ./stag.sh              Auto-discover and sync all repositories"
    echo "  ./stag.sh status       Show current status and configuration"
    echo "  ./stag.sh discover     Force repository discovery (refresh cache)"
    echo "  ./stag.sh help         Show this help message"
    echo "  ./stag.sh version      Show version information"
    echo ""
    echo -e "${CYAN}HOW IT WORKS:${NC}"
    echo "  1. ${DISCOVER} Discovers your accessible STAG repositories"
    echo "  2. ${CREATE} Creates your private repository if needed"
    echo "  3. ${SYNC} Bidirectionally syncs all content"
    echo "  4. ${SUCCESS} Shows detailed sync report"
    echo ""
    echo -e "${CYAN}REPOSITORY STRUCTURE:${NC}"
    echo "  📁 _docs/private/      - Your personal methodologies (stag-private-[name])"
    echo "  📁 _docs/shared/       - Team resources (stag-shared)"
    echo "  📁 _docs/projects/     - Client projects (stag-project-[name])"
    echo ""
    echo -e "${CYAN}GETTING STARTED:${NC}"
    echo "  1. Run: ./stag.sh"
    echo "  2. Start creating content in _docs/ folders"
    echo "  3. Run: ./stag.sh periodically to stay synced"
    echo ""
    echo -e "${CYAN}CONFIGURATION:${NC}"
    echo "  • Uses git config user.name for consultant identification"
    echo "  • Caches repository list for 1 hour (.stag-config.json)"
    echo "  • Auto-resolves merge conflicts"
}

show_version() {
    echo "STAG Auto-Sync Documentation Tool v${SCRIPT_VERSION}"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local command=${1:-"sync"}
    
    case $command in
        sync|"")
            initialize_docs
            load_config
            validate_and_create_projects
            sync_all_repositories
            show_status
            ;;
        discover)
            log_step "Forcing repository discovery..."
            discover_repositories
            log_success "Repository discovery completed"
            ;;
        status)
            show_status
            ;;
        help|-h|--help)
            show_help
            ;;
        version|-v|--version)
            show_version
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Please install jq first."
    log_info "Install: https://stedolan.github.io/jq/download/"
    exit 1
fi

# Run main function
main "$@"