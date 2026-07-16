#!/usr/bin/env ruby
# Edits an existing post's tags, title, or topic — without recreating it
# from scratch. Changing --topic reorganizes the post: it moves the
# post's PDF (and cover thumbnail, if it has one) into the new topic's
# folder under assets/pdfs/ and updates the front matter to match, the
# same way script/new_post.rb lays a new post out.
#
# Usage:
#   ruby script/edit_post.rb _posts/2026-07-16-lab-notebook-week-3.md \
#     [--tags "a,b"] \
#     [--title "New Title"] \
#     [--topic new-topic]
#
# Pass an empty string to --tags to clear a post's tags entirely.
# --title only changes the displayed title — it does not rename the
# post's file, date, or URL.

require "optparse"
require "yaml"
require "fileutils"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/edit_post.rb PATH_TO_POST [--tags a,b] [--title \"New Title\"] [--topic new-topic]"
  opts.on("--tags TAGS", "Replace this post's tags (comma-separated; pass \"\" to clear)") { |v| options[:tags] = v }
  opts.on("--title TITLE", "Rename the post's display title (does not rename the file or change its URL)") { |v| options[:title] = v }
  opts.on("--topic TOPIC", "Move this post to a different topic — relocates its PDF/cover and changes its URL") { |v| options[:topic] = v }
end.parse!

post_path = ARGV.first
abort "Usage: ruby script/edit_post.rb PATH_TO_POST [--tags a,b] [--title \"New Title\"] [--topic new-topic]" if post_path.nil?
abort "No such post: #{post_path}" unless File.exist?(post_path)
abort "Nothing to do — pass at least one of --tags, --title, --topic" if options.empty?

repo_root = File.expand_path("..", __dir__)
raw = File.read(post_path)

parts = raw.split(/^---$/, 3)
abort "Couldn't find a front matter block (---...---) at the top of #{post_path}" unless parts.length == 3
_, fm_text, body = parts
front_matter = YAML.safe_load(fm_text, permitted_classes: [Date]) || {}

changed = []

if options.key?(:title)
  front_matter["title"] = options[:title]
  changed << "title"
end

if options.key?(:tags)
  front_matter["tags"] = options[:tags].split(",").map(&:strip).reject(&:empty?)
  changed << "tags"
end

if options.key?(:topic)
  old_topic = front_matter["category"]
  new_topic = options[:topic].downcase.strip

  if new_topic == old_topic
    puts "Already in topic '#{new_topic}' — nothing to move."
  elsif front_matter["pdf"].nil?
    # Text-only post: no PDF/cover on disk to relocate, just relabel it.
    front_matter["category"] = new_topic
    changed << "topic (#{old_topic} -> #{new_topic})"
  else
    pdf_basename = File.basename(front_matter["pdf"])
    old_pdf_full = File.join(repo_root, front_matter["pdf"])
    new_pdf_dir = File.join(repo_root, "assets", "pdfs", new_topic)
    new_pdf_full = File.join(new_pdf_dir, pdf_basename)

    abort "PDF not found on disk: #{old_pdf_full}" unless File.exist?(old_pdf_full)
    abort "A file already exists at the destination: #{new_pdf_full}" if File.exist?(new_pdf_full)

    FileUtils.mkdir_p(new_pdf_dir)
    FileUtils.mv(old_pdf_full, new_pdf_full)
    front_matter["pdf"] = "/assets/pdfs/#{new_topic}/#{pdf_basename}"

    if front_matter["cover"]
      cover_basename = File.basename(front_matter["cover"])
      old_cover_full = File.join(repo_root, front_matter["cover"])
      new_cover_full = File.join(new_pdf_dir, cover_basename)
      if File.exist?(old_cover_full)
        FileUtils.mv(old_cover_full, new_cover_full)
        front_matter["cover"] = "/assets/pdfs/#{new_topic}/#{cover_basename}"
      end
    end

    old_pdf_dir = File.join(repo_root, "assets", "pdfs", old_topic.to_s)
    FileUtils.rmdir(old_pdf_dir) if Dir.exist?(old_pdf_dir) && Dir.empty?(old_pdf_dir)

    front_matter["category"] = new_topic
    changed << "topic (#{old_topic} -> #{new_topic})"
    puts "Note: this changes the post's URL, since the permalink includes" \
         " its topic/category — the old link will 404. Nothing on the" \
         " site links to it by the old URL automatically, but double" \
         " check if you've shared that link anywhere."
  end
end

abort "Nothing changed." if changed.empty?

format_value = lambda do |key, value|
  case key
  when "title"
    "\"#{value}\""
  when "tags"
    arr = Array(value)
    arr.empty? ? "[]" : "[#{arr.join(', ')}]"
  when "date"
    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d") : value.to_s
  else
    value.to_s
  end
end

front_matter_lines = front_matter.map { |k, v| "#{k}: #{format_value.call(k, v)}" }
new_front_matter = "---\n#{front_matter_lines.join("\n")}\n---"

File.write(post_path, new_front_matter + body)

puts "Updated: #{changed.join(', ')}"
puts "Post:    #{post_path}"
