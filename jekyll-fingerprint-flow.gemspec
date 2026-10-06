# frozen_string_literal: true

require_relative "lib/jekyll/fingerprint_flow/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-fingerprint-flow"
  spec.version = Jekyll::FingerprintFlow::VERSION
  spec.authors = ["Svend Gundestrup"]
  spec.email = ["svend@gundestrup.dk"]
  spec.summary = "Content-hash URL cache busting for Jekyll HTML output"
  spec.description = "A zero-config Jekyll plugin that content-tags supported local asset " \
                     "URLs in generated .html/.htm attributes at post_write. Covers matching " \
                     "markup emitted by themes and plugins without template changes. CSS/JS " \
                     "runtime references and HTTP cache headers are outside its scope."
  spec.homepage = "https://github.com/gundestrup/jekyll-fingerprint-flow"
  spec.license = "AGPL-3.0-or-later"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/gundestrup/jekyll-fingerprint-flow/tree/main",
    "changelog_uri" => "https://github.com/gundestrup/jekyll-fingerprint-flow/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/gundestrup/jekyll-fingerprint-flow/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.3.0"
  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md", "interface.yml"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 4.0", "< 5.0"
end
