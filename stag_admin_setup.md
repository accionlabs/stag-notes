# STAG Admin Setup Guide
## One-time setup for Strategy and Technology Advisory Group

This guide is for administrators setting up the STAG documentation system for the team.

## Prerequisites

- Admin access to AccionLabs GitHub organization
- GitHub CLI (`gh`) installed and authenticated
- Git configured for SSH access
- jq installed for JSON processing

## Repository Structure Overview

The STAG system uses three types of repositories with automatic team management:

| Type | Naming Convention | Purpose | Access Level |
|------|------------------|---------|--------------|
| **Private** | `stag-private-[consultant-name]` | Individual consultant's private notes | Individual only |
| **Shared** | `stag-shared` | Team resources and templates | All STAG team members |
| **Projects** | `stag-project-[project-name]` | Client work and deliverables | Auto-managed by project teams |

## Step 1: Create STAG Team in AccionLabs

### Create Team
1. Go to https://github.com/orgs/accionlabs/teams
2. Click "New team"
3. **Team name**: `stag`
4. **Description**: "Strategy and Technology Advisory Group"
5. **Privacy**: Private
6. Click "Create team"

### Add Team Members
1. In the STAG team page, click "Members" → "Add a member"
2. Add each team member:
   - Saurabh
   - Hemesh
   - Nischal
   - Karteek
   - Pankaj
   - Rahul
   - Ashutosh
3. Set appropriate roles (Member or Maintainer)

## Step 2: Create Base Jekyll Repository

### Create Repository
```bash
# Create the base Jekyll repository
gh repo create accionlabs/stag-notes --private --description "STAG team base Jekyll documentation site"

# Clone the repository
git clone git@github.com:accionlabs/stag-notes.git
cd stag-notes

# Copy your existing Jekyll setup files here
# - _config.yml, Gemfile, _layouts/, _includes/, etc.
# - Copy the updated stag.sh script to the root

# Ensure _docs is gitignored
echo "_docs/" >> .gitignore

# Initial commit
git add .
git commit -m "Initial Jekyll setup with STAG script v3.0"
git push
```

### Set Repository Permissions
```bash
# Give STAG team read access to base repository
gh api repos/accionlabs/stag-notes/teams/stag -X PUT -f permission=pull
```

## Step 3: Create Shared Repository

### Create Empty Repository
```bash
# Create repository manually
gh repo create accionlabs/stag-shared --private --description "STAG team shared resources and templates"

# Give STAG team write access to shared repository
gh api repos/accionlabs/stag-shared/teams/stag -X PUT -f permission=push
```

### Initialize Repository Content
```bash
# Navigate to base repository
cd stag-notes

# Run stag.sh to automatically link the shared repository
./stag.sh

# Now add initial content to the shared repository
cd _docs/shared

# Create structure
mkdir -p templates methodologies research published

# Create README
cat > README.md << 'EOF'
# STAG Shared Resources

Central repository for all STAG team shared content.

## Organization

- [Templates](templates/) - Reusable templates and formats
- [Methodologies](methodologies/) - Consulting frameworks  
- [Research](research/) - Industry insights and analysis
- [Published](published/) - Organization-wide content

## Contributing

Team members can update shared content automatically when they sync:
```bash
./stag.sh
```

## Usage

This repository is automatically synced to all STAG team members' documentation.
EOF

# Go back to main docs directory
cd ..

# The content will be automatically synced on next ./stag.sh run
cd ..
./stag.sh
```

## Step 4: Create Team Configuration

### Create Team Configuration File
```bash
# Navigate to the base Jekyll repository
cd stag-notes

# Create team configuration mapping friendly names to GitHub usernames
cat > .stag-team.json << 'EOF'
{
  "team_members": {
    "saurabh": "saurabh-github-username",
    "hemesh": "hemesh-github-id", 
    "nischal": "nischal123",
    "karteek": "karteek-dev",
    "pankaj": "pankaj-consulting",
    "rahul": "rahul-stag",
    "ashutosh": "ashutosh-real-id"
  }
}
EOF

# Commit team configuration
git add .stag-team.json
git commit -m "Add team configuration for automatic project management"
git push
```

**Important**: Replace the GitHub usernames with the actual GitHub usernames of your team members.

### Verify GitHub Usernames
```bash
# Verify each team member's GitHub username
gh api users/saurabh-github-username
gh api users/hemesh-github-id
# etc...
```

## Step 5: Test Repository Operations

### Test Private Repository Creation
```bash
# Test creating a private repository for a team member
./stag.sh

# Verify repository was created
gh repo view accionlabs/stag-private-$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
```

