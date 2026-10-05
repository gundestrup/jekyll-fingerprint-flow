# frozen_string_literal: true

module Jekyll
  module FingerprintFlow
    class SrcsetRewriter
      ASCII_SPACE = [9, 10, 12, 13, 32].freeze

      def initialize(tagger, &counter)
        @tagger = tagger
        @counter = counter
      end

      def rewrite(value, html_dir:, base_href:)
        changes = []
        position = 0
        while (candidate = next_candidate(value, position))
          start, finish, url, position = candidate
          tagged = @counter.call(@tagger.tag(url, html_dir: html_dir, base_href: base_href))
          changes << [start, finish, tagged.b] if tagged && tagged != url
        end
        return if changes.empty?

        apply_changes(value.b, changes).force_encoding(Encoding::UTF_8)
      end

      private

      def next_candidate(value, position)
        position = skip_separators(value, position)
        return if position >= value.bytesize

        start = position
        position = skip_url(value, position)
        finish = position
        url = value.byteslice(start, finish - start)
        url, finish, trailing_comma = strip_trailing_commas(url, finish)
        position = skip_descriptors(value, position) unless trailing_comma
        [start, finish, url, position]
      end

      def strip_trailing_commas(url, finish)
        commas = url[/,+\z/]
        return [url, finish, false] unless commas

        [url.byteslice(0, url.bytesize - commas.bytesize), finish - commas.bytesize, true]
      end

      def skip_url(value, position)
        position += 1 while position < value.bytesize && !space?(value.getbyte(position))
        position
      end

      def skip_descriptors(value, position)
        position = skip_spaces(value, position)
        depth = 0
        while position < value.bytesize
          byte = value.getbyte(position)
          return position + 1 if byte == 44 && depth.zero?

          depth += 1 if byte == 40
          depth -= 1 if byte == 41 && depth.positive?
          position += 1
        end
        position
      end

      def skip_separators(value, position)
        while position < value.bytesize
          byte = value.getbyte(position)
          break unless space?(byte) || byte == 44

          position += 1
        end
        position
      end

      def skip_spaces(value, position)
        position += 1 while position < value.bytesize && space?(value.getbyte(position))
        position
      end

      def space?(byte)
        ASCII_SPACE.include?(byte)
      end

      def apply_changes(source, changes)
        changes.sort_by(&:first).reverse_each do |start, finish, replacement|
          prefix = source.byteslice(0, start)
          suffix = source.byteslice(finish, source.bytesize - finish)
          source = prefix + replacement + suffix
        end
        source
      end
    end
  end
end
