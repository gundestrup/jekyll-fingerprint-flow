# frozen_string_literal: true

require "jekyll"
require "jekyll/fingerprint_flow/version"
require "jekyll/fingerprint_flow/configuration"
require "jekyll/fingerprint_flow/hasher"
require "jekyll/fingerprint_flow/url_tagger"
require "jekyll/fingerprint_flow/html_tag_scanner"
require "jekyll/fingerprint_flow/srcset_rewriter"
require "jekyll/fingerprint_flow/html_document_rewriter"
require "jekyll/fingerprint_flow/rewriter"

module Jekyll
  module FingerprintFlow
    Configuration::POST_WRITE_PRIORITIES.each do |hook_priority|
      registered_priority = hook_priority
      Jekyll::Hooks.register :site, :post_write, priority: registered_priority do |site|
        next unless Configuration.post_write_priority(site) == registered_priority

        Rewriter.new(site).run
      end
    end
  end
end
