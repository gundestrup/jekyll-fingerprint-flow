# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "interface manifest" do
  root = File.expand_path("..", __dir__)
  interface = Jekyll::FingerprintFlow::Interface.to_h

  it "matches the committed interface.yml" do
    manifest = YAML.load_file(File.join(root, "interface.yml"))
    expect(manifest).to eq(interface)
  end

  it "declares no tags — this gem registers none with Liquid" do
    owned = Liquid::Template.tags.select do |_name, klass|
      klass.to_s.start_with?("Jekyll::FingerprintFlow")
    end.map(&:first)
    expect(owned).to be_empty
    expect(interface["tags"]).to be_empty
  end

  it "declares exactly the config keys Configuration reads" do
    source = File.read(File.join(root, "lib/jekyll/fingerprint_flow/configuration.rb"))
    key_pattern = /(?:cfg|config)\s*(?:\[\s*"(\w+)"\s*\]|\.fetch\(\s*"(\w+)")/
    read = []
    pos = 0
    while (match = key_pattern.match(source, pos))
      read << match.captures.compact.first
      pos = match.end(0)
    end
    read = read.uniq - %w[fingerprint_flow] # section name, not a key
    expect(interface.dig("config", "fingerprint_flow")).to eq(read.sort)
  end

  it "documents every config key" do
    docs = Dir[File.join(root, "*.md")].map { |f| File.read(f) }.join("\n")

    missing = interface["config"]["fingerprint_flow"].reject do |key|
      docs.match?(/\b#{key}\b/)
    end
    expect(missing).to be_empty,
                       "config keys missing from docs:\n  #{missing.join("\n  ")}"
  end
end
