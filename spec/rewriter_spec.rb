# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::FingerprintFlow::Rewriter do
  def rewriter_for(dest, config: {}, hasher: Jekyll::FingerprintFlow::Hasher.new)
    described_class.new(make_site(dest: dest, config: config), hasher: hasher)
  end

  it "tags src/href attributes on asset references" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      File.write(File.join(dest, "site.css"), "css")
      File.write(File.join(dest, "index.html"), <<~HTML)
        <html><head>
        <link rel="stylesheet" href="/site.css">
        <script src="/app.js"></script>
        </head></html>
      HTML

      rewriter_for(dest).run
      out = File.read(File.join(dest, "index.html"))
      expect(out).to include('href="/site.css?v=')
      expect(out).to include('src="/app.js?v=')
    end
  end

  it "tags direct document links but never page links" do
    with_site_dir do |dest|
      File.write(File.join(dest, "doc.pdf"), "%PDF")
      File.write(File.join(dest, "index.html"), <<~HTML)
        <a href="/doc.pdf">download</a>
        <a href="/about/">about</a>
      HTML

      rewriter_for(dest).run
      out = File.read(File.join(dest, "index.html"))
      expect(out).to include('href="/doc.pdf?v=')
      expect(out).to include('href="/about/"')
    end
  end

  it "rewrites srcset entries and keeps descriptors" do
    with_site_dir do |dest|
      File.write(File.join(dest, "a.png"), "1")
      File.write(File.join(dest, "b.png"), "22")
      File.write(File.join(dest, "index.html"), <<~HTML)
        <img srcset="/a.png 1x, /b.png 2x" alt="">
      HTML

      rewriter_for(dest).run
      out = File.read(File.join(dest, "index.html"))
      expect(out).to match(%r{srcset="/a\.png\?v=[0-9a-f]{10} 1x, /b\.png\?v=[0-9a-f]{10} 2x"})
    end
  end

  it "handles single-quoted attribute values" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "x")
      File.write(File.join(dest, "index.html"), %(<script src='/x.js'></script>))

      rewriter_for(dest).run
      expect(File.read(File.join(dest, "index.html"))).to include("src='/x.js?v=")
    end
  end

  it "leaves external and missing references alone" do
    with_site_dir do |dest|
      File.write(File.join(dest, "index.html"), <<~HTML)
        <script src="https://cdn.example.com/lib.js"></script>
        <link href="/gone.css" rel="stylesheet">
      HTML

      rewriter_for(dest).run
      out = File.read(File.join(dest, "index.html"))
      expect(out).to include('src="https://cdn.example.com/lib.js"')
      expect(out).to include('href="/gone.css"')
    end
  end

  it "does not rewrite the file when nothing changed" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "x")
      page = File.join(dest, "index.html")
      File.write(page, '<script src="/x.js"></script>')

      rewriter_for(dest).run
      mtime = File.mtime(page)
      rewriter_for(dest).run
      expect(File.mtime(page)).to eq(mtime)
    end
  end

  it "gives a new tag when asset content changes on rebuild" do
    with_site_dir do |dest|
      asset = File.join(dest, "x.css")
      File.write(asset, "v1")
      page = File.join(dest, "index.html")
      File.write(page, '<link href="/x.css">')

      rewriter_for(dest).run
      first = File.read(page)
      File.write(asset, "v2-content")
      FileUtils.touch(asset, mtime: File.mtime(asset) + 10)
      rewriter_for(dest).run
      second = File.read(page)

      expect(first).not_to eq(second)
      expect(second).to match(%r{/x\.css\?v=[0-9a-f]{10}})
    end
  end

  it "is a no-op when disabled in config" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "x")
      page = File.join(dest, "index.html")
      File.write(page, '<script src="/x.js"></script>')

      rewriter_for(dest, config: { "fingerprint_flow" => { "enabled" => false } }).run
      expect(File.read(page)).to include('src="/x.js"')
    end
  end

  it "only rewrites actual attributes, not comments, scripts, styles, or data attributes" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      html = <<~HTML
        <!-- href="/app.js" -->
        <script>const src = "/app.js"; if (src === "/app.js") console.log(src);</script>
        <style>.x { content: 'src="/app.js"'; }</style>
        <img data-src="/app.js" data-href="/app.js">
      HTML
      File.write(page, html)

      rewriter_for(dest).run

      expect(File.read(page)).to eq(html)
    end
  end

  it "preserves data URLs and tags local srcset candidates" do
    with_site_dir do |dest|
      File.write(File.join(dest, "large.png"), "image")
      page = File.join(dest, "index.html")
      File.write(page, '<img srcset="data:image/png;base64,AAAA 1x, /large.png 2x">')

      rewriter_for(dest).run

      expect(File.read(page)).to match(
        %r{srcset="data:image/png;base64,AAAA 1x, /large\.png\?v=[0-9a-f]{10} 2x"}
      )
    end
  end

  it "leaves srcset formatting alone when no candidate is taggable" do
    with_site_dir do |dest|
      page = File.join(dest, "index.html")
      html = '<img srcset="/missing.png 1x,/also-missing.png 2x">'
      File.write(page, html)

      rewriter_for(dest).run

      expect(File.read(page)).to eq(html)
    end
  end

  it "decodes and re-escapes HTML query entities while replacing v" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      File.write(page, '<script src="/app.js?foo=1&amp;v=stale"></script>')

      rewriter_for(dest).run
      out = File.read(page)

      expect(out).to match(%r{src="/app\.js\?foo=1&amp;v=[0-9a-f]{10}"})
      expect(out.scan("v=").length).to eq(1)
    end
  end

  it "supports unquoted URL attributes" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      File.write(page, "<script src=/app.js></script>")

      rewriter_for(dest).run

      expect(File.read(page)).to match(%r{src=/app\.js\?v=[0-9a-f]{10}})
    end
  end

  it "does not swallow unexpected ArgumentErrors during rewriting" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      File.write(page, '<script src="/app.js"></script>')
      hasher = Class.new do
        def tag(_path)
          raise ArgumentError, "unexpected hasher failure"
        end
      end.new

      expect { rewriter_for(dest, hasher: hasher).run }
        .to raise_error(ArgumentError, "unexpected hasher failure")
    end
  end

  it "resolves relative asset URLs against a local base href" do
    with_site_dir do |dest|
      FileUtils.mkdir_p(File.join(dest, "sub"))
      FileUtils.mkdir_p(File.join(dest, "assets"))
      File.write(File.join(dest, "sub", "app.css"), "wrong")
      target = File.join(dest, "assets", "app.css")
      File.write(target, "right")
      page = File.join(dest, "sub", "index.html")
      File.write(page, '<base href="/assets/"><link href="app.css">')

      rewriter_for(dest).run

      expected = Digest::MD5.file(target).hexdigest[0, 10]
      expect(File.read(page)).to include(%(href="app.css?v=#{expected}"))
    end
  end

  it "leaves local-looking URLs unchanged when the base href is external" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.css"), "css")
      page = File.join(dest, "index.html")
      html = '<base href="https://cdn.example.com/"><link href="/app.css">'
      File.write(page, html)

      rewriter_for(dest).run

      expect(File.read(page)).to eq(html)
    end
  end

  it "skips CDATA sections and continues scanning after them" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      File.write(page, <<~HTML)
        <![CDATA[<script src="/app.js"></script>]]>
        <script src="/app.js"></script>
      HTML

      rewriter_for(dest).run

      out = File.read(page)
      expect(out).to include("<![CDATA[<script src=\"/app.js\">")
      expect(out.scan('src="/app.js?v=').length).to eq(1)
    end
  end

  it "skips a page whose base href is not valid UTF-8" do
    with_site_dir do |dest|
      File.write(File.join(dest, "app.js"), "js")
      page = File.join(dest, "index.html")
      html = "<base href=\"\xFF/\"><script src=\"/app.js\"></script>".b
      File.binwrite(page, html)
      allow(Jekyll.logger).to receive(:warn)

      rewriter_for(dest).run

      expect(File.binread(page)).to eq(html)
      expect(Jekyll.logger).to have_received(:warn)
        .with("fingerprint-flow:", /invalid base href/)
    end
  end

  it "tolerates malformed attributes and still tags the valid ones" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.css"), "css")
      page = File.join(dest, "index.html")
      File.write(page, %(<a ="junk" href="/x.css">link</a>))

      rewriter_for(dest).run

      expect(File.read(page)).to match(%r{href="/x\.css\?v=[0-9a-f]{10}"})
    end
  end

  it "tolerates unterminated CDATA and markup declarations at end of file" do
    with_site_dir do |dest|
      File.write(File.join(dest, "x.js"), "js")
      page = File.join(dest, "index.html")

      File.write(page, '<script src="/x.js"></script><![CDATA[unclosed')
      rewriter_for(dest).run
      File.write(page, '<script src="/x.js"></script><!unterminated')
      rewriter_for(dest).run

      expect(File.read(page)).to include('src="/x.js?v=')
    end
  end

  it "treats a file that vanishes mid-scan as unwritable" do
    with_site_dir do |dest|
      page = File.join(dest, "index.html")
      File.write(page, '<script src="/x.js"></script>')
      allow(File).to receive(:realpath).and_raise(Errno::ENOENT)

      expect(rewriter_for(dest).rewrite_file(page)).to be_nil
    end
  end

  it "tags a srcset candidate URL that ends in a stray comma" do
    with_site_dir do |dest|
      File.write(File.join(dest, "a.png"), "img")
      page = File.join(dest, "index.html")
      File.write(page, '<img srcset="/a.png,">')

      rewriter_for(dest).run

      expect(File.read(page)).to match(%r{srcset="/a\.png\?v=[0-9a-f]{10},"})
    end
  end

  it "does not follow an HTML symlink outside the destination" do
    with_site_dir do |dest|
      root = File.dirname(dest)
      File.write(File.join(dest, "app.js"), "js")
      outside = File.join(root, "outside.html")
      html = '<script src="/app.js"></script>'
      File.write(outside, html)
      File.symlink(outside, File.join(dest, "linked.html"))

      rewriter_for(dest).run

      expect(File.read(outside)).to eq(html)
    end
  end
end
