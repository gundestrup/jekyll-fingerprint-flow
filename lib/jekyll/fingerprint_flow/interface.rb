# frozen_string_literal: true

module Jekyll
  module FingerprintFlow
    # Machine-readable description of the plugin's public interface:
    # config keys (this plugin registers no Liquid tags or filters).
    # `rake interface` writes this as interface.yml (shipped in the gem) so
    # tooling like editor extensions can consume it without parsing Ruby.
    module Interface
      CONFIG_KEYS = %w[enabled exclude extensions priority].freeze

      def self.to_h
        {
          "gem" => "jekyll-fingerprint-flow",
          "version" => VERSION,
          "tags" => {},
          "filters" => [],
          "config" => { "fingerprint_flow" => CONFIG_KEYS.sort },
          "enums" => {}
        }
      end
    end
  end
end
