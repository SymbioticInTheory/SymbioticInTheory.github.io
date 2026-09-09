#!/usr/bin/env ruby
# Shared category helpers for script/new_post.rb and script/edit_post.rb.
#
# Categories have two forms:
#
#   * a **slug** — lowercase, hyphenated, safe for a URL and a folder name.
#     This is what goes into a post's front matter, so it's what Jekyll's
#     `:categories` permalink placeholder expands into the post URL and what
#     new_post.rb uses for assets/pdfs/<topic>/<subcategory>/.
#   * a **display name** — what you actually typed, spaces/capitals and all.
#     Kept in _data/categories.yml, keyed by slug, and used for every place
#     the site renders the category as text.
#
# So `--topic "Linear Algebra"` gives a `linear-algebra` slug everywhere it
# matters mechanically, and "Linear Algebra" everywhere a human reads it.
#
# Stdlib only (same constraint as the scripts that require this file), so it
# runs on a lightweight authoring machine with no `bundle install`.

require "yaml"
require "fileutils"

module Categories
  module_function

  # Turn free text into a URL/folder-safe slug.
  #   "Linear Algebra" -> "linear-algebra"
  def slugify(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
  end

  # Collapse whitespace but otherwise leave the name exactly as typed — this
  # is what gets shown on the site.
  def normalize_name(text)
    text.to_s.strip.gsub(/\s+/, " ")
  end

  def registry_path(repo_root)
    File.join(repo_root, "_data", "categories.yml")
  end

  def load_registry(repo_root)
    path = registry_path(repo_root)
    return {} unless File.exist?(path)

    YAML.safe_load(File.read(path)) || {}
  end

  # Record `key -> name` in _data/categories.yml, where `key` is a slug
  # ("linear-algebra") for a topic or a slug path ("linear-algebra/vector-
  # spaces") for a subcategory.
  #
  # Appends rather than rewriting the file, so hand-written comments and any
  # display name you've since tuned by hand survive untouched. An existing
  # key is never overwritten. Returns true if a line was added.
  def register(repo_root, key, name)
    return false if key.nil? || key.empty?

    registry = load_registry(repo_root)
    return false if registry.key?(key)

    path = registry_path(repo_root)
    FileUtils.mkdir_p(File.dirname(path))
    existing = File.exist?(path) ? File.read(path) : header
    existing += "\n" unless existing.empty? || existing.end_with?("\n")
    File.write(path, existing + %(#{key.inspect}: #{name.inspect}\n))
    true
  end

  # Both scripts take a topic/subcategory pair, need the same slugs, and need
  # the same display names registered. Returns [topic_slug, sub_slug_or_nil].
  def resolve(repo_root, topic:, subcategory:)
    topic_name = normalize_name(topic)
    topic_slug = slugify(topic_name)
    raise ArgumentError, "Topic #{topic.inspect} slugifies to nothing usable." if topic_slug.empty?

    sub_name = normalize_name(subcategory)
    sub_slug = sub_name.empty? ? nil : slugify(sub_name)
    raise ArgumentError, "Subcategory #{subcategory.inspect} slugifies to nothing usable." if sub_slug&.empty?

    register(repo_root, topic_slug, topic_name)
    register(repo_root, "#{topic_slug}/#{sub_slug}", sub_name) if sub_slug

    [topic_slug, sub_slug]
  end

  # Human-readable "Display Name (slug)" for a topic/subcategory pair, so the
  # scripts can echo back both what the site will show and what lands in the
  # front matter and on disk.
  def describe(repo_root, topic_slug, sub_slug = nil)
    registry = load_registry(repo_root)
    label = lambda do |key, slug|
      name = registry[key]
      name.nil? || name == slug ? slug : "#{name} (#{slug})"
    end

    parts = [label.call(topic_slug, topic_slug)]
    parts << label.call("#{topic_slug}/#{sub_slug}", sub_slug) if sub_slug
    parts.join(" / ")
  end

  def header
    <<~YAML
      # Display names for categories, keyed by slug.
      #
      # A post's front matter stores the *slug* (so URLs and assets/pdfs/
      # folders stay clean); this file maps that slug back to the name the
      # site shows. Subcategories are keyed by their full path under the
      # topic, e.g. "linear-algebra/vector-spaces".
      #
      # script/new_post.rb and script/edit_post.rb append to this file when
      # they see a category for the first time, and never overwrite an entry
      # that's already here — so editing a name by hand is safe and sticks.
      #
      # A slug with no entry here still works: _plugins/category_pages.rb
      # falls back to title-casing the slug ("linear-algebra" -> "Linear
      # Algebra").
    YAML
  end
end
