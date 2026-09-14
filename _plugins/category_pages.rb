# Generates one browsable page per category at /categories/<slug>/.
#
# The /categories/ index (and the homepage, which shares its include) lists
# categories as plain links; clicking one lands here, on a page that shows
# that category's subcategories with their posts underneath, plus any posts
# filed directly under the category with no subcategory.
#
# Jekyll can't do this in plain Liquid — a Liquid loop renders many sections
# on one page, but it can't *create* pages. Hence a generator. It's local
# (first-party, in _plugins/), not a third-party gem, so the "no plugin"
# decisions recorded in CLAUDE.md for the tag/category listings don't apply:
# those rejected an unmaintained external plugin for something site.tags
# already provided. Our GitHub Actions workflow runs `bundle exec jekyll
# build` directly rather than the native Pages build, so _plugins/ loads.
#
# Alongside the pages, this exposes two lookups for templates to use:
#
#   site.data.category_names  — { "linear-algebra" => "Linear Algebra",
#                                 "linear-algebra/vector-spaces" => "Vector
#                                 Spaces", ... } for every category in use.
#   site.data.category_index  — the category list the index page renders,
#                               sorted by display name.
#
# Display names come from _data/categories.yml (written by
# script/new_post.rb — see script/categories.rb), falling back to title-casing
# the slug when a category has no entry there.

module SymbioticInTheory
  class CategoryPageGenerator < Jekyll::Generator
    safe true
    priority :normal

    def generate(site)
      registry = site.data["categories"] || {}
      tree = build_tree(site)

      names = {}
      tree.each do |slug, node|
        names[slug] = display_name(registry, slug)
        node[:subs].each_key do |sub_slug|
          key = "#{slug}/#{sub_slug}"
          names[key] = display_name(registry, key, sub_slug)
        end
      end
      site.data["category_names"] = names

      pages = tree.keys.sort_by { |slug| names[slug].downcase }.map do |slug|
        node = tree[slug]
        subcategories = node[:subs].keys
                                   .sort_by { |sub| names["#{slug}/#{sub}"].downcase }
                                   .map do |sub|
          {
            "slug"  => sub,
            "name"  => names["#{slug}/#{sub}"],
            "posts" => newest_first(node[:subs][sub]),
          }
        end

        page = CategoryPage.new(site, slug, names[slug], newest_first(node[:direct]), subcategories)
        site.pages << page
        page
      end

      site.data["category_index"] = pages.map do |page|
        {
          "slug"          => page.data["category"],
          "name"          => page.data["category_name"],
          "url"           => page.url,
          "count"         => page.data["post_count"],
          "subcategories" => page.data["subcategories"].map { |sub| sub["name"] },
        }
      end

      pdf_posts = site.posts.docs.select { |post| post.data["pdf"] }
      page_count = pdf_posts.sum { |post| post.data["pages"].to_i }
      site.data["archive_stats"] = {
        "pdf_count"          => pdf_posts.length,
        "page_count"         => page_count,
        "page_count_display" => page_count.to_s.reverse.scan(/.{1,3}/).join(",").reverse,
      }
    end

    private

    # { topic_slug => { direct: [posts], subs: { sub_slug => [posts] } } }
    #
    # Reads post.categories, which Jekyll populates from either the singular
    # `category:` or the plural `categories: [topic, sub]` front matter, so
    # both post shapes land here the same way.
    def build_tree(site)
      tree = {}
      site.posts.docs.each do |post|
        cats = Array(post.data["categories"]).map { |cat| cat.to_s.strip }.reject(&:empty?)
        next if cats.empty?

        node = tree[cats[0]] ||= { direct: [], subs: {} }
        if cats[1]
          (node[:subs][cats[1]] ||= []) << post
        else
          node[:direct] << post
        end
      end
      tree
    end

    def newest_first(posts)
      posts.sort_by { |post| post.date }.reverse
    end

    # "linear-algebra" -> "Linear Algebra". Only used when _data/categories.yml
    # has no entry for the slug — e.g. a post whose front matter was written by
    # hand rather than by script/new_post.rb.
    def display_name(registry, key, slug = key)
      name = registry[key]
      return name.to_s unless name.nil? || name.to_s.strip.empty?

      slug.split("-").map(&:capitalize).join(" ")
    end
  end

  # An in-memory page at /categories/<slug>/ rendered by _layouts/category.html.
  # Built by hand rather than through Page#initialize's read_yaml path, since
  # there's no source file on disk to read front matter from.
  class CategoryPage < Jekyll::Page
    def initialize(site, slug, name, direct_posts, subcategories)
      @site = site
      @base = site.source
      @dir  = File.join("categories", slug)
      @name = "index.html"

      process(@name)
      self.data = {
        "layout"        => "category",
        "title"         => name,
        "category"      => slug,
        "category_name" => name,
        "direct_posts"  => direct_posts,
        "subcategories" => subcategories,
        "post_count"    => direct_posts.length + subcategories.sum { |sub| sub["posts"].length },
      }
    end
  end
end
