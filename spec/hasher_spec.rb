# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::FingerprintFlow::Hasher do
  it "returns the same tag for repeated references to one file in a build" do
    with_site_dir do |dest|
      path = File.join(dest, "app.js")
      File.write(path, "console.log(1)")
      hasher = described_class.new

      expect(hasher.tag(path)).to eq(hasher.tag(path))
    end
  end

  it "recomputes a changed file in the next build even if size and mtime match" do
    with_site_dir do |dest|
      path = File.join(dest, "app.js")
      fixed_time = Time.at(1_700_000_000)
      File.write(path, "aa")
      File.utime(fixed_time, fixed_time, path)
      first = described_class.new.tag(path)

      File.write(path, "bb")
      File.utime(fixed_time, fixed_time, path)

      expect(described_class.new.tag(path)).not_to eq(first)
      expect(described_class.new.tag(path)).to eq(Digest::MD5.file(path).hexdigest[0, 10])
    end
  end
end
