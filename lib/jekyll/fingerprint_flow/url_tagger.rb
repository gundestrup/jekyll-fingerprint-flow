# frozen_string_literal: true

require "uri"

module Jekyll
  module FingerprintFlow
    # Decides whether a single URL from generated HTML should carry a
    # content-hash tag, and produces the tagged URL. Pure URL logic — file
    # resolution and hashing are injected.
    #
    # Tagged:   local URLs with a fingerprintable extension resolving to a
    #           real file under _site → ?v=<md5> (merged into any existing
    #           query, fragment preserved)
    # Skipped:  external URLs (any scheme, //), fragment-only, data:,
    #           non-allowlisted extensions, and references whose target file does
    #           not exist inside _site.
    class UrlTagger
      EXTERNAL = %r{\A(?:[a-z][a-z0-9+.-]*:|//)}i

      def initialize(site:, config:, hasher:)
        @dest = File.expand_path(site.dest)
        @baseurl = normalize_baseurl(site.baseurl)
        @config = config
        @hasher = hasher
      end

      # Returns the rewritten URL, or nil when the URL must not be touched.
      def tag(url, html_dir:, base_href: nil)
        parts = split(url.strip) or return
        path, query, frag = parts
        decoded_path = unescape(path) or return
        return unless fingerprintable?(decoded_path)

        resolved = resolve(decoded_path, html_dir, base_href) or return
        merge(path, query, frag, @hasher.tag(resolved))
      end

      private

      def normalize_baseurl(value)
        normalized = value.to_s
        normalized = normalized.delete_prefix("/") while normalized.start_with?("/")
        normalized = normalized.delete_suffix("/") while normalized.end_with?("/")
        normalized
      end

      def split(url)
        return if url.empty? || url.match?(EXTERNAL)

        path, _, fragment = url.partition("#")
        path, _, query = path.partition("?")
        return if path.empty?

        [path, query, fragment]
      end

      def unescape(path)
        URI::DEFAULT_PARSER.unescape(path)
      rescue ArgumentError
        nil
      end

      def fingerprintable?(path)
        ext = File.extname(path).delete_prefix(".").downcase
        return false unless @config.extensions.include?(ext)

        @config.exclude.none? { |prefix| path.start_with?(prefix) }
      end

      def resolve(path, html_dir, base_href)
        return if external_base_href?(base_href)

        candidate = candidate_path(path, html_dir, base_href)
        candidate && confined_file(candidate)
      rescue ArgumentError, SystemCallError
        nil
      end

      def external_base_href?(base_href)
        base_href&.strip&.match?(EXTERNAL)
      end

      def candidate_path(path, html_dir, base_href)
        return root_relative_path(path) if path.start_with?("/")

        base_dir = relative_base_dir(base_href, html_dir)
        base_dir && File.expand_path(path, base_dir)
      end

      def root_relative_path(path)
        File.expand_path(without_baseurl(path.delete_prefix("/")), @dest)
      end

      def without_baseurl(relative)
        return relative if @baseurl.empty?
        return "" if relative == @baseurl

        relative.start_with?("#{@baseurl}/") ? relative.delete_prefix("#{@baseurl}/") : relative
      end

      def relative_base_dir(base_href, html_dir)
        return html_dir unless base_href

        base_path = base_href.strip.partition("#").first.partition("?").first
        decoded_base = unescape(base_path) or return
        return html_dir if decoded_base.empty?

        base_target = base_target(decoded_base, html_dir)
        decoded_base.end_with?("/") ? base_target : File.dirname(base_target)
      end

      def base_target(path, html_dir)
        return root_relative_path(path) if path.start_with?("/")

        File.expand_path(path, html_dir)
      end

      def confined_file(candidate)
        root = File.realpath(@dest)
        resolved = File.realpath(candidate)
        return unless File.file?(resolved) && inside_destination?(resolved, root)

        resolved
      end

      def inside_destination?(path, root)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        path.start_with?(prefix)
      end

      def merge(path, query, fragment, tag)
        merged = if query.match?(/(?:^|&)v=/)
                   query.sub(/(^|&)v=[^&]*/, "\\1v=#{tag}")
                 elsif query.empty?
                   "v=#{tag}"
                 else
                   "#{query}&v=#{tag}"
                 end
        suffix = fragment.empty? ? "" : "##{fragment}"
        "#{path}?#{merged}#{suffix}"
      end
    end
  end
end
