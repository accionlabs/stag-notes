# STAG Admin Setup Guide
## One-time setup for Strategy and Technology Advisory Group

This guide is for administrators setting up the STAG documentation system for the team.

## Prerequisites

- Admin access to AccionLabs GitHub organization
- GitHub CLI (`gh`) installed and authenticated
- Git configured for SSH access

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
gh repo create accionlabs/stag-base-jekyll --private --description "STAG team base Jekyll documentation site"

# Clone the repository
git clone git@github.com:accionlabs/stag-base-jekyll.git
cd stag-base-jekyll

# Copy your existing Jekyll setup files here
# - _config.yml, Gemfile, _layouts/, _includes/, etc.
# - Copy the stag.sh script to the root

# Ensure _docs is gitignored
echo "_docs/" >> .gitignore

# Initial commit
git add .
git commit -m "Initial Jekyll setup with STAG script"
git push
```

### Set Repository Permissions
```bash
# Give STAG team read access to base repository
gh api repos/accionlabs/stag-base-jekyll/teams/stag -X PUT -f permission=pull
```

## Step 3: Create Shared Repository

### Create Repository Manually
1. Go to https://github.com/organizations/accionlabs/repositories/new
2. **Repository name**: `stag-shared`
3. **Description**: "STAG team shared resources and templates"
4. **Privacy**: Private
5. Click "Create repository"

### Initialize Shared Repository
```bash
# Clone the empty repository
git clone git@github.com:accionlabs/stag-shared.git
cd stag-shared

# Create simple README
cat > README.md << 'EOF'
# STAG Shared Resources

Central repository for all STAG team shared content.

## Usage
This repository is automatically synced to all STAG team members' documentation repositories.

Team members can create folders and organize content as needed:
- Templates and formats
- Methodologies and frameworks  
- Research and insights
- Published materials
- Any other shared resources

## Contributing
To update shared content:
1. Edit files in your local copy
2. Run: `./stag.sh contribute shared/shared "Description of changes"`

## Organization
Create folders as needed to organize content. Common patterns:
- `templates/` - Reusable templates
- `methodologies/` - Consulting frameworks
- `research/` - Industry insights
- `published/` - Organization-wide content
EOF

# Initial commit
git add .
git commit -m "Initial STAG shared repository"
git push

cd ..
```

### Set Shared Repository Permissions
```bash
# Give STAG team write access to shared repository
gh api repos/accionlabs/stag-shared/teams/stag -X PUT -f permission=push
```

## Step 4: Test Admin Functions

### Test Repository Creation (Optional)
```bash
# Test creating a client project repository
gh repo create accionlabs/stag-client-test-project --private --description "Test STAG client project"

# Set up basic project structure
git clone git@github.com:accionlabs/stag-client-test-project.git
cd stag-client-test-project

mkdir -p {proposal,research,presentations,deliverables}
echo "# Test Client Project

## Project Structure
- [Proposal](proposal/) - Initial proposal and scope
- [Research](research/) - Background research and analysis
- [Presentations](presentations/) - Client presentations
- [Deliverables](deliverables/) - Final project deliverables

## Confidentiality Notice
🔒 This repository contains confidential client information.
" > README.md

git add .
git commit -m "Initial test project structure"
git push

cd ..
```

### Test Permission Management
```bash
# Test adding individual access to project
gh api repos/accionlabs/stag-client-test-project/collaborators/saurabh -X PUT -f permission=admin
gh api repos/accionlabs/stag-client-test-project/collaborators/hemesh -X PUT -f permission=push

# Verify permissions
gh api repos/accionlabs/stag-client-test-project/collaborators
```

## Step 5: Share with Team

### Send Setup Instructions to Team
Send team members the main setup guide with these details:

**Base repository URL**: `git@github.com:accionlabs/stag-base-jekyll.git`
**Shared repository**: Available as `stag-shared`
**Team access**: All members added to STAG team in AccionLabs

### Team Member Onboarding Checklist
- [ ] Verify STAG team membership in AccionLabs
- [ ] Clone base Jekyll repository
- [ ] Run `./stag.sh init [name]`
- [ ] Run `./stag.sh add-shared stag-shared`
- [ ] Test Jekyll serving: `bundle exec jekyll serve`

## Step 6: Ongoing Management

### Creating Client Projects
For each new client engagement:

```bash
# Create client project repository
gh repo create accionlabs/stag-client-[client-name]-[project-type] --private --description "STAG client project: [client-name]"

# Grant access to project team members
gh api repos/accionlabs/stag-client-[client-name]-[project-type]/collaborators/[username] -X PUT -f permission=push

# Team members can then add the project:
# ./stag.sh add-project stag-client-[client-name]-[project-type]
```

### Managing Permissions
```bash
# View team members
gh api orgs/accionlabs/teams/stag/members

# Add new team member
gh api orgs/accionlabs/teams/stag/memberships/[username] -X PUT

# Remove team member access to specific project
gh api repos/accionlabs/stag-client-[project]/collaborators/[username] -X DELETE
```

### Repository Cleanup
```bash
# List all STAG repositories
gh repo list accionlabs --search stag

# Delete test/old repositories
gh repo delete accionlabs/stag-client-test-project --confirm
```

## Admin Quick Reference

### Common Commands
```bash
# Create new client project
gh repo create accionlabs/stag-client-[name] --private

# Add user to project
gh api repos/accionlabs/stag-client-[name]/collaborators/[user] -X PUT -f permission=push

# Check team membership
gh api orgs/accionlabs/teams/stag/members

# List STAG repositories
gh repo list accionlabs --search stag
```

### Permission Levels
- **pull**: Read-only access (can clone and view)
- **push**: Read and write access (can contribute)
- **admin**: Full access (can manage collaborators and settings)

This completes the admin setup for the STAG documentation system.