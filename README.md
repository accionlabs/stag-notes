# STAG Documentation System

Repository for STAG (Strategy and Technology Advisory Group) documentation using Jekyll for offline viewing.

## Getting Started

This repository contains the base Jekyll setup for STAG team documentation. Each team member maintains their personal documentation in the gitignored `_docs/` folder, which includes private notes, shared resources, and client projects.

### Prerequisites

- [Ruby](https://www.ruby-lang.org/en/documentation/installation/)
- [Bundler](https://bundler.io/)
- [Jekyll](https://jekyllrb.com/docs/installation/)
- [Quarto](https://quarto.org/docs/get-started/) for enhanced document exports
- [ImageMagick](https://imagemagick.org/script/download.php) (optional, for image format conversion)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- SSH access to GitHub

#### Installing Quarto

**macOS:**
```sh
# Install via Homebrew
brew install quarto

# Or download from https://quarto.org/docs/download/
```

**Linux:**
```sh
# Download and install the latest release
wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.549/quarto-1.4.549-linux-amd64.deb
sudo dpkg -i quarto-1.4.549-linux-amd64.deb
```

**Windows:**
Download and run the installer from [Quarto Downloads](https://quarto.org/docs/download/)

#### Installing ImageMagick (Optional)

For automatic WebP/SVG image conversion in document exports:

**macOS:**
```sh
brew install imagemagick
```

**Linux (Ubuntu/Debian):**
```sh
sudo apt-get install imagemagick
```

**Windows:**
Download from [ImageMagick Downloads](https://imagemagick.org/script/download.php#windows)

### Setup Instructions

1. **Clone the repository:**
   ```sh
   git clone git@github.com:accionlabs/stag-base-jekyll.git
   cd stag-base-jekyll
   ```

2. **Install dependencies:**
   ```sh
   bundle install
   ```

3. **Initialize your personal STAG documentation:**
   ```sh
   ./stag.sh init $(whoami)
   ```

4. **Add shared STAG resources:**
   ```sh
   ./stag.sh add-shared stag-shared
   ```

5. **Serve the site locally:**
   ```sh
   bundle exec jekyll serve
   ```
   The site will be available at [http://localhost:4000](http://localhost:4000).

## STAG Documentation Management

### Quick Start Commands

```sh
# Check status of your documentation
./stag.sh status

# Sync with latest shared content and projects
./stag.sh sync

# Add a client project (if you have access)
./stag.sh add-project stag-client-alpha-strategy

# Contribute changes back to shared resources
./stag.sh contribute shared/shared "Added new proposal template"
```

### Documentation Structure

Your personal documentation is organized in the `_docs/` folder:

```
_docs/                          # Your personal documentation (gitignored)
├── private/                    # Private methodologies and insights
│   ├── methodologies/          # Your personal consulting frameworks
│   ├── insights/              # Industry insights and observations
│   └── client-notes/          # Confidential client relationship notes
├── projects/                   # Client projects (via git subtrees)
│   ├── alpha-strategy/        # Client project repositories
│   └── beta-digital/          # Added only if you have access
└── shared/                     # STAG team shared resources
    └── shared/                # Templates, methodologies, research
```

### Creating Documentation

#### Personal Notes
Create markdown files in the appropriate private folders:

```yaml
---
title: "Digital Transformation Methodology"
description: "My approach to digital transformation consulting"
date: 2025-01-15
---

# Digital Transformation Methodology

## Overview
My personal framework for...
```

#### Shared Content
Contribute to shared resources by editing files in `_docs/shared/shared/` and running:

```sh
./stag.sh contribute shared/shared "Description of changes"
```

### STAG Script Commands

#### Setup Commands
- `./stag.sh init [name]` - Initialize personal documentation
- `./stag.sh add-shared [repo]` - Add shared STAG repository
- `./stag.sh add-project [repo]` - Add client project repository

#### Daily Workflow
- `./stag.sh sync` - Sync all repositories with latest changes
- `./stag.sh status` - Show status of your repositories
- `./stag.sh contribute [path] [message]` - Contribute changes back

#### Project Management
- `./stag.sh add-permission [repo] [user] [role]` - Grant repository access
- `./stag.sh list-permissions [repo]` - Show repository collaborators

### Working with Client Projects

When you're added to a client project:

1. **Add the project to your documentation:**
   ```sh
   ./stag.sh add-project stag-client-alpha-strategy
   ```

2. **Work on project files:**
   Edit files in `_docs/projects/alpha-strategy/`

3. **Contribute your changes:**
   ```sh
   ./stag.sh contribute projects/alpha-strategy "Updated risk assessment"
   ```

4. **Sync to get others' changes:**
   ```sh
   ./stag.sh sync
   ```

### Markdown Front Matter

Each markdown file should start with YAML front matter:

```yaml
---
title: "Document Title"
description: "Brief description"
date: 2025-01-15
category: "methodology"  # optional
tags: ["consulting", "strategy"]  # optional
---
```

### Adding Mermaid Diagrams

Include [Mermaid](https://mermaid-js.github.io/) diagrams using fenced code blocks:

    ```mermaid
    graph TD
      A[Current State] --> B{Gap Analysis}
      B --> C[Future State Design]
      B --> D[Implementation Plan]
      C --> E[Final Recommendations]
      D --> E
    ```

## File Organization Tips

### Private Folder Structure
Organize your private content by type:

```
private/
├── methodologies/
│   ├── digital-maturity-assessment.md
│   ├── vendor-selection-framework.md
│   └── change-management-approach.md
├── insights/
│   ├── fintech-industry-trends.md
│   ├── ai-adoption-patterns.md
│   └── regulatory-landscape-2025.md
└── client-notes/
    ├── relationship-mapping.md
    └── engagement-history.md
```

### Shared Content Organization
The team organizes shared content as needed:

```
shared/shared/
├── templates/
│   ├── proposal-templates/
│   └── presentation-templates/
├── methodologies/
│   ├── frameworks/
│   └── assessment-tools/
├── research/
│   ├── industry-analysis/
│   └── competitive-intelligence/
└── published/
    ├── whitepapers/
    └── case-studies/
```

## Security and Confidentiality

- **Private folder**: Never shared, contains your personal methodologies
- **Client projects**: Only accessible to authorized team members
- **Shared resources**: Available to all STAG team members
- **Git history**: All changes are tracked for audit purposes

## Troubleshooting

### Common Issues

**Permission denied when adding projects:**
```sh
# Verify you're in the STAG team
# Contact admin to be added to specific project
```

**Git subtree conflicts:**
```sh
# Reset and re-sync
cd _docs
git fetch origin
git reset --hard origin/main
cd ..
./stag.sh sync
```

**Jekyll not serving _docs content:**
```sh
# Check if _docs is properly configured in _config.yml
# Ensure files have proper front matter
```

### Getting Help

- Check command help: `./stag.sh --help`
- View repository status: `./stag.sh status`
- Contact STAG team leads for access issues

## More Information

- [Jekyll Documentation](https://jekyllrb.com/docs/) for advanced configuration
- [STAG Admin Setup Guide](STAG-ADMIN-SETUP.md) for administrators
- [Git Subtree Documentation](https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging) for advanced usage