// index-generator.ts
import * as fs from 'fs';
import * as path from 'path';

// Configuration
const DOCS_DIR = 'docs';
const IGNORE_FILES = ['.DS_Store', 'index.md'];
const SITE_TITLE = 'Documentation Site';

interface Page {
  title: string;
  path: string;
  filename: string;
}

interface Section {
  title: string;
  path: string;
  pages: Page[];
}

// Extract title from markdown file
function extractTitle(filePath: string): string {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const titleMatch = content.match(/^#\s+(.+)$/m);
    if (titleMatch && titleMatch[1]) {
      return titleMatch[1].trim();
    }
    // If no title found, use filename without extension
    return path.basename(filePath, path.extname(filePath));
  } catch (error) {
    console.error(`Error reading file ${filePath}:`, error);
    return path.basename(filePath, path.extname(filePath));
  }
}

// Get all sections and pages
function getSectionsAndPages(): Section[] {
  const sections: Section[] = [];
  
  // Ensure docs directory exists
  if (!fs.existsSync(DOCS_DIR)) {
    fs.mkdirSync(DOCS_DIR);
  }
  
  // Get all sections (directories in docs)
  const sectionDirs = fs.readdirSync(DOCS_DIR, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);
  
  for (const sectionDir of sectionDirs) {
    const sectionPath = path.join(DOCS_DIR, sectionDir);
    const section: Section = {
      title: sectionDir.charAt(0).toUpperCase() + sectionDir.slice(1).replace(/-/g, ' '),
      path: sectionPath,
      pages: []
    };
    
    // Get all markdown files in the section
    const files = fs.readdirSync(sectionPath)
      .filter(file => file.endsWith('.md') && !IGNORE_FILES.includes(file));
    
    for (const file of files) {
      const filePath = path.join(sectionPath, file);
      section.pages.push({
        title: extractTitle(filePath),
        path: filePath,
        filename: file
      });
    }
    
    sections.push(section);
  }
  
  return sections;
}

// Generate index.md for a section
function generateSectionIndex(section: Section): void {
  const indexPath = path.join(section.path, 'index.md');
  let content = `# ${section.title}\n\n`;
  
  // Add links to all pages
  if (section.pages.length > 0) {
    content += '## Pages\n\n';
    for (const page of section.pages) {
      content += `- [${page.title}](./${page.filename})\n`;
    }
  } else {
    content += 'No pages available yet.\n';
  }
  
  content += '\n[Back to Home](../index.md)\n';
  
  fs.writeFileSync(indexPath, content);
  console.log(`Generated index for ${section.title}`);
}

// Generate main index.md
function generateMainIndex(sections: Section[]): void {
  const indexPath = path.join(DOCS_DIR, 'index.md');
  let content = `# ${SITE_TITLE}\n\n`;
  
  if (sections.length > 0) {
    content += '## Sections\n\n';
    for (const section of sections) {
      content += `- [${section.title}](./${path.basename(section.path)}/index.md)\n`;
    }
  } else {
    content += 'No sections available yet.\n';
  }
  
  fs.writeFileSync(indexPath, content);
  console.log('Generated main index');
}

// Main function
function main(): void {
  console.log('Generating indexes...');
  const sections = getSectionsAndPages();
  
  // Generate section indexes
  for (const section of sections) {
    generateSectionIndex(section);
  }
  
  // Generate main index
  generateMainIndex(sections);
  
  console.log('Done!');
}

main();
