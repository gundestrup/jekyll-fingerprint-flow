# frozen_string_literal: true

module Jekyll
  module FingerprintFlow
    class HtmlTagParser
      Attribute = Struct.new(:name, :value_start, :value_end, keyword_init: true)
      ATTRIBUTE_TERMINATORS = [34, 39, 47, 60, 61, 62].freeze
      QUOTES = [34, 39].freeze
      ASCII_SPACE = [9, 10, 12, 13, 32].freeze

      def initialize(source, opening)
        @source = source
        @cursor = opening + 1
      end

      def parse
        return unless ascii_alpha?(@source.getbyte(@cursor))

        name = read_tag_name
        attributes, ending = read_attributes
        [name, attributes, ending]
      end

      private

      def read_tag_name
        start = @cursor
        @cursor += 1 while tag_name_byte?(@source.getbyte(@cursor))
        @source.byteslice(start, @cursor - start).downcase
      end

      def read_attributes
        attributes = []
        seen = {}
        loop do
          @cursor = skip_spaces(@cursor)
          ending = tag_ending
          return [attributes, ending] if ending

          append_current_attribute(attributes, seen)
        end
      end

      def tag_ending
        byte = @source.getbyte(@cursor)
        return @cursor + 1 if byte == 62
        return @cursor + 2 if byte == 47 && @source.getbyte(@cursor + 1) == 62

        @source.bytesize unless byte
      end

      def append_current_attribute(attributes, seen)
        name = read_attribute_name
        unless name
          @cursor += 1
          return
        end

        start, finish = read_attribute_value
        return if seen[name]

        attributes << Attribute.new(name: name, value_start: start, value_end: finish) if start
        seen[name] = true
      end

      def read_attribute_name
        start = @cursor
        @cursor += 1 while attribute_name_byte?(@source.getbyte(@cursor))
        return if @cursor == start

        @source.byteslice(start, @cursor - start).downcase
      end

      def read_attribute_value
        @cursor = skip_spaces(@cursor)
        return [nil, nil] unless @source.getbyte(@cursor) == 61

        @cursor = skip_spaces(@cursor + 1)
        quote = @source.getbyte(@cursor)
        return read_quoted_value(quote) if QUOTES.include?(quote)

        read_unquoted_value
      end

      def read_quoted_value(quote)
        start = @cursor + 1
        ending = @source.index(quote.chr.b, start)
        @cursor = ending ? ending + 1 : @source.bytesize
        ending ? [start, ending] : [nil, nil]
      end

      def read_unquoted_value
        start = @cursor
        @cursor += 1 while (byte = @source.getbyte(@cursor)) && !space?(byte) && byte != 62
        [start, @cursor]
      end

      def skip_spaces(position)
        position += 1 while space?(@source.getbyte(position))
        position
      end

      def space?(byte)
        ASCII_SPACE.include?(byte)
      end

      def ascii_alpha?(byte)
        return false unless byte

        byte.between?(65, 90) || byte.between?(97, 122)
      end

      def tag_name_byte?(byte)
        byte && !space?(byte) && ![47, 61, 62].include?(byte)
      end

      def attribute_name_byte?(byte)
        byte && !space?(byte) && !ATTRIBUTE_TERMINATORS.include?(byte)
      end
    end
  end
end
