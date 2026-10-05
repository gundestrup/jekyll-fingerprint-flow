# frozen_string_literal: true

require "digest"

module Jekyll
  module FingerprintFlow
    # Content-hash tags for files under _site. The tag is a pure function of
    # file content — same bytes, same tag, on any machine, in any
    # environment. Each output file is hashed once per build.
    class Hasher
      DIGEST_LENGTH = 10

      def initialize
        @memo = {}
      end

      def tag(path)
        @memo[path] ||= Digest::MD5.file(path).hexdigest[0, DIGEST_LENGTH]
      end
    end
  end
end
