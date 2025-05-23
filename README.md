# markdown-notes

Repository of Notes in Markdown

## Getting Started

This repository contains markdown notes and is set up to be served as a static site using [Jekyll](https://jekyllrb.com/).

### Prerequisites

- [Ruby](https://www.ruby-lang.org/en/documentation/installation/)
- [Bundler](https://bundler.io/)
- [Jekyll](https://jekyllrb.com/docs/installation/)

### Setup Instructions

1. **Clone the repository:**
   ```sh
   git clone https://github.com/bijoor/markdown-notes.git
   cd markdown-notes
   ```

2. **Install dependencies:**
   ```sh
   bundle install
   ```

3. **Serve the site locally:**
   ```sh
   bundle exec jekyll serve
   ```
   The site will be available at [http://localhost:4000](http://localhost:4000).

### Creating Markdown Notes

Your notes will be stored as markdown files in the `_docs/` folder. You can create sub-folders within this to organize your notes files.

Each markdown file must start with a YAML front matter block to be recognized by Jekyll. For example:

```yaml
---
title: "My Note Title"
description: "Description of the file"
date: 2025-05-23
---
```

- `title`: The title of your note
- `description`: Description of your note
- `date`: (Optional) The date for posts (required in `_posts/`)

Write your markdown content below the front matter.  

Please note that any markdown folder that contains files without front matter will not be shown.

### Adding Mermaid Diagrams

You can include [Mermaid](https://mermaid-js.github.io/) diagrams in your markdown files using fenced code blocks with `mermaid` as the language. For example:

    ```mermaid
    graph TD
      A[Start] --> B{Is it working?}
      B -- Yes --> C[Great!]
      B -- No --> D[Check your code]
    ```

When the site is built and viewed in the browser, these code blocks will be rendered as diagrams.

### More Information

See [Jekyll Documentation](https://jekyllrb.com/docs/) for advanced configuration.