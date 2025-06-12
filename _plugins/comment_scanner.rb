require 'yaml'
require 'json'

module Jekyll
  class CommentScanner
    def initialize(site)
      @site = site
      @comment_counts = {}
    end

    def scan_all_documents
      Jekyll.logger.info "STAG Comments", "Scanning documents for comments..."
      
      # Scan all docs collection pages (your _docs folder structure)
      docs_pages = @site.collections['docs'] ? @site.collections['docs'].docs : []
      all_pages = @site.pages + docs_pages
      
      all_pages.each do |doc|
        next unless doc.content && ['.md', '.qmd'].include?(doc.extname)
        
        comment_count = count_comments_in_content(doc.content)
        if comment_count > 0
          # Store using multiple path formats for easier lookup
          relative_path = if doc.path.include?('_docs/')
                           doc.path.gsub(/.*_docs\//, '')
                         else
                           doc.path.gsub(@site.source + '/', '')
                         end
          
          @comment_counts[relative_path] = comment_count
          @comment_counts[doc.path] = comment_count
          
          # Also store with URL for easier matching
          if doc.url
            @comment_counts[doc.url] = comment_count
          end
          
          Jekyll.logger.info "STAG Comments", "Found #{comment_count} comments in #{relative_path}"
          Jekyll.logger.debug "STAG Comments", "  - Full path: #{doc.path}"
          Jekyll.logger.debug "STAG Comments", "  - URL: #{doc.url}"
        end
      end
      
      # Store in site data for access in templates
      @site.data['comment_counts'] = @comment_counts
      
      # Debug: Log all comment files found
      Jekyll.logger.info "STAG Comments", "=== COMMENT SUMMARY ==="
      Jekyll.logger.info "STAG Comments", "Found comments in #{@comment_counts.keys.length / 3} documents"
      @comment_counts.each do |path, count|
        next if path.include?('/')  # Skip full paths, just show relative ones
        Jekyll.logger.info "STAG Comments", "  #{path}: #{count} comments"
      end
      Jekyll.logger.info "STAG Comments", "========================"
    end

    private

    def count_comments_in_content(content)
      comment_count = 0
      
      # Count Format A & C: Structured comments (with or without COMMENT: keyword)
      structured_comments = content.scan(/<!--\s*(?:COMMENT:\s*)?\n?((?:.*?:\s*.*?\n)*)\s*---\s*\n(.*?)(?:\n(?:\s*>>.*)*)?\s*-->/m)
      structured_comments.each do |match|
        metadata_text = match[0]
        # Check if this looks like a valid comment (has author: or @author)
        if metadata_text && (metadata_text.include?('author:') || metadata_text.match(/@\w+/))
          comment_count += 1
        end
      end
      
      # Count Format B: Inline comments (@author: content or author: name: content)
      inline_comments = content.scan(/<!--\s*(?:@(\w+)|author:\s*(\w+))(?:\s*\([^)]*\))?:\s*([^-]+?)(?:\n(?:\s*>>.*)*)?-->/m)
      comment_count += inline_comments.length
      
      comment_count
    end
  end

  # Hook to scan documents after site is read but before generation
  Jekyll::Hooks.register :site, :post_read do |site|
    scanner = CommentScanner.new(site)
    scanner.scan_all_documents
  end

  # Liquid filters for use in your existing navigation template
  module CommentFilters
    def comment_count(input)
      @context.registers[:site].data.dig('comment_counts', input) || 0
    end
    
    def has_comments(input)
      comment_count(input) > 0
    end
    
    def comment_indicator(input)
      count = comment_count(input)
      return '' if count == 0
      
      "<span class=\"comment-indicator\" title=\"#{count} comment#{'s' if count != 1} in this document\">💬 #{count}</span>"
    end
    
    # Fixed folder checking - be very specific about what constitutes "in this folder"
    def folder_contains_comments(folder_path)
      site_data = @context.registers[:site].data
      comment_counts = site_data['comment_counts'] || {}
      
      # Normalize folder path - ensure it ends with /
      normalized_folder = folder_path.to_s.chomp('/') + '/'
      
      # Debug output
      Jekyll.logger.debug "STAG Comments", "Checking folder: '#{normalized_folder}'"
      
      # Only check relative paths (not full system paths or URLs)
      relative_paths = comment_counts.keys.select { |path| !path.include?(@context.registers[:site].source) && !path.start_with?('/') }
      
      # Check if any relative path starts with this folder path
      has_comments = relative_paths.any? do |file_path|
        file_path.start_with?(normalized_folder)
      end
      
      Jekyll.logger.debug "STAG Comments", "Folder '#{normalized_folder}' has comments: #{has_comments}"
      if has_comments
        matching_files = relative_paths.select { |path| path.start_with?(normalized_folder) }
        Jekyll.logger.debug "STAG Comments", "  Matching files: #{matching_files.join(', ')}"
      end
      
      has_comments
    end
    
    # Get comment count for a specific document object
    def doc_comment_count(doc)
      return 0 unless doc && doc.path
      
      site_data = @context.registers[:site].data
      comment_counts = site_data['comment_counts'] || {}
      
      # Try multiple path formats to find the comment count
      relative_path = if doc.path.include?('_docs/')
                       doc.path.gsub(/.*_docs\//, '')
                     else
                       doc.path.gsub(@context.registers[:site].source + '/', '')
                     end
      
      # Check in order of preference: relative path, full path, URL
      count = comment_counts[relative_path] || 
              comment_counts[doc.path] || 
              comment_counts[doc.url] || 0
      
      Jekyll.logger.debug "STAG Comments", "Doc lookup for '#{doc.title || doc.name}':"
      Jekyll.logger.debug "STAG Comments", "  - Relative path: '#{relative_path}' -> #{comment_counts[relative_path] || 0}"
      Jekyll.logger.debug "STAG Comments", "  - Full path: '#{doc.path}' -> #{comment_counts[doc.path] || 0}"
      Jekyll.logger.debug "STAG Comments", "  - URL: '#{doc.url}' -> #{comment_counts[doc.url] || 0}"
      Jekyll.logger.debug "STAG Comments", "  - Final count: #{count}"
      
      count
    end
    
    # Check if a document has comments
    def doc_has_comments(doc)
      doc_comment_count(doc) > 0
    end
    
    # Debug filter to see what paths are available
    def debug_comment_paths
      site_data = @context.registers[:site].data
      comment_counts = site_data['comment_counts'] || {}
      
      Jekyll.logger.info "STAG Comments", "=== DEBUG: Available comment paths ==="
      comment_counts.each do |path, count|
        Jekyll.logger.info "STAG Comments", "  '#{path}' -> #{count}"
      end
      Jekyll.logger.info "STAG Comments", "=================================="
      
      ""
    end
  end
end

Liquid::Template.register_filter(Jekyll::CommentFilters)