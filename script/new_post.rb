#!/usr/bin/env ruby
# Scaffolds a new post. Pairs a PDF scan with a dated _posts/ markdown
# file by default; pass no --pdf to scaffold a text-only post instead
# (no PDF, no cover thumbnail, plain `post` layout).
#
# Usage:
#   ruby script/new_post.rb "Title Of The Note" \
#     --topic calculus \
#     [--pdf ~/scans/notes.pdf] \
#     [--tags "midterm,chapter-3"] \
#     [--date 2026-07-15]

require "optparse"
require "date"
require "fileutils"

options = { tags: [], date: Date.today.to_s }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/new_post.rb \"Title\" --topic TOPIC [--pdf PATH] [--tags a,b] [--date YYYY-MM-DD]"
  opts.on("-t TOPIC", "--topic TOPIC", "Topic/category (e.g. calculus, physics, journal)") { |v| options[:topic] = v }
  opts.on("-p PATH", "--pdf PATH", "Path to a source PDF to scaffold a post for (optional — omit for a text-only post)") { |v| options[:pdf] = v }
  opts.on("--tags TAGS", "Comma-separated tags (optional)") { |v| options[:tags] = v.split(",").map(&:strip) }
  opts.on("--date DATE", "Post date, YYYY-MM-DD (defaults to today)") { |v| options[:date] = v }
end.parse!

title = ARGV.first
abort "Missing title. Usage: ruby script/new_post.rb \"Title\" --topic TOPIC [--pdf PATH]" if title.nil? || title.empty?
abort "Missing --topic" unless options[:topic]
abort "PDF not found: #{options[:pdf]}" if options[:pdf] && !File.exist?(options[:pdf])

has_pdf = !options[:pdf].nil?

repo_root = File.expand_path("..", __dir__)
topic = options[:topic].downcase.strip
slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
date = options[:date]
basename = "#{date}-#{slug}"

post_path = File.join(repo_root, "_posts", "#{basename}.md")
abort "Post already exists: #{post_path}" if File.exist?(post_path)
FileUtils.mkdir_p(File.join(repo_root, "_posts"))

pdf_dest = nil
cover_dest = nil
cover_generated = false

if has_pdf
  pdf_dir = File.join(repo_root, "assets", "pdfs", topic)
  pdf_dest = File.join(pdf_dir, "#{basename}.pdf")
  abort "PDF already exists: #{pdf_dest}" if File.exist?(pdf_dest)

  FileUtils.mkdir_p(pdf_dir)
  FileUtils.cp(options[:pdf], pdf_dest)

  # Cover thumbnail: page 1 of the PDF rendered to a PNG, shown in the
  # homepage feed (M5) instead of a wall of identical PDF icons. Requires
  # pdftoppm (poppler-utils, see docs/DEVELOPMENT.md) — if it's missing,
  # skip the cover rather than aborting the whole post; the feed just
  # falls back to its placeholder for that post.
  cover_dest = File.join(pdf_dir, "#{basename}.png")
  if system("which pdftoppm > /dev/null 2>&1")
    cover_prefix = File.join(pdf_dir, basename)
    ok = system("pdftoppm", "-png", "-singlefile", "-f", "1", "-l", "1",
                "-scale-to", "600", pdf_dest, cover_prefix)
    cover_generated = ok && File.exist?(cover_dest)
    warn "pdftoppm failed to render a cover thumbnail; continuing without one." unless cover_generated
  else
    warn "pdftoppm not found (install poppler-utils); continuing without a cover thumbnail."
  end
end

tags_yaml = options[:tags].empty? ? "[]" : "[#{options[:tags].join(', ')}]"

front_matter_lines = [
  "layout: #{has_pdf ? 'pdf-post' : 'post'}",
  "title: \"#{title}\"",
  "date: #{date}",
  "category: #{topic}",
  "tags: #{tags_yaml}",
]
front_matter_lines << "pdf: /assets/pdfs/#{topic}/#{basename}.pdf" if has_pdf
front_matter_lines << "cover: /assets/pdfs/#{topic}/#{basename}.png" if cover_generated

body_placeholder = if has_pdf
  "<!-- Context for this note goes here as normal Markdown. It renders\n" \
  "     above the embedded PDF viewer on the post page. Delete this\n" \
  "     comment once you've written something. -->\n"
else
  "<!-- Write this post's content here as normal Markdown. Delete this\n" \
  "     comment once you've written something. -->\n"
end

File.write(post_path, "---\n#{front_matter_lines.join("\n")}\n---\n\n#{body_placeholder}")

puts "Created post:  #{post_path.sub(repo_root + '/', '')}"
if has_pdf
  puts "Copied PDF to: #{pdf_dest.sub(repo_root + '/', '')}"
  if cover_generated
    puts "Cover image:   #{cover_dest.sub(repo_root + '/', '')}"
  else
    puts "No cover thumbnail generated (see warning above)."
  end
else
  puts "No PDF — text-only post (layout: post)."
end
puts
puts "Next steps:"
puts "  1. Edit the post body to add context text."
puts "  2. bundle exec jekyll serve  # preview locally"
puts "  3. git add, commit, push"