### Test Project Creation with Team Management
```bash
# Test creating a project with team management
mkdir -p _docs/projects/test-alpha
cat > _docs/projects/test-alpha/index.md << 'EOF'
---
title: "Test Alpha Project"
description: "Test project for STAG system validation"
client: "Test Client"
lead: "saurabh"
team: ["hemesh", "nischal"]
status: "active"
start_date: "2025-01-15"
---

# Test Alpha Project

This is a test project to validate the STAG system.

## Team
- **Lead**: Saurabh
- **Team**: Hemesh, Nischal
EOF

# Run the script to create repository and set permissions
./stag.sh

# Verify repository was created with correct permissions
gh repo view accionlabs/stag-project-test-alpha
gh api repos/accionlabs/stag-project-test-alpha/collaborators
```

### Test Full Workflow
```bash
# Test the full auto-sync workflow
./stag.sh

# Check status
./stag.sh status

# Verify all components work:
# - Private repository created
# - Shared repository linked  
# - Test project created with team permissions

# Clean up test project
rm -rf _docs/projects/test-alpha
gh repo delete accionlabs/stag-project-test-alpha --confirm
```

## Step 6: Share with Team

### Send Setup Instructions to Team
Send team members the main setup guide with these details:

**Base repository URL**: `git@github.com:accionlabs/stag-notes.git`

**Team member onboarding steps**:
1. Clone base repository: `git clone git@github.com:accionlabs/stag-notes.git`
2. Navigate to directory: `cd stag-notes`
3. Install dependencies: `bundle install`
4. Configure git: `git config user.name "[Your Name]"` (must match `.stag-team.json`)
5. Authenticate GitHub: `gh auth login`
6. Run auto-sync: `./stag.sh`
7. Test Jekyll serving: `bundle exec jekyll serve`

### Team Member Onboarding Checklist
- [ ] Verify STAG team membership in AccionLabs
- [ ] Clone base Jekyll repository
- [ ] Install prerequisites (Ruby, Jekyll, GitHub CLI, jq)
- [ ] Configure git user.name to match team configuration
- [ ] Authenticate with GitHub CLI
- [ ] Run `./stag.sh` (creates private repo, links shared, discovers projects)
- [ ] Test Jekyll serving: `bundle exec jekyll serve`
- [ ] Verify access to http://localhost:4000

## Step 7: Project Management

### Creating Client Projects

**Method 1: Let consultants create projects (Recommended)**
1. Consultant creates project folder: `mkdir _docs/projects/alpha-strategy`
2. Consultant creates `index.md` with team info
3. Consultant runs `./stag.sh`
4. Repository and permissions created automatically

**Method 2: Admin pre-creates projects**
```bash
# Create project repository
gh repo create accionlabs/stag-project-alpha-strategy --private --description "STAG project: alpha-strategy"

# Initialize with structure
git clone git@github.com:accionlabs/stag-project-alpha-strategy.git
cd stag-project-alpha-strategy

mkdir -p proposal research presentations deliverables
cat > index.md << 'EOF'
---
title: "Alpha Strategy Project"
description: "Strategy consulting for Alpha Corp"
client: "Alpha Corp"
lead: "saurabh"
team: ["hemesh", "nischal"]
status: "active"
start_date: "2025-01-15"
---

# Alpha Strategy Project
[Project content here]
EOF

git add .
git commit -m "Initial project structure"
git push

cd ..
rm -rf stag-project-alpha-strategy
```

### Managing Project Access

**Automatic method (via index.md):**
- Edit project's `index.md` to change `lead` or `team` fields
- Run `./stag.sh` or ask team member to sync
- Permissions updated automatically

**Manual method (emergency only):**
```bash
# Grant access to project team members
gh api repos/accionlabs/stag-project-[project-name]/collaborators/[username] -X PUT -f permission=push

# Grant admin access to project lead
gh api repos/accionlabs/stag-project-[project-name]/collaborators/[username] -X PUT -f permission=admin

# View project permissions
gh api repos/accionlabs/stag-project-[project-name]/collaborators
```

### Project Naming Convention

| Project Type | Repository Name | Folder Name | Example |
|--------------|----------------|-------------|---------|
| Strategy Consulting | `stag-project-[client]-strategy` | `[client]-strategy` | `stag-project-alpha-strategy` |
| Digital Transformation | `stag-project-[client]-digital` | `[client]-digital` | `stag-project-beta-digital` |
| Technology Assessment | `stag-project-[client]-tech` | `[client]-tech` | `stag-project-gamma-tech` |

