#!/usr/bin/env ruby
# Edits an existing post's tags, title, topic, or subcategory — without
# recreating it from scratch. Changing --topic or --subcategory reorganizes
# the post: it moves the post's PDF (and cover thumbnail, if it has one)
# into the matching folder under assets/pdfs/ and updates the front matter,
# the same way script/new_post.rb lays a new post out.
#
# Usage:
#   ruby script/edit_post.rb _posts/2026-07-16-lab-notebook-week-3.md \
#     [--tags "a,b"] \
#     [--title "New Title"] \
#     [--topic new-topic] \
#     [--subcategory new-sub]
#
# Pass an empty string to --tags to clear a post's tags entirely. Pass an
# empty string to --subcategory to remove the subcategory (flattening the
# post back up to just its topic). --title only changes the displayed title
# — it does not rename the post's file, date, or URL.
#
# Topics and subcategories may be several words long — quote them. As in
# new_post.rb, the name is slugified for the front matter, URL, and folder
# ("Linear Algebra" -> linear-algebra) and recorded as typed in
# _data/categories.yml for the site to display. To rename a category that's
# already registered there, edit that file directly — this script only ever
# adds entries, so a name you've tuned by hand is never clobbered.

require "optparse"
require "yaml"
require "fileutils"
require_relative "categories"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/edit_post.rb PATH_TO_POST [--tags a,b] [--title \"New Title\"] [--topic new-topic] [--subcategory new-sub]"
  opts.on("--tags TAGS", "Replace this post's tags (comma-separated; pass \"\" to clear)") { |v| options[:tags] = v }
  opts.on("--title TITLE", "Rename the post's display title (does not rename the file or change its URL)") { |v| options[:title] = v }
  opts.on("--topic TOPIC", "Move this post to a different topic — relocates its PDF/cover and changes its URL") { |v| options[:topic] = v }
  opts.on("--subcategory SUB", "Set/replace the subcategory (pass \"\" to remove it) — relocates PDF/cover and changes the URL") { |v| options[:subcategory] = v }
end.parse!

post_path = ARGV.first
abort "Usage: ruby script/edit_post.rb PATH_TO_POST [--tags a,b] [--title \"New Title\"] [--topic new-topic] [--subcategory new-sub]" if post_path.nil?
abort "No such post: #{post_path}" unless File.exist?(post_path)
abort "Nothing to do — pass at least one of --tags, --title, --topic, --subcategory" if options.empty?

repo_root = File.expand_path("..", __dir__)
raw = File.read(post_path)

parts = raw.split(/^---$/, 3)
abort "Couldn't find a front matter block (---...---) at the top of #{post_path}" unless parts.length == 3
_, fm_text, body = parts
front_matter = YAML.safe_load(fm_text, permitted_classes: [Date]) || {}

# Jekyll merges either `category:` (singular) or `categories:` (list) into a
# post's category list, so read whichever this post used.
def current_categories(fm)
  if fm["categories"]
    Array(fm["categories"]).map(&:to_s)
  elsif fm["category"]
    [fm["category"].to_s]
  else
    []
  end
end

# Write the category list back in the tidiest shape: singular `category:`
# when there's just a topic, plural `categories: [a, b]` when nested. Removes
# the other key so we never leave both behind.
def set_categories(fm, cats)
  fm.delete("category")
  fm.delete("categories")
  if cats.length <= 1
    fm["category"] = cats.first
  else
    fm["categories"] = cats
  end
end

changed = []

if options.key?(:title)
  front_matter["title"] = options[:title]
  changed << "title"
end

if options.key?(:tags)
  front_matter["tags"] = options[:tags].split(",").map(&:strip).reject(&:empty?)
  changed << "tags"
end

# Topic and subcategory both affect the on-disk folder and the URL, so
# compute the new (topic, subcategory) pair once and relocate together.
if options.key?(:topic) || options.key?(:subcategory)
  old_cats = current_categories(front_matter)
  old_topic = old_cats[0]
  old_sub = old_cats[1]

  # Names as typed feed _data/categories.yml; their slugs feed the front
  # matter, the URL, and the assets/pdfs/ folder.
  new_topic_name = options.key?(:topic) ? Categories.normalize_name(options[:topic]) : nil
  new_topic = new_topic_name ? Categories.slugify(new_topic_name) : old_topic

  if options.key?(:subcategory)
    new_sub_name = Categories.normalize_name(options[:subcategory])
    new_sub = new_sub_name.empty? ? nil : Categories.slugify(new_sub_name)
  else
    new_sub_name = nil
    new_sub = old_sub
  end

  abort "Topic #{options[:topic].inspect} slugifies to nothing usable." if new_topic_name && new_topic.empty?
  abort "Subcategory #{options[:subcategory].inspect} slugifies to nothing usable." if new_sub&.empty?
  abort "This post has no topic to change; set one with --topic." if new_topic.nil? || new_topic.empty?

  Categories.register(repo_root, new_topic, new_topic_name) if new_topic_name
  Categories.register(repo_root, "#{new_topic}/#{new_sub}", new_sub_name) if new_sub && new_sub_name

  new_cats = new_sub ? [new_topic, new_sub] : [new_topic]
  old_seg = [old_topic, old_sub].compact.join("/")
  new_seg = new_cats.join("/")

  if old_seg == new_seg
    puts "Already in '#{new_seg}' — nothing to move."
  elsif front_matter["pdf"].nil?
    # Text-only post: no PDF/cover on disk to relocate, just relabel it.
    set_categories(front_matter, new_cats)
    changed << "category (#{old_seg} -> #{new_seg})"
  else
    pdf_basename = File.basename(front_matter["pdf"])
    old_pdf_full = File.join(repo_root, front_matter["pdf"])
    new_pdf_dir = File.join(repo_root, "assets", "pdfs", new_seg)
    new_pdf_full = File.join(new_pdf_dir, pdf_basename)

    abort "PDF not found on disk: #{old_pdf_full}" unless File.exist?(old_pdf_full)
    abort "A file already exists at the destination: #{new_pdf_full}" if File.exist?(new_pdf_full)

    FileUtils.mkdir_p(new_pdf_dir)
    FileUtils.mv(old_pdf_full, new_pdf_full)
    front_matter["pdf"] = "/assets/pdfs/#{new_seg}/#{pdf_basename}"

    if front_matter["cover"]
      cover_basename = File.basename(front_matter["cover"])
      old_cover_full = File.join(repo_root, front_matter["cover"])
      new_cover_full = File.join(new_pdf_dir, cover_basename)
      if File.exist?(old_cover_full)
        FileUtils.mv(old_cover_full, new_cover_full)
        front_matter["cover"] = "/assets/pdfs/#{new_seg}/#{cover_basename}"
      end
    end

    # Tidy up now-empty source folders (the subcategory dir, then its topic
    # dir), but only if this move actually emptied them.
    [File.join(repo_root, "assets", "pdfs", old_seg),
     File.join(repo_root, "assets", "pdfs", old_topic.to_s)].each do |dir|
      FileUtils.rmdir(dir) if !dir.empty? && Dir.exist?(dir) && Dir.empty?(dir)
    end

    set_categories(front_matter, new_cats)
    changed << "category (#{old_seg} -> #{new_seg})"
    puts "Note: this changes the post's URL, since the permalink includes" \
         " its category — the old link will 404. Nothing on the site links" \
         " to it by the old URL automatically, but double check if you've" \
         " shared that link anywhere."
  end
end

abort "Nothing changed." if changed.empty?

format_value = lambda do |key, value|
  case key
  when "title"
    "\"#{value}\""
  when "tags", "categories"
    arr = Array(value)
    arr.empty? ? "[]" : "[#{arr.join(', ')}]"
  when "date"
    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d") : value.to_s
  else
    value.to_s
  end
end

# Emit front matter in a stable, readable key order regardless of what order
# the keys ended up in the hash (set_categories can swap category/categories).
key_order = %w[layout title date category categories tags pdf pages cover]
ordered = front_matter.keys.sort_by { |k| [key_order.index(k) || key_order.length, k] }
front_matter_lines = ordered.map { |k| "#{k}: #{format_value.call(k, front_matter[k])}" }
new_front_matter = "---\n#{front_matter_lines.join("\n")}\n---"

File.write(post_path, new_front_matter + body)

puts "Updated: #{changed.join(', ')}"
puts "Post:    #{post_path}"
