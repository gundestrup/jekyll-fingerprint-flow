# frozen_string_literal: true

module Jekyll
  module FingerprintFlow
    # Reads the `fingerprint_flow:` section of _config.yml.
    #
    #   fingerprint_flow:
    #     enabled: true            # default
    #     extensions: [foo]        # extra extensions to fingerprint
    #     exclude: ["/internal/"]  # URL path prefixes never rewritten
    #     priority: 12             # integer 11..19; between normal processing and compression
    class Configuration
      DEFAULT_POST_WRITE_PRIORITY = 12
      POST_WRITE_PRIORITIES = (11..19)
      DEFAULT_EXTENSIONS = %w[
        css js mjs map json xml webmanifest
        png jpg jpeg gif webp avif svg ico
        woff woff2 ttf otf eot
        mp4 webm mp3 wav ogg pdf txt
      ].freeze

      attr_reader :extensions, :exclude, :post_write_priority

      def self.post_write_priority(site)
        config = site.config["fingerprint_flow"] || {}
        priority = config.fetch("priority", DEFAULT_POST_WRITE_PRIORITY)
        return priority if priority.is_a?(Integer) && POST_WRITE_PRIORITIES.cover?(priority)

        raise Jekyll::Errors::FatalException,
              "FingerprintFlow: fingerprint_flow.priority must be an integer from 11 through 19"
      end

      def initialize(site)
        cfg = site.config["fingerprint_flow"] || {}
        @enabled = cfg.fetch("enabled", true)
        @post_write_priority = self.class.post_write_priority(site)
        configure_asset_options(cfg)
      end

      def enabled?
        @enabled
      end

      private

      def configure_asset_options(config)
        extra = Array(config["extensions"]).map do |extension|
          extension.to_s.downcase.delete_prefix(".")
        end
        @extensions = (DEFAULT_EXTENSIONS | extra).freeze
        @exclude = Array(config["exclude"]).map(&:to_s)
      end
    end
  end
end
