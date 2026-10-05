# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless ENV["COVERAGE"] == "false"
  require "simplecov"
  if ENV["CI"]
    require "simplecov-cobertura"
    SimpleCov.formatter SimpleCov::Formatter::CoberturaFormatter
  end
  SimpleCov.start do
    cover "lib/**/*.rb"
    minimum_coverage 90 if ENV["CI"]
  end
end

require "jekyll-fingerprint-flow"
require "tmpdir"
require "fileutils"

# A throwaway _site tree plus the minimal site stub the rewriter needs
# (dest + baseurl + config hash). Real hashing, real files.
def make_site(dest:, baseurl: "", config: {})
  Struct.new(:dest, :baseurl, :config).new(dest, baseurl, config)
end

def with_site_dir
  Dir.mktmpdir("fingerprint-flow") do |dir|
    site_dir = File.join(dir, "_site")
    FileUtils.mkdir_p(site_dir)
    yield site_dir
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
