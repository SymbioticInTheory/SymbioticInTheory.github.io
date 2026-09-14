#!/usr/bin/env ruby
# Scaffolds new posts. Pairs a scanned PDF with a dated _posts/ markdown
# file. Three modes:
#
#   * one PDF          --pdf PATH        (title from the positional arg)
#   * a whole folder   --pdf-dir DIR     (one post per PDF; title from each
#                                          filename, humanized)
#   * text-only        (neither flag)    (no PDF, plain `post` layout)
#
# A post's --topic is its browsable category (folder-mirrored on disk under
# assets/pdfs/<topic>/ and shown at /categories/<topic>/). An optional
# --subcategory nests one level deeper: files go to
# assets/pdfs/<topic>/<subcategory>/, the URL becomes
# /<topic>/<subcategory>/..., and the topic's browse page groups it into its
# own section.
#
# Topics and subcategories may be several words long — quote them. The name
# is slugified for the front matter, URL, and folder ("Linear Algebra" ->
# linear-algebra), and recorded as typed in _data/categories.yml so the site
# displays it properly. See script/categories.rb.
#
# Usage:
#   # single PDF
#   ruby script/new_post.rb "Title Of The Note" \
#     --topic "Linear Algebra" [--subcategory "Vector Spaces"] \
#     --pdf ~/scans/notes.pdf [--tags "midterm,chapter-3"] [--date 2026-07-15]
#
#   # a whole directory of PDFs -> one post each
#   ruby script/new_post.rb --topic calculus [--subcategory derivatives] \
#     --pdf-dir ~/scans/calc-unit-1/ [--tags "midterm"] [--date 2026-07-15]
#
#   # text-only post
#   ruby script/new_post.rb "A Written Note" --topic journal

require "optparse"
require "date"
require "fileutils"
require "open3"
require_relative "categories"

# Raised for a problem with a single post so batch mode can skip that one
# file and carry on rather than aborting the whole run.
class PostError < StandardError; end

