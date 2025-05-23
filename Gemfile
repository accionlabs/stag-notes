source "https://rubygems.org"

# Hello! This is where you manage which Jekyll version is used to run.
gem "jekyll", "~> 4.3.2"

# If you have any plugins, put them here!
group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.12"
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-github-metadata"
  gem "jekyll-remote-theme"
end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]

# Lock jekyll-sass-converter to 2.x on Linux/macOS
gem "jekyll-sass-converter", "~> 2.0"