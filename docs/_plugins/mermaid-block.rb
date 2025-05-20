module Jekyll
  class MermaidBlockConverter < Converter
    safe true
    priority :low

    def matches(ext)
      ext =~ /^\.md$/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      content.gsub(/```mermaid\n(.*?)```/m, '<div class="mermaid">\1</div>')
             .gsub(/<pre><code class="language-mermaid">(.*?)<\/code><\/pre>/m, '<div class="mermaid">\1</div>')
    end
  end
end
