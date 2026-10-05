# frozen_string_literal: true

require "spec_helper"

RSpec.describe "post_write integration" do
  it "fingerprints asset references in a real Jekyll build" do
    Dir.mktmpdir("fingerprint-flow-build") do |dest|
      site = Jekyll::Site.new(Jekyll.configuration(
                                "source" => File.expand_path("fixtures/site", __dir__),
                                "destination" => dest
                              ))
      site.process

      html = File.read(File.join(dest, "index.html"))
      expect(html).to match(%r{/assets/site\.css\?v=[0-9a-f]{10}})
      expect(html).to match(%r{/assets/app\.js\?v=[0-9a-f]{10}})
      expect(html).to include('href="/about/"')
      expect(html).to include('src="https://cdn.example.com/keep.js"')
      expect(File).to exist(File.join(dest, "assets/site.css"))
    end
  end

  it "emits a new tag for a changed asset when the site is built again" do
    Dir.mktmpdir("fingerprint-flow-src") do |src|
      FileUtils.cp_r(File.join(File.expand_path("fixtures/site", __dir__), "."), src)
      Dir.mktmpdir("fingerprint-flow-dest") do |dest|
        build = lambda do
          Jekyll::Site.new(Jekyll.configuration(
                             "source" => src, "destination" => dest, "quiet" => true
                           )).process
        end

        build.call
        first = File.read(File.join(dest, "index.html"))[/site\.css\?v=([0-9a-f]{10})/, 1]
        File.write(File.join(src, "assets/site.css"), "changed content")
        FileUtils.touch(File.join(src, "assets/site.css"), mtime: Time.now + 10)
        build.call
        second = File.read(File.join(dest, "index.html"))[/site\.css\?v=([0-9a-f]{10})/, 1]

        expect(first).to match(/\A[0-9a-f]{10}\z/)
        expect(second).not_to eq(first)
      end
    end
  end

  it "keeps the same tag for an unchanged asset when the site is built again" do
    Dir.mktmpdir("fingerprint-flow-src") do |src|
      FileUtils.cp_r(File.join(File.expand_path("fixtures/site", __dir__), "."), src)
      Dir.mktmpdir("fingerprint-flow-dest") do |dest|
        build = lambda do
          Jekyll::Site.new(Jekyll.configuration(
                             "source" => src, "destination" => dest, "quiet" => true
                           )).process
        end

        build.call
        first = File.read(File.join(dest, "index.html"))[/site\.css\?v=[0-9a-f]{10}/]
        build.call
        second = File.read(File.join(dest, "index.html"))[/site\.css\?v=[0-9a-f]{10}/]

        expect(second).to eq(first)
      end
    end
  end

  it "registers a dispatcher between normal processing and compression" do
    hooks = Jekyll::Hooks.instance_variable_get(:@registry)
    callbacks = hooks.fetch(:site).fetch(:post_write).select do |hook|
      hook.source_location&.first&.end_with?("/lib/jekyll/fingerprint_flow.rb")
    end
    priorities = Jekyll::Hooks.instance_variable_get(:@hook_priority)
    registered = callbacks.map { |hook| -priorities.fetch(hook).first }

    expect(registered).to match_array((11..19).to_a)
    expect(Jekyll::FingerprintFlow::Configuration::DEFAULT_POST_WRITE_PRIORITY).to eq(12)
  end

  it "uses the configured priority for this site's build" do
    Dir.mktmpdir("fingerprint-flow-priority") do |dest|
      site = Jekyll::Site.new(Jekyll.configuration(
                                "source" => File.expand_path("fixtures/site", __dir__),
                                "destination" => dest,
                                "fingerprint_flow" => { "priority" => 17 }
                              ))
      observed = false
      probe = proc do |built_site|
        observed = File.read(File.join(built_site.dest, "index.html")).include?("?v=")
      end
      hooks = Jekyll::Hooks.instance_variable_get(:@registry).fetch(:site).fetch(:post_write)
      priorities = Jekyll::Hooks.instance_variable_get(:@hook_priority)
      Jekyll::Hooks.register(:site, :post_write, priority: 16, &probe)

      begin
        site.process
      ensure
        hooks.delete(probe)
        priorities.delete(probe)
      end

      expect(observed).to be(true)
    end
  end
end
