#!/bin/bash
# STAG - Strategy and Technology Advisory Group Documentation Management
# Simplified Auto-Sync Version
# Usage: ./stag.sh
# Automatically discovers and syncs all accessible STAG repositories

# Configuration
STAG_ORG="accionlabs"
SCRIPT_VERSION="3.0.3"
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
        log_info "Create it with: {\"team_members\": {\"name\": \"github-username\", ...}}"
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
# PROJECT VALIDATION AND CREATION
# =============================================================================

validate_and_create_projects() {
    if [ ! -d "$DOCS_DIR/projects" ]; then
        return 0
    fi
    
    log_step "Validating project configurations..."
    
    local projects_created=()
    
    # Find all project directories
    for project_dir in "$DOCS_DIR/projects"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            local index_file="$project_dir/index.md"
            
            if [ ! -f "$index_file" ]; then
                log_warning "Project '$project_name' missing index.md - skipping"
                continue
            fi
            
            # Extract front matter
            local front_matter=$(awk '/^---$/{if(++n==2) exit} n>=1' "$index_file")
            
            if [ -z "$front_matter" ]; then
                log_warning "Project '$project_name' has invalid index.md (no front matter) - skipping"
                continue
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
            
            # Validate team members
            if ! validate_team_members "$team_json" "$lead" "$project_name"; then
                log_error "Skipping project '$project_name' due to validation errors"
                continue
            fi
            
            # Sync project permissions
            if sync_project_permissions "$project_name"; then
                projects_created+=("stag-project-$project_name")
            fi
        fi
    done
    
    # Update config file with newly created projects
    if [ ${#projects_created[@]} -gt 0 ]; then
        log_info "Updating configuration with newly created projects..."
        
        # Read current config
        local current_projects=($(jq -r '.repositories.projects[]? // empty' "$CONFIG_FILE" 2>/dev/null))
        
        # Add new projects to the list
        for new_project in "${projects_created[@]}"; do
            local found=false
            for existing in "${current_projects[@]}"; do
                if [ "$existing" = "$new_project" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                current_projects+=("$new_project")
            fi
        done
        
        # Update config file
        local consultant=$(jq -r '.consultant' "$CONFIG_FILE")
        local shared_repo=$(jq -r '.repositories.shared // empty' "$CONFIG_FILE")
        
        local config=$(jq -n \
            --arg consultant "$consultant" \
            --arg timestamp "$(get_timestamp)" \
            --arg shared "$shared_repo" \
            --argjson projects "$(printf '%s\n' "${current_projects[@]}" | jq -R . | jq -s .)" \
            '{
                consultant: $consultant,
                last_scan: $timestamp,
                repositories: {
                    shared: ($shared | select(. != "")),
                    projects: $projects
                }
            }')
        
        echo "$config" > "$CONFIG_FILE"
    fi
}

sync_project_permissions() {
    local project_name=$1
    local repo_name="stag-project-$project_name"
    local index_file="$DOCS_DIR/projects/$project_name/index.md"
    
    if [ ! -f "$index_file" ]; then
        log_warning "No index.md found for project: $project_name"
        return 1
    fi
    
    # Extract front matter using awk
    local front_matter=$(awk '/^---$/{if(++n==2) exit} n>=1' "$index_file")
    
    if [ -z "$front_matter" ]; then
        log_warning "No front matter found in $project_name/index.md"
        return 1
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
    
    # Check if repository exists
    if ! gh repo view "$STAG_ORG/$repo_name" >/dev/null 2>&1; then
        log_create "Creating repository: $repo_name"
        if ! gh repo create "$STAG_ORG/$repo_name" --private --description "STAG project: $project_name"; then
            log_error "Failed to create repository: $repo_name"
            return 1
        fi
        
        # Push existing local content
        push_local_content_to_new_repo "$DOCS_DIR/projects/$project_name" "$repo_name"
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

# =============================================================================
# Push local content to newly created repository
# =============================================================================

push_local_content_to_new_repo() {
    local local_path=$1
    local repo_name=$2
    local repo_url="git@github.com:$STAG_ORG/$repo_name.git"
    
    log_info "Pushing existing local content to new repository..."
    
    cd "$local_path"
    
    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        git init >/dev/null 2>&1
    fi
    
    # Add remote if not already added
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "$repo_url"
    else
        git remote set-url origin "$repo_url"
    fi
    
    # Add all files
    git add -A >/dev/null 2>&1
    
    # Commit if there are changes
    if [ "$(git status --porcelain)" ]; then
        git commit -m "Initial commit: Local project content" >/dev/null 2>&1
    fi
    
    # Create main branch if it doesn't exist
    git branch -M main >/dev/null 2>&1
    
    # Push to remote
    if git push -u origin main -f >/dev/null 2>&1; then
        log_success "Successfully pushed local content to repository"
    else
        log_warning "Failed to push local content - will retry on next sync"
    fi
    
    cd - >/dev/null
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
    local shared_repo="stag-shared"
    local projects=()
    
    # Private folder is local-only, no repository
    log_info "Private folder is local-only (not synced to GitHub)"
    
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
    
    # Create configuration (no private repo)
    local config=$(jq -n \
        --arg consultant "$consultant" \
        --arg timestamp "$(get_timestamp)" \
        --arg shared "$shared_repo" \
        --argjson projects "$(printf '%s\n' "${projects[@]}" | jq -R . | jq -s .)" \
        '{
            consultant: $consultant,
            last_scan: $timestamp,
            repositories: {
                shared: ($shared | select(. != "")),
                projects: $projects
            }
        }')
    
    echo "$config" > "$CONFIG_FILE"
    
    log_success "Repository discovery completed"
    log_info "Found: $([ -n "$shared_repo" ] && echo "1" || echo "0") shared, ${#projects[@]} projects"
    
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

- [Private Notes](private/) - Personal notes and methodologies (local-only)
- [Shared Resources](shared/) - STAG team resources
- [Active Projects](projects/) - Client work and engagements

## Usage

Run \`./stag.sh\` to automatically sync shared and project repositories.

**Note**: The private folder is local-only and not synced to GitHub.

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
description: "Personal notes and confidential information (local-only)"
date: $(date +%Y-%m-%d)
---

# Private Documentation

This folder contains your personal notes and confidential information.

## ⚠️ Important

**This folder is local-only and NOT synced to GitHub.**

Feel free to store:
- Personal methodologies and frameworks
- Confidential client notes
- Sensitive information
- Draft ideas and experiments

## Organization

Create folders and files as needed:
- **methodologies/** - Your unique approaches and techniques
- **insights/** - Industry insights and observations  
- **client-notes/** - Confidential client relationship notes
- **drafts/** - Work in progress

## Security

Since this folder is not synced to any remote repository:
- Your content stays completely private
- No risk of accidental exposure
- Perfect for sensitive information

Remember to backup important content independently!
EOF
        log_create "Created private documentation structure"
    fi
    
    # Create .gitignore in private folder to be extra safe
    if [ ! -f "$DOCS_DIR/private/.gitignore" ]; then
        cat > "$DOCS_DIR/private/.gitignore" << EOF
# This folder is local-only
# Adding .gitignore as extra protection
*
!.gitignore
!README.md
EOF
        log_create "Added .gitignore to private folder for extra protection"
    fi
    
    log_success "Documentation structure initialized"
}

# =============================================================================
# IMPROVED REPOSITORY SYNCHRONIZATION
# =============================================================================

sync_repository() {
    local repo_type=$1
    local repo_name=$2
    local local_path=$3
    
    if [ -z "$repo_name" ]; then
        return 0
    fi
    
    local repo_url="git@github.com:$STAG_ORG/$repo_name.git"
    
    # Check if repository exists on remote
    if ! gh repo view "$STAG_ORG/$repo_name" >/dev/null 2>&1; then
        log_warning "Repository $repo_name does not exist on GitHub"
        return 1
    fi
    
    echo -n "${SYNC} Syncing $repo_type ($repo_name)... "
    
    # IMPORTANT FIX: Create parent directory if it doesn't exist (for projects)
    local parent_dir=$(dirname "$local_path")
    if [ ! -d "$parent_dir" ]; then
        mkdir -p "$parent_dir"
        log_info "Created parent directory: $parent_dir"
    fi
    
    # Check if local path exists and is a git repo
    if [ ! -d "$local_path/.git" ]; then
        # Directory exists but no git - need to handle carefully
        if [ -d "$local_path" ] && [ "$(ls -A "$local_path" 2>/dev/null)" ]; then
            # We have local content but no git repo
            log_info "Local content found without git repo, setting up..."
            
            # Backup local content
            local temp_backup=$(mktemp -d)
            cp -r "$local_path"/* "$temp_backup/" 2>/dev/null || true
            cp -r "$local_path"/.[^.]* "$temp_backup/" 2>/dev/null || true
            
            # Remove the directory and clone
            rm -rf "$local_path"
            if git clone "$repo_url" "$local_path" >/dev/null 2>&1; then
                cd "$local_path"
                
                # Copy back the local content
                cp -r "$temp_backup"/* . 2>/dev/null || true
                cp -r "$temp_backup"/.[^.]* . 2>/dev/null || true
                
                # Check if we have new files to add
                if [ "$(git status --porcelain)" ]; then
                    git add -A >/dev/null 2>&1
                    git commit -m "Add local content from $(hostname)" >/dev/null 2>&1
                    if git push origin main >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ (cloned and pushed local content)${NC}"
                    else
                        echo -e "${YELLOW}⚠ (cloned, push pending)${NC}"
                    fi
                else
                    echo -e "${GREEN}✓ (cloned, no new content)${NC}"
                fi
                
                cd - >/dev/null
            else
                echo -e "${RED}✗ (clone failed)${NC}"
                # Restore the backup
                rm -rf "$local_path"
                mv "$temp_backup" "$local_path"
                return 1
            fi
            
            rm -rf "$temp_backup"
        else
            # No local content, just clone
            # IMPORTANT FIX: Ensure the parent directory exists before cloning
            if [ ! -d "$(dirname "$local_path")" ]; then
                mkdir -p "$(dirname "$local_path")"
            fi
            
            if git clone "$repo_url" "$local_path" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ (cloned)${NC}"
            else
                echo -e "${RED}✗ (clone failed)${NC}"
                return 1
            fi
        fi
    else
        # Repository exists locally, sync it
        cd "$local_path"
        
        # IMPORTANT: Check for uncommitted changes FIRST
        if [ "$(git status --porcelain)" ]; then
            log_info "Found uncommitted changes, committing..."
            git add -A >/dev/null 2>&1
            git commit -m "Auto-commit: Local changes from $(hostname) - $(date +%Y-%m-%d_%H:%M:%S)" >/dev/null 2>&1
        fi
        
        # Ensure we're on main branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        if [ "$current_branch" != "main" ]; then
            git checkout main >/dev/null 2>&1 || git checkout -b main >/dev/null 2>&1
        fi
        
        # Fetch from remote
        git fetch origin >/dev/null 2>&1
        
        # Check if we have diverged from remote
        local local_ref=$(git rev-parse HEAD 2>/dev/null || echo "none")
        local remote_ref=$(git rev-parse origin/main 2>/dev/null || echo "none")
        
        if [ "$local_ref" = "$remote_ref" ]; then
            echo -e "${GREEN}✓ (up to date)${NC}"
        elif [ "$remote_ref" = "none" ]; then
            # Remote has no main branch yet, push our content
            if git push -u origin main >/dev/null 2>&1; then
                echo -e "${GREEN}✓ (initialized remote)${NC}"
            else
                echo -e "${RED}✗ (push failed)${NC}"
            fi
        else
            # We have diverged - need to merge
            local commits_ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
            local commits_behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
            
            if [ "$commits_ahead" -eq 0 ] && [ "$commits_behind" -gt 0 ]; then
                # Only remote has changes, fast-forward
                if git merge origin/main --ff-only >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ (updated: $commits_behind new commits)${NC}"
                else
                    echo -e "${RED}✗ (merge failed)${NC}"
                fi
            elif [ "$commits_ahead" -gt 0 ] && [ "$commits_behind" -eq 0 ]; then
                # Only we have changes, push them
                if git push origin main >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ (pushed: $commits_ahead commits)${NC}"
                else
                    echo -e "${RED}✗ (push failed)${NC}"
                fi
            else
                # Both have changes, merge then push
                echo -e "${YELLOW}diverged${NC}"
                log_info "Merging: $commits_ahead local, $commits_behind remote commits"
                
                if git merge origin/main --no-edit >/dev/null 2>&1; then
                    echo -e "  ${SUCCESS} Merged successfully"
                    if git push origin main >/dev/null 2>&1; then
                        echo -e "  ${SUCCESS} Pushed merged changes"
                    else
                        echo -e "  ${WARNING} Push failed - will retry next sync"
                    fi
                else
                    # Merge conflict - try to resolve
                    echo -e "  ${WARNING} Merge conflict detected"
                    git status --porcelain | grep "^UU" | awk '{print $2}' | while read conflicted_file; do
                        echo -e "  ${INFO} Conflict in: $conflicted_file"
                    done
                    
                    # Auto-resolve by taking both changes
                    git add -A >/dev/null 2>&1
                    git commit -m "Auto-resolved conflicts: merged both versions" >/dev/null 2>&1
                    
                    if git push origin main >/dev/null 2>&1; then
                        echo -e "  ${SUCCESS} Resolved and pushed"
                    else
                        echo -e "  ${WARNING} Resolved but push failed"
                    fi
                fi
            fi
        fi
        
        cd - >/dev/null
    fi
}

# Also update sync_all_repositories to provide better feedback
sync_all_repositories() {
    log_step "Starting repository synchronization..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "No configuration found. Please run discovery first."
        return 1
    fi
    
    # Read configuration
    local shared_repo=$(jq -r '.repositories.shared // empty' "$CONFIG_FILE")
    local projects=($(jq -r '.repositories.projects[]? // empty' "$CONFIG_FILE"))
    
    # Note about private folder
    log_info "Private folder is local-only and not synced to GitHub"
    
    # Sync shared repository
    if [ -n "$shared_repo" ]; then
        sync_repository "shared" "$shared_repo" "$DOCS_DIR/shared"
    fi
    
    # Sync project repositories
    if [ ${#projects[@]} -gt 0 ]; then
        log_info "Syncing ${#projects[@]} project(s)..."
    fi
    
    for project_repo in "${projects[@]}"; do
        if [ -n "$project_repo" ]; then
            local project_name=$(echo "$project_repo" | sed 's/^stag-project-//')
            local project_path="$DOCS_DIR/projects/$project_name"
            
            # Log which project we're syncing
            log_info "Processing project: $project_name"
            
            sync_repository "project" "$project_repo" "$project_path"
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
        local shared_repo=$(jq -r '.repositories.shared // empty' "$CONFIG_FILE")
        local project_count=$(jq -r '.repositories.projects | length' "$CONFIG_FILE" 2>/dev/null || echo 0)
        
        echo ""
        echo -e "${PURPLE}📊 Repository Summary:${NC}"
        echo -e "  🔒 Private: Local-only (not synced)"
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
        # Check private folder (local-only)
        if [ -d "$DOCS_DIR/private" ]; then
            local private_files=$(find "$DOCS_DIR/private" -type f -name "*.md" 2>/dev/null | wc -l)
            echo -e "  📝 Private folder: $private_files markdown files (local-only)"
        fi
        
        # Check synced directories
        cd "$DOCS_DIR"
        for dir in shared projects/*; do
            if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
                cd "$dir"
                if git status --porcelain 2>/dev/null | grep -q .; then
                    echo -e "  ${INFO} Uncommitted changes in $dir"
                fi
                cd - >/dev/null
            fi
        done
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
    echo "  2. ${SYNC} Bidirectionally syncs shared and project content"
    echo "  3. ${LOCK} Keeps private notes local-only (not synced)"
    echo "  4. ${SUCCESS} Shows detailed sync report"
    echo ""
    echo -e "${CYAN}REPOSITORY STRUCTURE:${NC}"
    echo "  📁 _docs/private/      - Your personal notes (local-only, not synced)"
    echo "  📁 _docs/shared/       - Team resources (stag-shared)"
    echo "  📁 _docs/projects/     - Client projects (stag-project-[name])"
    echo ""
    echo -e "${CYAN}GETTING STARTED:${NC}"
    echo "  1. Run: ./stag.sh"
    echo "  2. Create private notes in _docs/private/ (stays local)"
    echo "  3. Work on team content in _docs/shared/ and _docs/projects/"
    echo "  4. Run: ./stag.sh periodically to stay synced"
    echo ""
    echo -e "${CYAN}CONFIGURATION:${NC}"
    echo "  • Uses git config user.name for consultant identification"
    echo "  • Caches repository list for 1 hour (.stag-config.json)"
    echo "  • Auto-commits and pushes local changes"
    echo "  • Private folder is never synced to GitHub"
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