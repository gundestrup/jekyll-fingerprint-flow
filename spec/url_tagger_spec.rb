# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::FingerprintFlow::UrlTagger do
  def tagger_for(dest, baseurl: "", config: {})
    site = make_site(dest: dest, baseurl: baseurl, config: config)
    cfg = Jekyll::FingerprintFlow::Configuration.new(site)
    described_class.new(
      site: site,
      config: cfg,
      hasher: Jekyll::FingerprintFlow::Hasher.new
    )
  end

  it "tags a root-relative reference to an existing asset" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "assets"))
      File.write(File.join(dest, "assets/site.css"), "body{}")
      url = tagger_for(dest).tag("/assets/site.css", html_dir: dest)
      expect(url).to match(%r{\A/assets/site\.css\?v=[0-9a-f]{10}\z})
    end
  end

  it "tags a relative reference resolved against the HTML file dir" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "sub"))
      File.write(File.join(dest, "sub/app.js"), "x=1")
      url = tagger_for(dest).tag("app.js", html_dir: File.join(dest, "sub"))
      expect(url).to start_with("app.js?v=")
    end
  end

  it "produces the same tag for identical content" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "a"))
      File.write(File.join(dest, "a/x.css"), "same")
      tagger = tagger_for(dest)
      expect(tagger.tag("/a/x.css", html_dir: dest)).to eq(tagger.tag("/a/x.css", html_dir: dest))
    end
  end

  it "produces a different tag when file content changes" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "a"))
      file = File.join(dest, "a/x.css")
      File.write(file, "v1")
      first = tagger_for(dest).tag("/a/x.css", html_dir: dest)
      File.write(file, "v2-different")
      expect(tagger_for(dest).tag("/a/x.css", html_dir: dest)).not_to eq(first)
    end
  end

  it "merges into an existing query string" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "x")
      url = tagger_for(dest).tag("/x.js?foo=1", html_dir: dest)
      expect(url).to match(%r{\A/x\.js\?foo=1&v=[0-9a-f]{10}\z})
    end
  end

  it "replaces a stale v= parameter instead of stacking" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "x")
      url = tagger_for(dest).tag("/x.js?v=deadbeef", html_dir: dest)
      expect(url).to match(%r{\A/x\.js\?v=[0-9a-f]{10}\z})
      expect(url).not_to include("deadbeef")
    end
  end

  it "preserves the fragment" do
    with_site_dir do |dest|
      File.write(File.join(dest, "icon.svg"), "<svg/>")
      url = tagger_for(dest).tag("/icon.svg#sym", html_dir: dest)
      expect(url).to match(/\?v=[0-9a-f]{10}#sym\z/)
    end
  end

  it "resolves %-escaped paths" do
    with_site_dir do |dest|
      File.write(File.join(dest, "my file.css"), "x")
      url = tagger_for(dest).tag("/my%20file.css", html_dir: dest)
      expect(url).to start_with("/my%20file.css?v=")
    end
  end

  it "skips external URLs" do
    with_site_dir do |dest|
      tagger = tagger_for(dest)
      %w[
        https://cdn.example.com/x.js http://cdn.example.com/x.js
        //cdn.example.com/x.js data:image/png;base64,AAAA
        mailto:a@b.dk javascript:void(0)
      ].each do |url|
        expect(tagger.tag(url, html_dir: dest)).to be_nil
      end
    end
  end

  it "skips fragment-only, pages, and non-allowlisted paths" do
    with_site_dir do |dest|
      tagger = tagger_for(dest)
      expect(tagger.tag("#section", html_dir: dest)).to be_nil
      expect(tagger.tag("/about/", html_dir: dest)).to be_nil
      expect(tagger.tag("/page.html", html_dir: dest)).to be_nil
    end
  end

  it "skips references whose file does not exist" do
    with_site_dir do |dest|
      expect(tagger_for(dest).tag("/assets/missing.css", html_dir: dest)).to be_nil
    end
  end

  it "resolves a relative base href against the HTML file dir" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "pages", "sub"))
      File.write(File.join(dest, "pages", "sub", "app.css"), "x")
      url = tagger_for(dest).tag(
        "app.css", html_dir: File.join(dest, "pages"), base_href: "sub/"
      )
      expect(url).to start_with("app.css?v=")
    end
  end

  it "skips URLs with invalid percent-encoding" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.css"), "x")
      expect(tagger_for(dest).tag("/bad%zz.css", html_dir: dest)).to be_nil
    end
  end

  it "skips the URL if percent-decoding raises" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.css"), "x")
      tagger = tagger_for(dest)
      allow_any_instance_of(URI::RFC3986_Parser).to receive(:unescape).and_raise(ArgumentError)
      expect(tagger.tag("/x.css", html_dir: dest)).to be_nil
    end
  end

  it "honours the site baseurl when resolving" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "assets"))
      File.write(File.join(dest, "assets/x.css"), "x")
      url = tagger_for(dest, baseurl: "/blog").tag("/blog/assets/x.css", html_dir: dest)
      expect(url).to start_with("/blog/assets/x.css?v=")
    end
  end

  it "skips paths under excluded prefixes" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "internal"))
      File.write(File.join(dest, "internal/x.css"), "x")
      tagger = tagger_for(dest, config: { "fingerprint_flow" => { "exclude" => ["/internal/"] } })
      expect(tagger.tag("/internal/x.css", html_dir: dest)).to be_nil
    end
  end

  it "fingerprint extra extensions from config" do
    with_site_dir do |dest|
      File.write(File.join(dest, "data.bin"), "x")
      tagger = tagger_for(dest, config: { "fingerprint_flow" => { "extensions" => ["bin"] } })
      expect(tagger.tag("/data.bin", html_dir: dest)).to start_with("/data.bin?v=")
    end
  end

  it "does not resolve relative paths outside the destination" do
    Dir.mktmpdir("fingerprint-review") do |root|
      dest = File.join(root, "_site")
      subdir = File.join(dest, "sub")
      FileUtils.mkdir_p(subdir)
      File.write(File.join(root, "outside.css"), "outside")

      expect(tagger_for(dest).tag("../../outside.css", html_dir: subdir)).to be_nil
    end
  end

  it "does not follow asset symlinks outside the destination" do
    Dir.mktmpdir("fingerprint-review") do |root|
      dest = File.join(root, "_site")
      FileUtils.mkdir_p(dest)
      outside = File.join(root, "outside.css")
      File.write(outside, "outside")
      File.symlink(outside, File.join(dest, "linked.css"))

      expect(tagger_for(dest).tag("/linked.css", html_dir: dest)).to be_nil
    end
  end
end