## Step 8: Team Configuration Management

### Adding New Team Members

1. **Add to GitHub team:**
   ```bash
   gh api orgs/accionlabs/teams/stag/memberships/[new-username] -X PUT
   ```

2. **Add to team configuration:**
   ```bash
   # Edit .stag-team.json
   {
     "team_members": {
       "existing-member": "existing-github-username",
       "new-member": "new-github-username"
     }
   }
   
   # Commit and push
   git add .stag-team.json
   git commit -m "Add new team member: new-member"
   git push
   ```

3. **Team members get updated config automatically on next sync**

### Removing Team Members

1. **Remove from team configuration:**
   ```bash
   # Edit .stag-team.json to remove the member
   # Commit and push changes
   ```

2. **Remove from GitHub team:**
   ```bash
   gh api orgs/accionlabs/teams/stag/memberships/[username] -X DELETE
   ```

3. **Remove from active projects:**
   - Edit each project's `index.md` to remove from team
   - Or ask project leads to update their teams
   - Permissions will be updated on next sync

### Updating GitHub Usernames

If a team member changes their GitHub username:

1. **Update team configuration:**
   ```bash
   # Edit .stag-team.json
   {
     "team_members": {
       "member-name": "new-github-username"  // Changed
     }
   }
   ```

2. **Commit and push:**
   ```bash
   git add .stag-team.json
   git commit -m "Update GitHub username for member-name"
   git push
   ```

3. **Permissions update automatically on next project sync**

## Step 9: Ongoing Management

### Managing Team Access

```bash
# View team members
gh api orgs/accionlabs/teams/stag/members

# Add new team member to GitHub team
gh api orgs/accionlabs/teams/stag/memberships/[username] -X PUT

# Remove team member from GitHub team
gh api orgs/accionlabs/teams/stag/memberships/[username] -X DELETE

# View all STAG repositories
gh repo list accionlabs --search stag
```

### Repository Maintenance

```bash
# List all STAG repositories
gh repo list accionlabs --search stag

# View repository details and permissions
gh repo view accionlabs/stag-project-[name]
gh api repos/accionlabs/stag-project-[name]/collaborators

# Archive completed projects
gh repo archive accionlabs/stag-project-[completed-project]

# Delete old/test repositories
gh repo delete accionlabs/stag-project-test-alpha --confirm
```

### Monitoring Usage

```bash
# Check repository activity
gh api repos/accionlabs/stag-shared/stats/commit_activity

# View recent commits across all repositories
for repo in $(gh repo list accionlabs --search stag --json name --jq '.[].name'); do
  echo "=== $repo ==="
  gh api repos/accionlabs/$repo/commits --jq '.[0:3][] | "\(.commit.author.date): \(.commit.message)"'
done

# Monitor repository sizes
gh repo list accionlabs --search stag --json name,diskUsage --jq '.[] | "\(.name): \(.diskUsage)KB"'
```

### Team Configuration Validation

```bash
# Validate all team members exist on GitHub
jq -r '.team_members | to_entries[] | .value' .stag-team.json | while read username; do
  if gh api users/$username >/dev/null 2>&1; then
    echo "✓ $username exists"
  else
    echo "✗ $username not found"
  fi
done

# Find team members not in GitHub team
STAG_MEMBERS=$(gh api orgs/accionlabs/teams/stag/members --jq '.[].login' | tr '\n' ' ')
jq -r '.team_members | to_entries[] | .value' .stag-team.json | while read username; do
  if echo "$STAG_MEMBERS" | grep -q "$username"; then
    echo "✓ $username is in STAG team"
  else
    echo "⚠ $username not in STAG GitHub team"
  fi
done
```

## Admin Command Reference

### Repository Management

| Operation | Command | Example |
|-----------|---------|---------|
| **List repositories** | `gh repo list accionlabs --search stag` | `gh repo list accionlabs --search stag-project` |
| **View repository** | `gh repo view accionlabs/[repo]` | `gh repo view accionlabs/stag-shared` |
| **Check permissions** | `gh api repos/accionlabs/[repo]/collaborators` | `gh api repos/accionlabs/stag-project-alpha/collaborators` |
| **Add collaborator** | `gh api repos/[org]/[repo]/collaborators/[user] -X PUT -f permission=[level]` | `gh api repos/accionlabs/stag-project-alpha/collaborators/saurabh -X PUT -f permission=admin` |
| **Remove collaborator** | `gh api repos/[org]/[repo]/collaborators/[user] -X DELETE` | `gh api repos/accionlabs/stag-project-alpha/collaborators/olduser -X DELETE` |

