# frozen_string_literal: true

require "spec_helper"

FIXTURE_SITE = File.expand_path("fixtures/site", __dir__).freeze
RSpec.describe "post_write integration" do
  # Re-expresses the committed fixture site as a harness config + files pair
  # so single-build examples run through jekyll_build. Rebuild examples
  # below keep their own scaffolding — the harness builds each site in a
  # fresh temporary directory.
  def fixture_site
    files = {
      "index.html" => File.read(File.join(FIXTURE_SITE, "index.html")),
      "assets" => {
        "site.css" => File.read(File.join(FIXTURE_SITE, "assets/site.css")),
        "app.js" => File.read(File.join(FIXTURE_SITE, "assets/app.js"))
      }
    }
    config = YAML.load_file(File.join(FIXTURE_SITE, "_config.yml"))
    [config, files]
  end

  it "fingerprints asset references in a real Jekyll build" do
    config, files = fixture_site
    jekyll_build(config: config, files: files) do |_site, output_files|
      html = output_files.read("index.html")
      expect(html).to match(%r{/assets/site\.css\?v=[0-9a-f]{10}})
      expect(html).to match(%r{/assets/app\.js\?v=[0-9a-f]{10}})
      expect(html).to include('href="/about/"')
      expect(html).to include('src="https://cdn.example.com/keep.js"')
      expect(File).to exist(output_files.path("assets/site.css"))
    end
  end

  it "emits a new tag for a changed asset when the site is built again" do
    Dir.mktmpdir("fingerprint-flow-src") do |src|
      FileUtils.cp_r(File.join(FIXTURE_SITE, "."), src)
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
      FileUtils.cp_r(File.join(FIXTURE_SITE, "."), src)
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
    observed = false
    probe = proc do |built_site|
      observed = File.read(File.join(built_site.dest, "index.html")).include?("?v=")
    end
    hooks = Jekyll::Hooks.instance_variable_get(:@registry).fetch(:site).fetch(:post_write)
    priorities = Jekyll::Hooks.instance_variable_get(:@hook_priority)
    Jekyll::Hooks.register(:site, :post_write, priority: 16, &probe)

    config, files = fixture_site
    begin
      jekyll_build(
        config: config.merge("fingerprint_flow" => { "priority" => 17 }),
        files: files
      ) do |_site, _output_files|
        expect(observed).to be(true)
      end
    ensure
      hooks.delete(probe)
      priorities.delete(probe)
    end
  end
end
