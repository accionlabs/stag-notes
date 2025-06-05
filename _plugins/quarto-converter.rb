require 'digest'
require 'fileutils'
require 'yaml'
require 'json'
require 'securerandom'
require 'pathname'
require 'set'

module Jekyll
  class QuartoConverter < Converter
    safe true
    priority :normal
    
    def initialize(config = {})
      super(config)
      @cache_dir = File.join(config['source'] || '.', '_quarto_cache')
      @quarto_available = check_quarto_installation
      FileUtils.mkdir_p(@cache_dir) if @quarto_available
      Jekyll.logger.info "Quarto", "Converter initialized. Quarto available: #{@quarto_available}"
    end

    def matches(ext)
      ext =~ /^\.qmd$/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      # Get the document context from Jekyll's current conversion context
      current_document = get_current_document(content)
      
      Jekyll.logger.info "Quarto", "Converting: #{current_document ? File.basename(current_document.path) : 'unknown document'}"
      
      # Extract export formats from the document
      export_formats = extract_export_formats(content, current_document)
      
      if @quarto_available
        render_with_quarto(content, export_formats, current_document)
      else
        Jekyll.logger.warn "Quarto", "Quarto not found, falling back to markdown processing"
        render_as_markdown(content)
      end
    end

    # Class method for cache cleaning
    def self.clean_old_cache(cache_dir, max_age_days = 7)
      cutoff_time = Time.now - (max_age_days * 24 * 60 * 60)
      
      Dir.glob(File.join(cache_dir, '*.meta.json')).each do |meta_file|
        begin
          metadata = JSON.parse(File.read(meta_file))
          if Time.at(metadata['timestamp']) < cutoff_time
            hash = metadata['hash']
            [
              File.join(cache_dir, "#{hash}.html"),
              File.join(cache_dir, "#{hash}.meta.json")
            ].each { |f| File.delete(f) if File.exist?(f) }
          end
        rescue
          File.delete(meta_file) if File.exist?(meta_file)
        end
      end
      
      # Clean up old temp directories
      Dir.glob(File.join(cache_dir, 'temp_*')).each do |temp_dir|
        if File.directory?(temp_dir) && File.mtime(temp_dir) < cutoff_time
          FileUtils.rm_rf(temp_dir)
        end
      end
    end

    private

    def get_current_document(content)
      # Use Jekyll's conversion context to find the current document
      site = Jekyll.sites.first
      return nil unless site
      
      # During conversion, Jekyll processes documents in order
      # We can find the current document by checking which one is being processed
      all_docs = site.collections.values.flat_map(&:docs).select { |doc| doc.extname == '.qmd' }
      
      # Find the document with matching content
      # First try exact content match
      current_doc = all_docs.find { |doc| doc.content == content }
      
      # If not found, try matching by content length and frontmatter
      if !current_doc
        content_frontmatter = extract_frontmatter(content)
        if content_frontmatter
          current_doc = all_docs.find do |doc|
            doc.data['title'] == content_frontmatter['title'] &&
            doc.content.length.between?(content.length - 100, content.length + 100)
          end
        end
      end
      
      if current_doc
        Jekyll.logger.debug "Quarto", "Found document: #{File.basename(current_doc.path)}"
      else
        Jekyll.logger.warn "Quarto", "Could not identify current document"
      end
      
      current_doc
    end

    def extract_frontmatter(content)
      if content =~ /^---\s*\n(.*?)\n---\s*\n/m
        begin
          YAML.load($1)
        rescue => e
          Jekyll.logger.warn "Quarto", "Failed to parse frontmatter: #{e.message}"
          nil
        end
      else
        nil
      end
    end

    def extract_export_formats(content, document)
      # Try to get export formats from document data first
      if document && document.data['quarto_exports']
        formats = document.data['quarto_exports']
        formats = [formats] unless formats.is_a?(Array)
        Jekyll.logger.info "Quarto", "Export formats from document: #{formats.inspect}"
        return formats
      end
      
      # Fall back to parsing frontmatter from content
      frontmatter = extract_frontmatter(content)
      if frontmatter && frontmatter['quarto_exports']
        formats = frontmatter['quarto_exports']
        formats = [formats] unless formats.is_a?(Array)
        Jekyll.logger.info "Quarto", "Export formats from frontmatter: #{formats.inspect}"
        return formats
      end
      
      []
    end

    def check_quarto_installation
      system('quarto --version > /dev/null 2>&1')
    rescue
      false
    end

    def render_with_quarto(content, export_formats, document)
      # Use document path in cache key if available
      cache_key_content = content
      if document && document.path
        cache_key_content = "#{document.path}|#{content}"
      end
      cache_key_content += "|exports:#{export_formats.join(',')}"
      
      content_hash = Digest::SHA256.hexdigest(cache_key_content)
      cache_file = File.join(@cache_dir, "#{content_hash}.html")
      metadata_file = File.join(@cache_dir, "#{content_hash}.meta.json")

      # Check if we need to generate exports
      should_generate_exports = export_formats.any? && document && needs_export_generation?(document, export_formats)
      
      # If we need to generate exports or cache is invalid, re-render
      if should_generate_exports || !valid_cache?(cache_file, metadata_file, document, export_formats)
        Jekyll.logger.info "Quarto", "Rendering #{document ? File.basename(document.path) : 'document'}"
        
        begin
          rendered_content = execute_quarto_render(content, export_formats, document)
          
          # Save to cache
          File.write(cache_file, rendered_content)
          File.write(metadata_file, {
            timestamp: Time.now.to_i,
            hash: content_hash,
            exports: export_formats,
            document_path: document ? document.path : nil
          }.to_json)
          
          rendered_content
        rescue => e
          Jekyll.logger.error "Quarto", "Failed to render: #{e.message}"
          Jekyll.logger.error "Quarto", e.backtrace.join("\n")
          render_as_markdown(content)
        end
      else
        Jekyll.logger.debug "Quarto", "Using cached output for #{document ? File.basename(document.path) : 'document'}"
        File.read(cache_file)
      end
    end

    def valid_cache?(cache_file, metadata_file, document, export_formats)
      return false unless File.exist?(cache_file) && File.exist?(metadata_file)
      
      # Check if all expected export files exist
      if document && export_formats.any?
        missing_exports = export_formats.any? do |format|
          export_file = document.path.sub(/\.qmd$/, ".#{format}")
          !File.exist?(export_file)
        end
        
        return false if missing_exports
      end
      
      true
    end

    def needs_export_generation?(document, export_formats)
      return false if export_formats.empty? || !document
      
      source_mtime = File.mtime(document.path)
      
      export_formats.any? do |format|
        export_file = document.path.sub(/\.qmd$/, ".#{format}")
        
        if !File.exist?(export_file)
          Jekyll.logger.info "Quarto", "Export file missing: #{File.basename(export_file)}"
          true
        elsif File.mtime(export_file) < source_mtime
          Jekyll.logger.info "Quarto", "Export file outdated: #{File.basename(export_file)}"
          true
        elsif File.size(export_file) == 0
          Jekyll.logger.info "Quarto", "Export file empty: #{File.basename(export_file)}"
          true
        else
          false
        end
      end
    end

    def execute_quarto_render(content, export_formats, document)
      temp_dir = File.join(@cache_dir, "temp_#{SecureRandom.hex(8)}")
      FileUtils.mkdir_p(temp_dir)
      temp_file = File.join(temp_dir, "document.qmd")
      
      begin
        # Copy assets if document path is available
        if document && document.path
          copy_assets_to_temp(temp_dir, document)
          content = update_image_references(content)
        end
        
        # Preprocess content
        processed_content = preprocess_executable_blocks(content)
        
        # Write content to temp file
        File.write(temp_file, processed_content)
        
        # Change to temp directory for rendering
        original_dir = Dir.pwd
        Dir.chdir(temp_dir)
        
        # Render HTML
        success = system("quarto render document.qmd --to html 2>&1")
        
        if success
          # Generate exports if needed
          if export_formats.any? && document
            generate_exports(temp_dir, export_formats, document)
          end
          
          # Read and return HTML output
          output_file = File.join(temp_dir, "document.html")
          if File.exist?(output_file)
            rendered_html = File.read(output_file)
            extract_body_content(rendered_html)
          else
            raise "HTML output file not found"
          end
        else
          raise "Quarto render failed"
        end
        
      ensure
        Dir.chdir(original_dir) if Dir.pwd != original_dir
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    def generate_exports(temp_dir, formats, document)
      formats.each do |format|
        Jekyll.logger.info "Quarto", "Generating #{format} export for #{File.basename(document.path)}"
        
        cmd = "quarto render document.qmd --to #{format}"
        success = system(cmd)
        
        if success
          export_files = Dir.glob("document.#{format}")
          
          export_files.each do |file|
            source_dir = File.dirname(document.path)
            basename = File.basename(document.path, '.qmd')
            dest_file = File.join(source_dir, "#{basename}.#{format}")
            
            begin
              FileUtils.cp(file, dest_file)
              FileUtils.touch(dest_file, mtime: Time.now + 1)
              Jekyll.logger.info "Quarto", "✓ Created: #{basename}.#{format}"
            rescue => e
              Jekyll.logger.error "Quarto", "Failed to copy export: #{e.message}"
            end
          end
        else
          Jekyll.logger.error "Quarto", "Failed to generate #{format} export"
        end
      end
    end

    def copy_assets_to_temp(temp_dir, document)
      return unless document && document.path
      
      source_dir = File.dirname(document.path)
      asset_patterns = ['img/**/*', 'images/**/*', 'assets/**/*', '*.png', '*.jpg', '*.jpeg', '*.gif', '*.svg', '*.webp']
      
      asset_patterns.each do |pattern|
        Dir.glob(File.join(source_dir, pattern)).each do |asset_file|
          next if File.directory?(asset_file)
          
          relative_path = Pathname.new(asset_file).relative_path_from(Pathname.new(source_dir))
          dest_file = File.join(temp_dir, relative_path)
          
          FileUtils.mkdir_p(File.dirname(dest_file))
          
          file_ext = File.extname(asset_file).downcase
          if ['.webp', '.svg'].include?(file_ext)
            converted_file = dest_file.gsub(/\.(webp|svg)$/i, '.png')
            if convert_image(asset_file, converted_file)
              Jekyll.logger.debug "Quarto", "Converted: #{relative_path}"
            else
              FileUtils.cp(asset_file, dest_file)
            end
          else
            FileUtils.cp(asset_file, dest_file)
          end
        end
      end
    end

    def convert_image(source_file, dest_file)
      conversion_commands = [
        "magick convert '#{source_file}' '#{dest_file}'",
        "convert '#{source_file}' '#{dest_file}'",
        "sips -s format png '#{source_file}' --out '#{dest_file}'"
      ]
      
      conversion_commands.each do |cmd|
        if system(cmd + " 2>/dev/null")
          return true if File.exist?(dest_file)
        end
      end
      
      false
    end

    def update_image_references(content)
      content.gsub(/!\[([^\]]*)\]\(([^)]*\.(webp|svg))\)/i) do |match|
        alt_text = $1
        image_path = $2
        png_path = image_path.gsub(/\.(webp|svg)$/i, '.png')
        "![#{alt_text}](#{png_path})"
      end
    end

    def preprocess_executable_blocks(content)
      executable_types = [
        'mermaid', 'dot', 'plantuml', 'ditaa', 'd2', 'kroki',
        'tikz', 'asymptote', 'metapost', 'xy-pic', 'quarto',
        'observable', 'ojs', 'python', 'r', 'julia', 'sql', 'bash', 'sh'
      ]
      
      pattern = executable_types.join('|')
      
      content.gsub(/^```(#{pattern})(\s*\n)/m) do |match|
        type = $1
        newline = $2
        
        if match =~ /^```\{#{type}\}/
          match
        else
          if ['python', 'r', 'julia', 'sql', 'bash', 'sh'].include?(type)
            next_lines = content[content.index(match)..-1].split("\n")[1..5].join("\n")
            if next_lines =~ /#\|/ || content[content.index(match)-50..content.index(match)] =~ /execute|eval|echo|output/i
              "```{#{type}}#{newline}"
            else
              match
            end
          else
            "```{#{type}}#{newline}"
          end
        end
      end
    end

    def extract_body_content(html)
      if html.include?('<body')
        body_start = html.index(/<body[^>]*>/) 
        body_end = html.rindex('</body>')
        if body_start && body_end
          body_start = html.index('>', body_start) + 1
          return html[body_start...body_end].strip
        end
      end
      html
    end

    def render_as_markdown(content)
      site = Jekyll.sites.first
      if site
        markdown_converter = site.find_converter_instance(Jekyll::Converters::Markdown)
        markdown_converter.convert(content)
      else
        content
      end
    end
  end

  # Hook to clean old cache files
  Jekyll::Hooks.register :site, :after_init do |site|
    cache_dir = File.join(site.source, '_quarto_cache')
    if Dir.exist?(cache_dir)
      Jekyll::QuartoConverter.clean_old_cache(cache_dir)
    end
  end

  # Hook to ensure export files are copied
  Jekyll::Hooks.register :site, :post_write do |site|
    # Log all .qmd files that were processed
    qmd_files = site.collections.values.flat_map(&:docs).select { |doc| doc.extname == '.qmd' }
    
    Jekyll.logger.info "Quarto", "Total .qmd files found: #{qmd_files.length}"
    qmd_files.each do |doc|
      Jekyll.logger.info "Quarto", "  - #{doc.relative_path}"
    end
    
    # Copy export files to destination
    qmd_files.each do |doc|
      if doc.data['quarto_exports']
        doc.data['quarto_exports'].each do |format|
          export_file = doc.path.sub(/\.qmd$/, ".#{format}")
          
          if File.exist?(export_file)
            dest_dir = File.join(site.dest, File.dirname(doc.url))
            dest_file = File.join(dest_dir, File.basename(export_file))
            
            FileUtils.mkdir_p(dest_dir)
            FileUtils.cp(export_file, dest_file)
            Jekyll.logger.info "Quarto", "Copied export: #{File.basename(export_file)} to #{doc.url}"
          end
        end
      end
    end
  end
end