### Team Management

| Operation | Command | Example |
|-----------|---------|---------|
| **List team members** | `gh api orgs/accionlabs/teams/stag/members` | `gh api orgs/accionlabs/teams/stag/members --jq '.[].login'` |
| **Add to team** | `gh api orgs/[org]/teams/[team]/memberships/[user] -X PUT` | `gh api orgs/accionlabs/teams/stag/memberships/newuser -X PUT` |
| **Remove from team** | `gh api orgs/[org]/teams/[team]/memberships/[user] -X DELETE` | `gh api orgs/accionlabs/teams/stag/memberships/olduser -X DELETE` |
| **Check team membership** | `gh api orgs/[org]/teams/[team]/memberships/[user]` | `gh api orgs/accionlabs/teams/stag/memberships/saurabh` |

### Permission Levels

| Level | Description | Access Rights |
|-------|-------------|---------------|
| **pull** | Read-only | Can clone and view repository |
| **push** | Read and write | Can contribute changes |
| **admin** | Full access | Can manage collaborators and settings |

### Repository Types and Access

| Repository Type | Default Access | Who Can Access | Permission Management |
|----------------|----------------|----------------|----------------------|
| **stag-base-jekyll** | STAG team (pull) | All team members | Manual (admin-managed) |
| **stag-shared** | STAG team (push) | All team members | Manual (admin-managed) |
| **stag-private-[name]** | Individual (admin) | Individual consultant only | Manual (auto-created) |
| **stag-project-[name]** | Project team | Project team members | Automatic (index.md managed) |

## Troubleshooting

### Common Admin Issues

**Team member can't access private repository:**
```bash
# Check if private repository exists
gh repo view accionlabs/stag-private-[name]

# If not, team member should run:
./stag.sh
```

**Project access denied:**
```bash
# Check current permissions
gh api repos/accionlabs/stag-project-[name]/collaborators

# Verify team member in project's index.md
# If missing, edit index.md or add manually:
gh api repos/accionlabs/stag-project-[name]/collaborators/[username] -X PUT -f permission=push
```

**Team configuration out of sync:**
```bash
# Verify team config exists and is valid
cat .stag-team.json | jq .

# Check if all members exist on GitHub
jq -r '.team_members | to_entries[] | .value' .stag-team.json | xargs -I {} gh api users/{}

# Force team members to refresh
# Team members should run: ./stag.sh discover
```

**Script permissions error:**
```bash
# Ensure GitHub CLI is authenticated with correct account
gh auth status

# Re-authenticate if needed
gh auth login

# Verify admin access to organization
gh api orgs/accionlabs/memberships/$(gh api user --jq .login)
```

### Security Best Practices

1. **Regular Access Review**: Monthly review of project permissions and team membership
2. **Repository Cleanup**: Remove old/completed project repositories (archive first)
3. **Team Updates**: Keep STAG team membership and configuration current
4. **Audit Logging**: Monitor repository access and changes through GitHub audit logs
5. **Permission Validation**: Regularly validate that project teams match index.md files

### Emergency Procedures

**Revoke access immediately:**
```bash
# Remove from all projects (emergency)
for repo in $(gh repo list accionlabs --search stag-project --json name --jq '.[].name'); do
  gh api repos/accionlabs/$repo/collaborators/[username] -X DELETE
done

# Remove from STAG team
gh api orgs/accionlabs/teams/stag/memberships/[username] -X DELETE
```

**Restore access:**
```bash
# Add back to STAG team
gh api orgs/accionlabs/teams/stag/memberships/[username] -X PUT

# Update team configuration
# Edit .stag-team.json and commit

# Access to projects will be restored on next sync based on index.md files
```

## Backup and Recovery

### Repository Backup
```bash
# Clone all STAG repositories for backup
mkdir stag-backup-$(date +%Y%m%d)
cd stag-backup-$(date +%Y%m%d)

# List and clone all repositories
gh repo list accionlabs --search stag --json name,sshUrl --jq '.[] | .sshUrl' | while read repo_url; do
    git clone "$repo_url"
done

# Backup team configuration
cp ../stag-notes/.stag-team.json ./
```

### Recovery Procedures
1. **Repository restoration**: Re-create from backup clones
2. **Permission restoration**: Re-apply team configuration and project index.md files
3. **Team member recovery**: Re-add to STAG team and update configuration
4. **Project recovery**: Restore project repositories and run permission sync

This completes the admin setup for the STAG documentation system with automatic team management and project creation.