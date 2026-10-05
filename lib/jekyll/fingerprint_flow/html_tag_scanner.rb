# frozen_string_literal: true

require "jekyll/fingerprint_flow/html_tag_parser"

module Jekyll
  module FingerprintFlow
    class HtmlTagScanner
      RAW_TEXT_ELEMENTS = %w[
        script style textarea title xmp iframe noembed noframes plaintext
      ].freeze
      COMMENT_OPEN = "<!--".b.freeze
      COMMENT_CLOSE = "-->".b.freeze
      CDATA_OPEN = "<![CDATA[".b.freeze

      def each_tag(source, &block)
        return enum_for(:each_tag, source) unless block

        data = source.b
        cursor = 0
        while (opening = data.index("<".b, cursor))
          cursor = skip_special(data, opening) || scan_tag(data, opening, &block)
        end
        self
      end

      private

      def scan_tag(source, opening, &block)
        parsed = HtmlTagParser.new(source, opening).parse
        return opening + 1 unless parsed

        name, attributes, cursor = parsed
        block.call(name, attributes)
        after_tag(source, name, cursor)
      end

      def after_tag(source, name, cursor)
        return source.bytesize if name == "plaintext"
        return raw_text_end(source, name, cursor) if RAW_TEXT_ELEMENTS.include?(name)

        cursor
      end

      def skip_special(source, opening)
        if starts_with?(source, COMMENT_OPEN, opening)
          skip_delimited(source, opening + COMMENT_OPEN.bytesize)
        elsif starts_with?(source, CDATA_OPEN, opening)
          skip_cdata(source, opening + CDATA_OPEN.bytesize)
        elsif markup_start?(source, opening)
          skip_markup(source, opening + 2)
        end
      end

      def markup_start?(source, opening)
        [33, 47, 63].include?(source.getbyte(opening + 1))
      end

      def starts_with?(source, token, position)
        source.byteslice(position, token.bytesize) == token
      end

      def skip_delimited(source, position)
        ending = source.index(COMMENT_CLOSE, position)
        ending ? ending + COMMENT_CLOSE.bytesize : source.bytesize
      end

      def skip_cdata(source, position)
        while position + 2 < source.bytesize
          return position + 3 if cdata_end?(source, position)

          position += 1
        end
        source.bytesize
      end

      def cdata_end?(source, position)
        source.getbyte(position) == 93 &&
          source.getbyte(position + 1) == 93 &&
          source.getbyte(position + 2) == 62
      end

      def skip_markup(source, position)
        quote = nil
        while position < source.bytesize
          byte = source.getbyte(position)
          return position + 1 if byte == 62 && quote.nil?

          quote = next_quote(byte, quote)
          position += 1
        end
        position
      end

      def next_quote(byte, quote)
        return nil if quote && byte == quote
        return byte if quote.nil? && [34, 39].include?(byte)

        quote
      end

      def raw_text_end(source, name, position)
        pattern = Regexp.new("</#{Regexp.escape(name)}(?=[\\x09\\x0a\\x0c\\x0d\\x20/>])".b, Regexp::IGNORECASE)
        match = pattern.match(source, position)
        match ? match.begin(0) : source.bytesize
      end
    end
  end
end
