require 'digest'
require 'fileutils'
require 'yaml'
require 'json'
require 'securerandom'
require 'pathname'

module Jekyll
  class QuartoConverter < Converter
    safe true
    priority :normal
    
    # Initialize class variable
    @@current_qmd_document = nil
    
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
      # Get export formats from the current document being processed
      export_formats = []
      if @@current_qmd_document
        export_formats = @@current_qmd_document.data['quarto_exports'] || []
        @current_document_path = @@current_qmd_document.path
        Jekyll.logger.info "Quarto", "Processing: #{File.basename(@current_document_path)} with exports: #{export_formats.inspect}" if export_formats.any?
      end
      
      if @quarto_available
        render_with_quarto(content, export_formats)
      else
        Jekyll.logger.warn "Quarto", "Quarto not found, falling back to markdown processing"
        render_as_markdown(content)
      end
    end

    def current_document_path=(path)
      @current_document_path = path
    end
    
    def current_document_path
      @current_document_path
    end

    private

    def check_quarto_installation
      system('quarto --version > /dev/null 2>&1')
    rescue
      false
    end

    def render_with_quarto(content, export_formats = [])
      # Include export formats in cache key so cache is invalidated when exports change
      content_with_exports = content + export_formats.to_s
      content_hash = Digest::SHA256.hexdigest(content_with_exports)
      cache_file = File.join(@cache_dir, "#{content_hash}.html")
      metadata_file = File.join(@cache_dir, "#{content_hash}.meta.json")

      if File.exist?(cache_file) && File.exist?(metadata_file) && export_formats.empty?
        Jekyll.logger.debug "Quarto", "Using cached output"
        return File.read(cache_file)
      end

      Jekyll.logger.info "Quarto", "Rendering #{File.basename(@current_document_path || 'document')}"
      
      begin
        rendered_content = execute_quarto_render(content, export_formats)
        
        File.write(cache_file, rendered_content)
        File.write(metadata_file, {
          timestamp: Time.now.to_i,
          hash: content_hash
        }.to_json)
        
        rendered_content
      rescue => e
        Jekyll.logger.error "Quarto", "Failed to render with Quarto: #{e.message}"
        render_as_markdown(content)
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
        
        File.write(temp_file, content)
        
        # Render HTML first
        original_dir = Dir.pwd
        Dir.chdir(temp_dir)
        
        success = system("quarto render document.qmd --to html > /dev/null 2>&1")
        
        if success && export_formats.any?
          generate_exports(temp_dir, export_formats)
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
        
        success = system("quarto render document.qmd --to #{format} > /dev/null 2>&1")
        
        if success
          # Look for files with the expected extension
          export_files = Dir.glob("document.#{format}")
          
          # Copy files to source directory
          export_files.each do |file|
            if @current_document_path
              source_dir = File.dirname(@current_document_path)
              basename = File.basename(@current_document_path, '.qmd')
              dest_file = File.join(source_dir, "#{basename}.#{format}")
              
              begin
                FileUtils.cp(file, dest_file)
                file_size = File.size(dest_file)
                Jekyll.logger.info "Quarto", "✓ Export created: #{basename}.#{format} (#{file_size} bytes)"
              rescue => e
                Jekyll.logger.error "Quarto", "Error copying export: #{e.message}"
              end
            end
          end
        else
          Jekyll.logger.warn "Quarto", "Failed to generate #{format} export"
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

  # Global storage for current document being processed
  @@current_qmd_document = nil

  Jekyll::Hooks.register :documents, :pre_render do |document|
    if document.extname == '.qmd'
      @@current_qmd_document = document
    end
  end

  Jekyll::Hooks.register :pages, :pre_render do |page|
    if page.extname == '.qmd'
      @@current_qmd_document = page
    end
  end

  Jekyll::Hooks.register :site, :after_init do |site|
    cache_dir = File.join(site.source, '_quarto_cache')
    clean_old_cache(cache_dir) if Dir.exist?(cache_dir)
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