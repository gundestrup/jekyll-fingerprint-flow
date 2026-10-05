# frozen_string_literal: true

require "cgi"

module Jekyll
  module FingerprintFlow
    class HtmlDocumentRewriter
      URL_ATTRIBUTES = %w[src href srcset poster xlink:href].freeze
      INVALID_BASE_HREF = :invalid_base_href

      attr_reader :tagged, :skipped

      def initialize(tagger, scanner: HtmlTagScanner.new)
        @tagger = tagger
        @scanner = scanner
        @tagged = 0
        @skipped = 0
        @srcset_rewriter = SrcsetRewriter.new(@tagger) { |value| counted(value) }
      end

      def rewrite(source, path)
        base_href = first_base_href(source)
        return invalid_base(path) if base_href == INVALID_BASE_HREF

        apply_changes(source, attribute_changes(source, path, base_href))
      end

      private

      def first_base_href(source)
        @scanner.each_tag(source) do |name, attributes|
          next unless name == "base"

          attribute = attributes.find { |item| item.name == "href" }
          next unless attribute

          value = decode_attribute(attribute_value(source, attribute))
          return value || INVALID_BASE_HREF
        end
        nil
      end

      def attribute_changes(source, path, base_href)
        changes = []
        @scanner.each_tag(source) do |_name, attributes|
          changes.concat(changes_for_attributes(source, attributes, File.dirname(path), base_href))
        end
        changes
      end

      def changes_for_attributes(source, attributes, html_dir, base_href)
        attributes.filter_map do |attribute|
          change_for_attribute(source, attribute, html_dir, base_href)
        end
      end

      def change_for_attribute(source, attribute, html_dir, base_href)
        return unless URL_ATTRIBUTES.include?(attribute.name)

        value = decode_attribute(attribute_value(source, attribute))
        return count_skip unless value

        rewritten = rewrite_attribute(attribute, value, html_dir, base_href)
        return unless rewritten && rewritten != value

        [attribute.value_start, attribute.value_end, CGI.escapeHTML(rewritten).b]
      end

      def rewrite_attribute(attribute, value, html_dir, base_href)
        if attribute.name == "srcset"
          return @srcset_rewriter.rewrite(value, html_dir: html_dir, base_href: base_href)
        end

        counted(@tagger.tag(value, html_dir: html_dir, base_href: base_href))
      end

      def attribute_value(source, attribute)
        source.byteslice(attribute.value_start, attribute.value_end - attribute.value_start)
      end

      def decode_attribute(raw)
        value = raw.dup.force_encoding(Encoding::UTF_8)
        CGI.unescapeHTML(value) if value.valid_encoding?
      end

      def invalid_base(path)
        Jekyll.logger.warn("fingerprint-flow:", "skipped #{path} (invalid base href encoding)")
        nil
      end

      def apply_changes(source, changes)
        changes.sort_by(&:first).reverse_each do |start, finish, replacement|
          prefix = source.byteslice(0, start)
          suffix = source.byteslice(finish, source.bytesize - finish)
          source = prefix + replacement + suffix
        end
        source
      end

      def count_skip
        @skipped += 1
        nil
      end

      def counted(value)
        if value
          @tagged += 1
          value
        else
          count_skip
        end
      end
    end
  end
end
