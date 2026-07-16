#!/usr/bin/env ruby
# Scaffolds a new PDF post.
#
# Copies the source PDF into assets/pdfs/<topic>/, creates a dated
# _posts/ markdown file with front matter filled in, and leaves a
# placeholder for the free-form context text that renders alongside
# the embedded viewer.
#
# Usage:
#   ruby script/new_post.rb "Title Of The Note" \
#     --topic calculus \
#     --pdf ~/scans/notes.pdf \
#     [--tags "midterm,chapter-3"] \
#     [--date 2026-07-15]

require "optparse"
require "date"
require "fileutils"

options = { tags: [], date: Date.today.to_s }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/new_post.rb \"Title\" --topic TOPIC --pdf PATH [--tags a,b] [--date YYYY-MM-DD]"
  opts.on("-t TOPIC", "--topic TOPIC", "Topic/category (e.g. calculus, physics, journal)") { |v| options[:topic] = v }
  opts.on("-p PATH", "--pdf PATH", "Path to the source PDF to scaffold a post for") { |v| options[:pdf] = v }
  opts.on("--tags TAGS", "Comma-separated tags (optional)") { |v| options[:tags] = v.split(",").map(&:strip) }
  opts.on("--date DATE", "Post date, YYYY-MM-DD (defaults to today)") { |v| options[:date] = v }
end.parse!

title = ARGV.first
abort "Missing title. Usage: ruby script/new_post.rb \"Title\" --topic TOPIC --pdf PATH" if title.nil? || title.empty?
abort "Missing --topic" unless options[:topic]
abort "Missing --pdf" unless options[:pdf]
abort "PDF not found: #{options[:pdf]}" unless File.exist?(options[:pdf])

repo_root = File.expand_path("..", __dir__)
topic = options[:topic].downcase.strip
slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
date = options[:date]
basename = "#{date}-#{slug}"

pdf_dir = File.join(repo_root, "assets", "pdfs", topic)
pdf_dest = File.join(pdf_dir, "#{basename}.pdf")
post_path = File.join(repo_root, "_posts", "#{basename}.md")

abort "Post already exists: #{post_path}" if File.exist?(post_path)
abort "PDF already exists: #{pdf_dest}" if File.exist?(pdf_dest)

FileUtils.mkdir_p(pdf_dir)
FileUtils.mkdir_p(File.join(repo_root, "_posts"))
FileUtils.cp(options[:pdf], pdf_dest)

# Cover thumbnail: page 1 of the PDF rendered to a PNG, shown in the
# homepage feed (M5) instead of a wall of identical PDF icons. Requires
# pdftoppm (poppler-utils, see docs/DEVELOPMENT.md) — if it's missing,
# skip the cover rather than aborting the whole post; the feed just falls
# back to its placeholder for that post.
cover_dest = File.join(pdf_dir, "#{basename}.png")
cover_front_matter = ""
if system("which pdftoppm > /dev/null 2>&1")
  cover_prefix = File.join(pdf_dir, basename)
  ok = system("pdftoppm", "-png", "-singlefile", "-f", "1", "-l", "1",
              "-scale-to", "600", pdf_dest, cover_prefix)
  if ok && File.exist?(cover_dest)
    cover_front_matter = "cover: /assets/pdfs/#{topic}/#{basename}.png\n"
  else
    warn "pdftoppm failed to render a cover thumbnail; continuing without one."
  end
else
  warn "pdftoppm not found (install poppler-utils); continuing without a cover thumbnail."
end

tags_yaml = options[:tags].empty? ? "[]" : "[#{options[:tags].join(', ')}]"

front_matter = <<~POST
  ---
  layout: pdf-post
  title: "#{title}"
  date: #{date}
  category: #{topic}
  tags: #{tags_yaml}
  pdf: /assets/pdfs/#{topic}/#{basename}.pdf
  #{cover_front_matter}---

  <!-- Context for this note goes here as normal Markdown. It renders
       above the embedded PDF viewer on the post page. Delete this
       comment once you've written something. -->
POST

File.write(post_path, front_matter)

puts "Created post:  #{post_path.sub(repo_root + '/', '')}"
puts "Copied PDF to: #{pdf_dest.sub(repo_root + '/', '')}"
if cover_front_matter.empty?
  puts "No cover thumbnail generated (see warning above)."
else
  puts "Cover image:   #{cover_dest.sub(repo_root + '/', '')}"
end
puts
puts "Next steps:"
puts "  1. Edit the post body to add context text."
puts "  2. bundle exec jekyll serve  # preview locally"
puts "  3. git add, commit, push"
