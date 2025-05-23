module Jekyll
  class MarkdownLinkConverter < Generator
    safe true
    priority :low

    def generate(site)
      site.pages.each do |page|
        # Skip non-markdown files
        next unless page.path.end_with?('.md', '.markdown')
        
        # Replace markdown links with html links
        page.content = page.content.gsub(/\[([^\]]+)\]\(([^)]+)\.md\)/) do |match|
          text = $1
          link = $2
          "[#{text}](#{link}.html)"
        end
      end
    end
  end
end
