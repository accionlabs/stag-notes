// STAG Inline Comments - Pure JavaScript Solution
// No Jekyll plugin required - processes comments client-side

class STAGComments {
  constructor() {
    this.expandedComments = new Set();
    this.teamConfig = {};
    this.commentCounter = 0;
    this.init();
  }

  async init() {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setup());
    } else {
      this.setup();
    }
  }

  async setup() {
    await this.loadTeamConfig();
    this.processComments();
    this.createCommentsSummary();
    this.setupEventListeners();
    this.addGlobalToggleFunction();
  }

  async loadTeamConfig() {
    try {
      const response = await fetch('/.stag-team.json');
      if (response.ok) {
        const config = await response.json();
        this.teamConfig = config.team_members || {};
      }
    } catch (error) {
      console.warn('Could not load team configuration:', error);
      this.teamConfig = {};
    }
  }

  processComments() {
    // Find all HTML comments in the document
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_COMMENT,
      null,
      false
    );

    const comments = [];
    let comment;
    while (comment = walker.nextNode()) {
      comments.push(comment);
    }

    // Process each comment
    comments.forEach(commentNode => {
      const commentText = commentNode.textContent.trim();
      const commentData = this.parseComment(commentText);
      
      if (commentData) {
        this.replaceCommentWithWidget(commentNode, commentData);
      }
    });
  }

  parseComment(commentText) {
    // Format B: Inline comments with intelligent bracket parsing
    // Supports: @author: content, @author(attrs): content, author: content, etc.
    const inlineMatch = commentText.match(/^\s*(?:@(\w+)|author:\s*(\w+))(?:\s*\(([^)]*)\))?:\s*(.+?)(?:\n((?:\s*>>.*)*))?$/s);
    if (inlineMatch) {
      const [, atAuthor, authorAuthor, attributes, content, repliesText] = inlineMatch;
      const author = atAuthor || authorAuthor;
      const parsedAttrs = this.parseInlineAttributes(attributes || '');
      
      return {
        type: 'inline',
        author: author,
        date: parsedAttrs.date || this.getCurrentDate(),
        content: content.trim(),
        replies: this.parseReplies(repliesText || ''),
        commentType: parsedAttrs.type || 'comment',
        title: parsedAttrs.title
      };
    }

    // Format A: Structured comments (with or without COMMENT: keyword)
    // Now supports both "author:" and "@author" in metadata
    const structuredMatch = commentText.match(/^\s*(?:COMMENT:\s*)?\n?((?:.*?:\s*.*?\n)*)\s*---\s*\n(.*?)(?:\n((?:\s*>>.*)*))?$/s);
    if (structuredMatch) {
      const [, metadataText, content, repliesText] = structuredMatch;
      const metadata = this.parseMetadata(metadataText);
      
      if (metadata.author) {
        return {
          type: 'structured',
          author: metadata.author,
          date: metadata.date || this.getCurrentDate(),
          content: content.trim(),
          replies: this.parseReplies(repliesText || ''),
          commentType: metadata.type || 'comment',
          title: metadata.title
        };
      }
    }

    return null;
  }

  parseInlineAttributes(attributeString) {
    if (!attributeString) return {};
    
    const result = {};
    const predefinedTypes = ['question', 'suggestion', 'note', 'action', 'urgent', 'approved', 'blocked', 'todo', 'review', 'clarification'];
    
    // Split by comma and process each attribute
    const parts = attributeString.split(',').map(part => part.trim());
    
    parts.forEach(part => {
      if (!part) return;
      
      // Check if it's a date (various formats)
      if (this.isDateFormat(part)) {
        result.date = this.normalizeDate(part);
      }
      // Check if it's a predefined type
      else if (predefinedTypes.includes(part.toLowerCase())) {
        result.type = part.toLowerCase();
      }
      // Everything else is considered a title
      else {
        // If we already have a title, append with space
        result.title = result.title ? `${result.title} ${part}` : part;
      }
    });
    
    return result;
  }

  isDateFormat(str) {
    // Check various date formats: YYYY-MM-DD, DD-MM-YYYY, MM-DD-YYYY, DD/MM/YYYY, etc.
    const datePatterns = [
      /^\d{4}[-\/]\d{1,2}[-\/]\d{1,2}$/,           // YYYY-MM-DD, YYYY/MM/DD
      /^\d{1,2}[-\/]\d{1,2}[-\/]\d{4}$/,           // DD-MM-YYYY, MM-DD-YYYY, DD/MM/YYYY, MM/DD/YYYY
      /^\d{1,2}[-\/]\d{1,2}[-\/]\d{2}$/,           // DD-MM-YY, MM-DD-YY
      /^\d{4}\.\d{1,2}\.\d{1,2}$/,                 // YYYY.MM.DD
      /^\d{1,2}\.\d{1,2}\.\d{4}$/                  // DD.MM.YYYY
    ];
    
    return datePatterns.some(pattern => pattern.test(str));
  }

  normalizeDate(dateStr) {
    // Try to parse various date formats and return in YYYY-MM-DD format
    let date;
    
    // Handle different separators
    const normalizedStr = dateStr.replace(/[\/\.]/g, '-');
    const parts = normalizedStr.split('-');
    
    if (parts.length === 3) {
      let year, month, day;
      
      // Determine format based on first part length
      if (parts[0].length === 4) {
        // YYYY-MM-DD format
        [year, month, day] = parts;
      } else if (parts[2].length === 4) {
        // DD-MM-YYYY or MM-DD-YYYY format
        // Assume DD-MM-YYYY if day > 12, otherwise ambiguous
        if (parseInt(parts[0]) > 12) {
          [day, month, year] = parts;
        } else if (parseInt(parts[1]) > 12) {
          [month, day, year] = parts;
        } else {
          // Default to DD-MM-YYYY for ambiguous cases
          [day, month, year] = parts;
        }
      } else {
        // Two-digit year, assume current century
        const currentYear = new Date().getFullYear();
        const century = Math.floor(currentYear / 100) * 100;
        const twoDigitYear = parseInt(parts[2]);
        year = century + twoDigitYear;
        
        if (parseInt(parts[0]) > 12) {
          [day, month] = parts;
        } else {
          [month, day] = parts;
        }
      }
      
      // Ensure two-digit month and day
      month = month.toString().padStart(2, '0');
      day = day.toString().padStart(2, '0');
      
      // Validate the date
      date = new Date(year, month - 1, day);
      if (date.getFullYear() == year && date.getMonth() == month - 1 && date.getDate() == day) {
        return `${year}-${month}-${day}`;
      }
    }
    
    // If parsing fails, return original string
    return dateStr;
  }

  parseMetadata(metadataText) {
    const metadata = {};
    const lines = metadataText.trim().split('\n');
    
    lines.forEach(line => {
      // Support both "author: name" and "@author: name" formats
      const match = line.match(/^\s*(?:@(\w+)|(\w+):\s*(.+))$/);
      if (match) {
        if (match[1]) {
          // @author format
          metadata.author = match[1];
        } else {
          // key: value format
          const key = match[2].trim();
          const value = match[3].trim();
          
          if (key === 'author') {
            // Remove @ prefix if present in author value
            metadata[key] = value.replace(/^@/, '');
          } else {
            metadata[key] = value;
          }
        }
      }
    });
    
    return metadata;
  }

  parseReplies(repliesText) {
    if (!repliesText) return [];
    
    const replies = [];
    const lines = repliesText.trim().split('\n');
    let currentReply = null;
    
    lines.forEach(line => {
      // Support both @author and author: formats in replies
      // >> @author(attrs): content or >> author(attrs): content
      const replyMatch = line.match(/^\s*>>\s*(?:@(\w+)|(\w+))(?:\s*\(([^)]*)\))?:\s*(.+)$/);
      if (replyMatch) {
        // Save previous reply
        if (currentReply) {
          replies.push(currentReply);
        }
        
        // Start new reply
        const [, atAuthor, colonAuthor, attributes, content] = replyMatch;
        const author = atAuthor || colonAuthor;
        const parsedAttrs = this.parseInlineAttributes(attributes || '');
        
        currentReply = {
          author: author,
          date: parsedAttrs.date || this.getCurrentDate(),
          content: content.trim(),
          valid_author: this.validateAuthor(author)
        };
      } else if (line.match(/^\s*>>\s*(.+)$/) && currentReply) {
        // Continuation of current reply
        const content = line.match(/^\s*>>\s*(.+)$/)[1];
        currentReply.content += '\n' + content.trim();
      }
    });
    
    // Don't forget the last reply
    if (currentReply) {
      replies.push(currentReply);
    }
    
    return replies;
  }

  validateAuthor(author) {
    if (Object.keys(this.teamConfig).length === 0) return true; // If no config, assume valid
    return this.teamConfig.hasOwnProperty(author) || Object.values(this.teamConfig).includes(author);
  }

  getCurrentDate() {
    return new Date().toISOString().split('T')[0];
  }

  replaceCommentWithWidget(commentNode, commentData) {
    this.commentCounter++;
    const commentId = `stag-comment-${this.commentCounter}`;
    
    const widget = this.createCommentWidget(commentId, commentData);
    
    // Replace the comment node with our widget
    commentNode.parentNode.insertBefore(widget, commentNode);
    commentNode.remove();
  }

  createCommentWidget(commentId, commentData) {
    const widget = document.createElement('div');
    const authorClass = this.validateAuthor(commentData.author) ? 'valid-author' : 'invalid-author';
    const typeClass = commentData.commentType || 'comment';
    const replyCount = commentData.replies.length;
    
    widget.className = `stag-comment-inline ${authorClass} ${typeClass}`;
    widget.id = commentId;
    
    const contentPreview = this.truncateContent(commentData.content, 60);
    const titleText = commentData.title ? `: ${commentData.title}` : '';
    
    widget.innerHTML = `
      <div class="stag-comment-trigger" onclick="toggleComment('${commentId}')">
        <span class="stag-comment-icon">💬</span>
        <span class="stag-comment-preview">
          <strong>${commentData.author}</strong>${titleText} 
          <span class="stag-comment-snippet">${contentPreview}</span>
        </span>
        ${replyCount > 0 ? `<span class="stag-reply-count">${replyCount} ${replyCount === 1 ? 'reply' : 'replies'}</span>` : ''}
        <span class="stag-expand-indicator">▼</span>
      </div>
      
      <div class="stag-comment-content" style="display: none;">
        <div class="stag-comment-main">
          <div class="stag-comment-header">
            <span class="stag-comment-author">${commentData.author}</span>
            <span class="stag-comment-date">${commentData.date}</span>
            ${commentData.commentType !== 'comment' ? `<span class="stag-comment-type ${commentData.commentType}">${commentData.commentType}</span>` : ''}
          </div>
          ${commentData.title ? `<div class="stag-comment-title">${commentData.title}</div>` : ''}
          <div class="stag-comment-body">${this.formatContent(commentData.content)}</div>
        </div>
        
        ${this.generateRepliesHTML(commentData.replies)}
      </div>
    `;
    
    return widget;
  }

  generateRepliesHTML(replies) {
    if (replies.length === 0) return '';
    
    let html = '<div class="stag-comment-replies">';
    replies.forEach(reply => {
      const replyAuthorClass = reply.valid_author ? 'valid-author' : 'invalid-author';
      html += `
        <div class="stag-comment-reply ${replyAuthorClass}">
          <div class="stag-comment-header">
            <span class="stag-comment-author">${reply.author}</span>
            <span class="stag-comment-date">${reply.date}</span>
          </div>
          <div class="stag-comment-body">${this.formatContent(reply.content)}</div>
        </div>
      `;
    });
    html += '</div>';
    
    return html;
  }

  truncateContent(content, maxLength) {
    if (content.length <= maxLength) return content;
    return content.substring(0, maxLength).trim() + '...';
  }

  formatContent(content) {
    // Simple formatting: convert line breaks to <br> and preserve basic structure
    return content.replace(/\n/g, '<br>');
  }

  createCommentsSummary() {
    const commentElements = document.querySelectorAll('.stag-comment-inline');
    const commentCount = commentElements.length;
    
    if (commentCount === 0) return;

    // Find a good place to insert the summary
    const targetElement = document.querySelector('article h1, .stag-document-content h1, main h1, h1') || 
                         document.querySelector('article, .stag-document-content, main, body');
    
    if (!targetElement) return;

    // Create summary indicator with index
    const summary = document.createElement('div');
    summary.className = 'stag-comments-summary';
    
    // Build comment index
    const indexItems = Array.from(commentElements).map((element, index) => {
      const authorElement = element.querySelector('.stag-comment-author');
      const typeElement = element.querySelector('.stag-comment-type');
      const titleElement = element.querySelector('.stag-comment-title');
      const snippetElement = element.querySelector('.stag-comment-snippet');
      
      const author = authorElement ? authorElement.textContent : 'Unknown';
      const type = typeElement ? typeElement.textContent : 'comment';
      const title = titleElement ? titleElement.textContent : 
                   (snippetElement ? snippetElement.textContent.substring(0, 30) + '...' : 'Comment');
      
      return {
        id: element.id,
        author: author,
        type: type,
        title: title,
        index: index + 1
      };
    });

    const indexHTML = indexItems.map(item => `
      <div class="stag-comment-index-item" onclick="stagComments.scrollToComment('${item.id}')">
        <span class="stag-comment-index-item-type">${item.type}</span>
        <span class="stag-comment-index-item-author">${item.author}</span>
        <span class="stag-comment-index-item-title">${item.title}</span>
      </div>
    `).join('');

    summary.innerHTML = `
      <div class="stag-comments-summary-header">
        <span class="stag-comments-summary-icon">💬</span>
        <span class="stag-comments-summary-text">
          This document has ${commentCount} comment${commentCount === 1 ? '' : 's'} from the team.
        </span>
        <div class="stag-comments-summary-actions">
          <button class="stag-comment-action-btn" onclick="stagComments.expandAllComments()">
            Expand All
          </button>
          <button class="stag-comment-action-btn secondary" onclick="stagComments.collapseAllComments()">
            Collapse All
          </button>
        </div>
      </div>
      <div class="stag-comments-index">
        <div class="stag-comments-index-header">Quick Navigation</div>
        <div class="stag-comments-index-list">
          ${indexHTML}
        </div>
      </div>
    `;

    // Insert after the target element
    if (targetElement.tagName === 'H1') {
      targetElement.parentNode.insertBefore(summary, targetElement.nextSibling);
    } else {
      targetElement.insertBefore(summary, targetElement.firstChild);
    }
  }

  scrollToComment(commentId) {
    const commentElement = document.getElementById(commentId);
    if (!commentElement) return;

    // Expand the comment if it's not already expanded
    if (!this.expandedComments.has(commentId)) {
      this.expandComment(commentId);
    }

    // Scroll to the comment with some offset
    setTimeout(() => {
      const rect = commentElement.getBoundingClientRect();
      const offset = window.pageYOffset + rect.top - 80; // 80px offset from top
      
      window.scrollTo({
        top: offset,
        behavior: 'smooth'
      });

      // Add a temporary highlight effect
      commentElement.style.transform = 'scale(1.02)';
      commentElement.style.transition = 'transform 0.3s ease';
      
      setTimeout(() => {
        commentElement.style.transform = '';
      }, 600);
    }, 200);
  }

  setupEventListeners() {
    // Handle keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + Shift + C to toggle all comments
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'C') {
        e.preventDefault();
        this.toggleAllComments();
      }
      
      // Escape to collapse all comments
      if (e.key === 'Escape') {
        this.collapseAllComments();
      }
    });

    // Smooth scrolling when comments are expanded
    document.addEventListener('click', (e) => {
      if (e.target.closest('.stag-comment-trigger')) {
        setTimeout(() => {
          const commentElement = e.target.closest('.stag-comment-inline');
          if (commentElement && this.expandedComments.has(commentElement.id)) {
            commentElement.scrollIntoView({ 
              behavior: 'smooth', 
              block: 'nearest' 
            });
          }
        }, 200);
      }
    });
  }

  addGlobalToggleFunction() {
    // Make functions globally available for onclick handlers
    window.toggleComment = (commentId) => {
      this.toggleComment(commentId);
    };
    
    window.stagComments = {
      expandAllComments: () => this.expandAllComments(),
      collapseAllComments: () => this.collapseAllComments(),
      scrollToComment: (commentId) => this.scrollToComment(commentId),
      toggleComment: (commentId) => this.toggleComment(commentId)
    };
  }

  toggleComment(commentId) {
    const commentElement = document.getElementById(commentId);
    if (!commentElement) return;

    const isExpanded = this.expandedComments.has(commentId);

    if (isExpanded) {
      this.collapseComment(commentId);
    } else {
      this.expandComment(commentId);
    }
  }

  expandComment(commentId) {
    const commentElement = document.getElementById(commentId);
    if (!commentElement) return;

    const contentElement = commentElement.querySelector('.stag-comment-content');
    
    // Add expanded state
    commentElement.classList.add('expanded');
    this.expandedComments.add(commentId);
    
    // Animate expansion
    contentElement.style.display = 'block';
    contentElement.style.opacity = '0';
    contentElement.style.transform = 'translateY(-10px)';
    
    // Use requestAnimationFrame for smooth animation
    requestAnimationFrame(() => {
      contentElement.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
      contentElement.style.opacity = '1';
      contentElement.style.transform = 'translateY(0)';
    });
  }

  collapseComment(commentId) {
    const commentElement = document.getElementById(commentId);
    if (!commentElement) return;

    const contentElement = commentElement.querySelector('.stag-comment-content');
    
    // Animate collapse
    contentElement.style.transition = 'opacity 0.15s ease, transform 0.15s ease';
    contentElement.style.opacity = '0';
    contentElement.style.transform = 'translateY(-5px)';
    
    setTimeout(() => {
      contentElement.style.display = 'none';
      commentElement.classList.remove('expanded');
      this.expandedComments.delete(commentId);
    }, 150);
  }

  expandAllComments() {
    const allComments = document.querySelectorAll('.stag-comment-inline');
    allComments.forEach((comment, index) => {
      // Stagger the expansion for visual effect
      setTimeout(() => {
        this.expandComment(comment.id);
      }, index * 50);
    });
  }

  collapseAllComments() {
    const allComments = document.querySelectorAll('.stag-comment-inline');
    allComments.forEach((comment, index) => {
      // Stagger the collapse for visual effect
      setTimeout(() => {
        this.collapseComment(comment.id);
      }, index * 30);
    });
  }

  toggleAllComments() {
    const expandedCount = this.expandedComments.size;
    const totalCount = document.querySelectorAll('.stag-comment-inline').length;
    
    // If more than half are expanded, collapse all; otherwise expand all
    if (expandedCount > totalCount / 2) {
      this.collapseAllComments();
    } else {
      this.expandAllComments();
    }
  }
}

// Initialize when DOM is ready
const stagComments = new STAGComments();