# _plugins/debug-qmd.rb
# Temporary debug plugin to understand QMD file processing

Jekyll::Hooks.register :site, :after_reset do |site|
  Jekyll.logger.info "Debug", "=== Site Reset ==="
end

Jekyll::Hooks.register :site, :post_read do |site|
  Jekyll.logger.info "Debug", "=== Post Read Hook ==="
  
  # Log all collections
  site.collections.each do |name, collection|
    Jekyll.logger.info "Debug", "Collection: #{name}"
    Jekyll.logger.info "Debug", "  Directory: #{collection.directory}"
    Jekyll.logger.info "Debug", "  Relative Directory: #{collection.relative_directory}"
    
    # Find all files in the collection directory
    if Dir.exist?(collection.directory)
      all_files = Dir.glob(File.join(collection.directory, "**/*"))
      qmd_files = all_files.select { |f| f.end_with?('.qmd') }
      Jekyll.logger.info "Debug", "  Total files: #{all_files.length}"
      Jekyll.logger.info "Debug", "  QMD files found: #{qmd_files.length}"
      qmd_files.each do |file|
        Jekyll.logger.info "Debug", "    - #{file}"
      end
    end
    
    # Check collection docs
    Jekyll.logger.info "Debug", "  Documents in collection: #{collection.docs.length}"
    collection.docs.each do |doc|
      Jekyll.logger.info "Debug", "    - #{doc.relative_path} (#{doc.extname})"
    end
  end
  
  # Check pages
  Jekyll.logger.info "Debug", "Pages: #{site.pages.length}"
  site.pages.select { |p| p.ext == '.qmd' }.each do |page|
    Jekyll.logger.info "Debug", "  QMD Page: #{page.path}"
  end
  
  # Check static files
  qmd_static = site.static_files.select { |f| f.extname == '.qmd' }
  Jekyll.logger.info "Debug", "QMD Static files: #{qmd_static.length}"
  qmd_static.each do |file|
    Jekyll.logger.info "Debug", "  - #{file.path}"
  end
end

Jekyll::Hooks.register :documents, :pre_render do |document|
  if document.extname == '.qmd'
    Jekyll.logger.info "Debug", "Pre-render QMD: #{document.relative_path}"
    Jekyll.logger.info "Debug", "  Output: #{document.output_ext}"
    Jekyll.logger.info "Debug", "  URL: #{document.url}"
    Jekyll.logger.info "Debug", "  Permalink: #{document.permalink}"
  end
end

Jekyll::Hooks.register :documents, :post_render do |document|
  if document.extname == '.qmd'
    Jekyll.logger.info "Debug", "Post-render QMD: #{document.relative_path}"
    Jekyll.logger.info "Debug", "  Output length: #{document.output.length if document.output}"
  end
end