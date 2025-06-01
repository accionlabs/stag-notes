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
      @current_document_path = nil
      Jekyll.logger.info "Quarto", "Converter initialized. Quarto available: #{@quarto_available}"
    end

    def matches(ext)
      ext =~ /^\.qmd$/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      Jekyll.logger.info "Quarto", "Convert method called"
      
      # Try to get the document from the site context
      site = Jekyll.sites.first
      current_doc = nil
      export_formats = []
      
      if site
        # Search through all documents to find the current one
        all_docs = site.collections.values.flat_map(&:docs)
        current_doc = all_docs.find { |doc| doc.extname == '.qmd' && doc.content == content }
        
        if current_doc
          @current_document_path = current_doc.path
          export_formats = current_doc.data['quarto_exports'] || []
          Jekyll.logger.info "Quarto", "Found document: #{File.basename(@current_document_path)} with exports: #{export_formats.inspect}"
        else
          Jekyll.logger.warn "Quarto", "Could not find current document in site.collections"
        end
      end
      
      # Fallback: try to extract exports from frontmatter in content
      if export_formats.empty? && content =~ /^---\s*\n(.*?)\n---\s*\n/m
        begin
          frontmatter = YAML.load($1)
          export_formats = frontmatter['quarto_exports'] || []
          Jekyll.logger.info "Quarto", "Extracted exports from content frontmatter: #{export_formats.inspect}"
        rescue => e
          Jekyll.logger.warn "Quarto", "Failed to parse frontmatter: #{e.message}"
        end
      end
      
      if @quarto_available
        render_with_quarto(content, export_formats)
      else
        Jekyll.logger.warn "Quarto", "Quarto not found, falling back to markdown processing"
        render_as_markdown(content)
      end
    end

    private

    def check_quarto_installation
      system('quarto --version > /dev/null 2>&1')
    rescue
      false
    end

    def render_with_quarto(content, export_formats = [])
      # Only generate exports if they don't already exist or if content has changed
      should_generate_exports = export_formats.any? && needs_export_generation?(content, export_formats)
      
      # Use cache for HTML generation
      content_hash = Digest::SHA256.hexdigest(content)
      cache_file = File.join(@cache_dir, "#{content_hash}.html")
      metadata_file = File.join(@cache_dir, "#{content_hash}.meta.json")

      if File.exist?(cache_file) && File.exist?(metadata_file) && !should_generate_exports
        Jekyll.logger.debug "Quarto", "Using cached output"
        return File.read(cache_file)
      end

      Jekyll.logger.info "Quarto", "Rendering #{File.basename(@current_document_path || 'document')}"
      
      begin
        rendered_content = execute_quarto_render(content, should_generate_exports ? export_formats : [])
        
        File.write(cache_file, rendered_content)
        File.write(metadata_file, {
          timestamp: Time.now.to_i,
          hash: content_hash
        }.to_json)
        
        rendered_content
      rescue => e
        Jekyll.logger.error "Quarto", "Failed to render with Quarto: #{e.message}"
        Jekyll.logger.error "Quarto", e.backtrace.join("\n")
        render_as_markdown(content)
      end
    end

    def needs_export_generation?(content, export_formats)
      return false if export_formats.empty? || !@current_document_path
      
      # Check if export files exist and are newer than the source
      source_mtime = File.mtime(@current_document_path)
      
      export_formats.any? do |format|
        export_file = @current_document_path.sub(/\.qmd$/, ".#{format}")
        !File.exist?(export_file) || File.mtime(export_file) < source_mtime
      end
    end

    def execute_quarto_render(content, export_formats)
      temp_dir = File.join(@cache_dir, "temp_#{SecureRandom.hex(8)}")
      FileUtils.mkdir_p(temp_dir)
      temp_file = File.join(temp_dir, "document.qmd")
      
      begin
        # Copy images and other assets to temp directory if document path is available
        if @current_document_path
          copy_assets_to_temp(temp_dir)
          # Update content to reference converted image formats
          content = update_image_references(content)
        end
        
        # Preprocess content to support both standard markdown and Quarto syntaxes
        processed_content = preprocess_executable_blocks(content)
        
        File.write(temp_file, processed_content)
        
        # Render HTML first
        original_dir = Dir.pwd
        Dir.chdir(temp_dir)
        
        Jekyll.logger.info "Quarto", "Executing: quarto render document.qmd --to html"
        success = system("quarto render document.qmd --to html > /dev/null 2>&1")
        
        if success && export_formats.any?
          Jekyll.logger.info "Quarto", "HTML render successful, generating exports: #{export_formats.inspect}"
          generate_exports(temp_dir, export_formats)
        elsif !success
          Jekyll.logger.error "Quarto", "HTML render failed"
        elsif export_formats.empty?
          Jekyll.logger.debug "Quarto", "No export formats specified"
        end
        
        Dir.chdir(original_dir)
        
        output_file = File.join(temp_dir, "document.html")
        if File.exist?(output_file)
          rendered_html = File.read(output_file)
          extract_body_content(rendered_html)
        else
          raise "HTML output file not found"
        end
        
      ensure
        Dir.chdir(original_dir) if Dir.pwd != original_dir
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    def generate_exports(temp_dir, formats)
      formats.each do |format|
        Jekyll.logger.info "Quarto", "Generating #{format} export"
        
        # Run quarto with output visible for debugging
        cmd = "quarto render document.qmd --to #{format}"
        Jekyll.logger.info "Quarto", "Executing: #{cmd}"
        
        success = system(cmd)
        
        if success
          # Look for files with the expected extension
          export_files = Dir.glob("document.#{format}")
          Jekyll.logger.info "Quarto", "Found export files: #{export_files.inspect}"
          
          # Copy files to source directory
          export_files.each do |file|
            if @current_document_path
              source_dir = File.dirname(@current_document_path)
              basename = File.basename(@current_document_path, '.qmd')
              dest_file = File.join(source_dir, "#{basename}.#{format}")
              
              Jekyll.logger.info "Quarto", "Copying #{file} to #{dest_file}"
              
              begin
                FileUtils.cp(file, dest_file)
                file_size = File.size(dest_file)
                Jekyll.logger.info "Quarto", "✓ Export created: #{basename}.#{format} (#{file_size} bytes)"
                
                # Touch the source file's mtime to be older than export
                # This prevents the export from triggering regeneration
                FileUtils.touch(dest_file, mtime: Time.now + 1)
              rescue => e
                Jekyll.logger.error "Quarto", "Error copying export: #{e.message}"
              end
            else
              Jekyll.logger.warn "Quarto", "No current document path available for export copy"
            end
          end
        else
          Jekyll.logger.error "Quarto", "Failed to generate #{format} export"
        end
      end
    end

    def copy_assets_to_temp(temp_dir)
      return unless @current_document_path
      
      source_dir = File.dirname(@current_document_path)
      
      # Look for common asset directories and files
      asset_patterns = ['img/**/*', 'images/**/*', 'assets/**/*', '*.png', '*.jpg', '*.jpeg', '*.gif', '*.svg', '*.webp']
      
      asset_patterns.each do |pattern|
        Dir.glob(File.join(source_dir, pattern)).each do |asset_file|
          next if File.directory?(asset_file)
          
          # Calculate relative path from source directory
          relative_path = Pathname.new(asset_file).relative_path_from(Pathname.new(source_dir))
          dest_file = File.join(temp_dir, relative_path)
          
          # Create destination directory if it doesn't exist
          FileUtils.mkdir_p(File.dirname(dest_file))
          
          # Check if we need to convert the image format
          file_ext = File.extname(asset_file).downcase
          if ['.webp', '.svg'].include?(file_ext)
            # Convert to PNG for better LaTeX compatibility
            converted_file = dest_file.gsub(/\.(webp|svg)$/i, '.png')
            if convert_image(asset_file, converted_file)
              Jekyll.logger.debug "Quarto", "Converted: #{relative_path}"
            else
              # If conversion fails, copy original
              FileUtils.cp(asset_file, dest_file)
            end
          else
            # Copy directly for supported formats
            FileUtils.cp(asset_file, dest_file)
          end
        end
      end
    end

    def convert_image(source_file, dest_file)
      # Try different image conversion tools
      conversion_commands = [
        "magick convert '#{source_file}' '#{dest_file}'", # ImageMagick 7+
        "convert '#{source_file}' '#{dest_file}'",        # ImageMagick 6
        "sips -s format png '#{source_file}' --out '#{dest_file}'", # macOS built-in
      ]
      
      conversion_commands.each do |cmd|
        if system(cmd + " 2>/dev/null")
          return true if File.exist?(dest_file)
        end
      end
      
      false
    end

    def update_image_references(content)
      # Replace references to webp and svg files with png equivalents for LaTeX compatibility
      content.gsub(/!\[([^\]]*)\]\(([^)]*\.(webp|svg))\)/i) do |match|
        alt_text = $1
        image_path = $2
        png_path = image_path.gsub(/\.(webp|svg)$/i, '.png')
        "![#{alt_text}](#{png_path})"
      end
    end

    def preprocess_mermaid_blocks(content)
      # Convert standard markdown mermaid blocks to Quarto syntax
      # This regex looks for ```mermaid blocks (without {})
      content.gsub(/^```mermaid\s*$/m, '```{mermaid}')
    end

    def preprocess_executable_blocks(content)
      # List of executable block types that Quarto supports
      # These are diagram/visualization formats that need the {type} syntax
      executable_types = [
        'mermaid',      # Flow charts and diagrams
        'dot',          # Graphviz diagrams
        'plantuml',     # PlantUML diagrams
        'ditaa',        # ASCII art diagrams
        'd2',           # D2 diagrams
        'kroki',        # Kroki diagram gateway
        'tikz',         # TikZ diagrams
        'asymptote',    # Asymptote diagrams
        'metapost',     # MetaPost diagrams
        'xy-pic',       # XY-pic diagrams
        'quarto',       # Quarto-specific blocks
        'observable',   # Observable JS
        'ojs',          # Observable JS shorthand
        'python',       # Python code blocks (when executable)
        'r',            # R code blocks (when executable)
        'julia',        # Julia code blocks (when executable)
        'sql',          # SQL code blocks (when executable)
        'bash',         # Bash/shell scripts (when executable)
        'sh',           # Shell scripts (when executable)
      ]
      
      # Create a regex pattern for all supported types
      pattern = executable_types.join('|')
      
      # Convert standard markdown blocks to Quarto executable syntax
      # This handles blocks like ```mermaid to ```{mermaid}
      processed = content.gsub(/^```(#{pattern})(\s*\n)/m) do |match|
        type = $1
        newline = $2
        
        # Check if it already has Quarto syntax
        if match =~ /^```\{#{type}\}/
          match  # Already in Quarto format, leave as-is
        else
          # For code blocks (python, r, julia, etc.), only convert if they have execution hints
          if ['python', 'r', 'julia', 'sql', 'bash', 'sh'].include?(type)
            # Look ahead to see if this block has execution markers like #| echo: true
            next_lines = content[content.index(match)..-1].split("\n")[1..5].join("\n")
            if next_lines =~ /#\|/ || content[content.index(match)-50..content.index(match)] =~ /execute|eval|echo|output/i
              "```{#{type}}#{newline}"
            else
              match  # Regular code block, don't convert
            end
          else
            # Diagram/visualization blocks always get converted
            "```{#{type}}#{newline}"
          end
        end
      end
      
      processed
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

  Jekyll::Hooks.register :site, :after_init do |site|
    cache_dir = File.join(site.source, '_quarto_cache')
    clean_old_cache(cache_dir) if Dir.exist?(cache_dir)
  end

  # Hook to ensure export files are copied to _site
  Jekyll::Hooks.register :site, :post_read do |site|
    # Find all .qmd files and their potential exports
    qmd_files = site.collections.values.flat_map(&:docs).select { |doc| doc.extname == '.qmd' }
    
    qmd_files.each do |doc|
      if doc.data['quarto_exports']
        doc.data['quarto_exports'].each do |format|
          export_file = doc.path.sub(/\.qmd$/, ".#{format}")
          
          if File.exist?(export_file)
            # Calculate relative path
            relative_dir = File.dirname(doc.relative_path)
            
            # Create a StaticFile for the export
            static_file = Jekyll::StaticFile.new(
              site,
              site.source,
              relative_dir,
              File.basename(export_file)
            )
            
            # Add to site's static files if not already present
            unless site.static_files.any? { |f| f.path == static_file.path }
              site.static_files << static_file
              Jekyll.logger.info "Quarto", "Registered export file for copying: #{File.basename(export_file)}"
            end
          end
        end
      end
    end
  end

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
  end
end