options = { tags: [], date: Date.today.to_s }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/new_post.rb [\"Title\"] --topic TOPIC [--subcategory SUB] [--pdf PATH | --pdf-dir DIR] [--tags a,b] [--date YYYY-MM-DD]"
  opts.on("-t TOPIC", "--topic TOPIC", "Topic/category (e.g. calculus, \"Linear Algebra\")") { |v| options[:topic] = v }
  opts.on("-s SUB", "--subcategory SUB", "Optional subcategory nested under the topic (may be several words)") { |v| options[:subcategory] = v }
  opts.on("-p PATH", "--pdf PATH", "Path to a single source PDF (optional — omit for a text-only post)") { |v| options[:pdf] = v }
  opts.on("-d DIR", "--pdf-dir DIR", "Directory of PDFs — scaffolds one post per PDF (title from each filename)") { |v| options[:pdf_dir] = v }
  opts.on("--tags TAGS", "Comma-separated tags (optional; applied to every post in --pdf-dir mode)") { |v| options[:tags] = v.split(",").map(&:strip) }
  opts.on("--date DATE", "Post date, YYYY-MM-DD (defaults to today; applied to every post in --pdf-dir mode)") { |v| options[:date] = v }
end.parse!

abort "Missing --topic" unless options[:topic]
abort "Pass either --pdf or --pdf-dir, not both." if options[:pdf] && options[:pdf_dir]

repo_root = File.expand_path("..", __dir__)
# Slugs are what go in the front matter, the URL, and the folder names; the
# names as typed are recorded in _data/categories.yml for the site to display.
begin
  topic, subcategory = Categories.resolve(repo_root, topic: options[:topic],
                                                     subcategory: options[:subcategory])
rescue ArgumentError => e
  abort e.message
end
# Path segment under assets/pdfs/ — nested when a subcategory is present.
cat_seg = subcategory ? "#{topic}/#{subcategory}" : topic

# Turn a PDF filename into a human-readable post title:
#   "gradient_descent-notes.pdf" -> "Gradient Descent Notes"
def humanize(path)
  File.basename(path, ".*")
      .gsub(/[_\-]+/, " ")
      .gsub(/[^a-zA-Z0-9]+/, " ")
      .split
      .map(&:capitalize)
      .join(" ")
end

def slugify(title)
  Categories.slugify(title)
end

def pdf_page_count(path)
  output, status = Open3.capture2e("pdfinfo", path)
  raise PostError, "pdfinfo could not read #{path}: #{output.strip}" unless status.success?

  pages = output[/^Pages:\s+(\d+)/, 1]
  raise PostError, "pdfinfo did not report a page count for #{path}." unless pages

  pages.to_i
rescue Errno::ENOENT
  raise PostError, "pdfinfo not found (install poppler-utils before adding a PDF)."
end

# Creates one post (markdown file + optional PDF/cover). Raises PostError on
# any problem so the caller decides whether to abort or skip. Returns a hash
# of the paths it wrote, for the summary line.
def create_post(repo_root:, title:, topic:, subcategory:, cat_seg:, pdf:, tags:, date:)
  raise PostError, "Empty title." if title.nil? || title.strip.empty?
  raise PostError, "PDF not found: #{pdf}" if pdf && !File.exist?(pdf)

  has_pdf = !pdf.nil?
  page_count = pdf_page_count(pdf) if has_pdf
  slug = slugify(title)
  raise PostError, "Title '#{title}' slugifies to nothing usable." if slug.empty?
  basename = "#{date}-#{slug}"

  post_path = File.join(repo_root, "_posts", "#{basename}.md")
  raise PostError, "Post already exists: #{post_path}" if File.exist?(post_path)
  FileUtils.mkdir_p(File.join(repo_root, "_posts"))

  pdf_dest = nil
  cover_dest = nil
  cover_generated = false

  if has_pdf
    pdf_dir = File.join(repo_root, "assets", "pdfs", cat_seg)
    pdf_dest = File.join(pdf_dir, "#{basename}.pdf")
    raise PostError, "PDF already exists: #{pdf_dest}" if File.exist?(pdf_dest)

    FileUtils.mkdir_p(pdf_dir)
    FileUtils.cp(pdf, pdf_dest)

    # Cover thumbnail: page 1 of the PDF rendered to a PNG, shown in the
    # homepage feed (M5) instead of a wall of identical PDF icons. Requires
    # pdftoppm (poppler-utils, see docs/DEVELOPMENT.md) — if it's missing,
    # skip the cover rather than failing the post; the feed just falls back
    # to its placeholder for that post.
    cover_dest = File.join(pdf_dir, "#{basename}.png")
    if system("which pdftoppm > /dev/null 2>&1")
      cover_prefix = File.join(pdf_dir, basename)
      ok = system("pdftoppm", "-png", "-singlefile", "-f", "1", "-l", "1",
                  "-scale-to", "600", pdf_dest, cover_prefix)
      cover_generated = ok && File.exist?(cover_dest)
      warn "  pdftoppm failed to render a cover for #{basename}; continuing without one." unless cover_generated
    else
      warn "  pdftoppm not found (install poppler-utils); continuing without a cover thumbnail."
    end
  end

  tags_yaml = tags.empty? ? "[]" : "[#{tags.join(', ')}]"

  front_matter_lines = [
    "layout: #{has_pdf ? 'pdf-post' : 'post'}",
    "title: \"#{title}\"",
    "date: #{date}",
  ]
  # A subcategory needs both levels in the URL, so it goes in the plural
  # `categories` list (the permalink's :categories placeholder expands it to
  # /topic/subcategory/...). Without one, keep the simpler singular form.
  front_matter_lines << if subcategory
    "categories: [#{topic}, #{subcategory}]"
  else
    "category: #{topic}"
  end
  front_matter_lines << "tags: #{tags_yaml}"
  front_matter_lines << "pdf: /assets/pdfs/#{cat_seg}/#{basename}.pdf" if has_pdf
  front_matter_lines << "pages: #{page_count}" if has_pdf
  front_matter_lines << "cover: /assets/pdfs/#{cat_seg}/#{basename}.png" if cover_generated

  body_placeholder = if has_pdf
    "<!-- Context for this note goes here as normal Markdown. It renders\n" \
    "     above the embedded PDF viewer on the post page. Delete this\n" \
    "     comment once you've written something. -->\n"
  else
    "<!-- Write this post's content here as normal Markdown. Delete this\n" \
    "     comment once you've written something. -->\n"
  end

  File.write(post_path, "---\n#{front_matter_lines.join("\n")}\n---\n\n#{body_placeholder}")

  {
    post: post_path,
    pdf: has_pdf ? pdf_dest : nil,
    cover: cover_generated ? cover_dest : nil,
  }
end

rel = ->(path) { path.sub(repo_root + "/", "") }

if options[:pdf_dir]
  # ---- Batch mode: one post per PDF in the directory ----
  dir = options[:pdf_dir]
  abort "Not a directory: #{dir}" unless File.directory?(dir)
  warn "Ignoring positional title in --pdf-dir mode (titles come from filenames)." if ARGV.first

  pdfs = Dir.glob(File.join(dir, "*.{pdf,PDF}")).sort
  abort "No PDFs found in #{dir}" if pdfs.empty?

  puts "Found #{pdfs.length} PDF(s) in #{dir}"
  puts "Category: #{Categories.describe(repo_root, topic, subcategory)}"
  puts

  created = 0
  skipped = 0
  pdfs.each do |pdf|
    title = humanize(pdf)
    begin
      result = create_post(repo_root: repo_root, title: title, topic: topic,
                           subcategory: subcategory, cat_seg: cat_seg, pdf: pdf,
                           tags: options[:tags], date: options[:date])
      puts "  + #{title}  ->  #{rel.call(result[:post])}"
      created += 1
    rescue PostError => e
      warn "  ! Skipped #{File.basename(pdf)}: #{e.message}"
      skipped += 1
    end
  end

  puts
  puts "Done: #{created} post(s) created, #{skipped} skipped."
  puts "Next steps: edit each post's body to add context, then git add/commit/push."
  puts "Tip: use script/edit_post.rb to fix any auto-generated title you don't like."
else
  # ---- Single post (with or without a PDF) ----
  title = ARGV.first
  abort "Missing title. Usage: ruby script/new_post.rb \"Title\" --topic TOPIC [--pdf PATH | --pdf-dir DIR]" if title.nil? || title.empty?

  begin
    result = create_post(repo_root: repo_root, title: title, topic: topic,
                         subcategory: subcategory, cat_seg: cat_seg, pdf: options[:pdf],
                         tags: options[:tags], date: options[:date])
  rescue PostError => e
    abort e.message
  end

  puts "Created post:  #{rel.call(result[:post])}"
  if result[:pdf]
    puts "Copied PDF to: #{rel.call(result[:pdf])}"
    if result[:cover]
      puts "Cover image:   #{rel.call(result[:cover])}"
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
end
