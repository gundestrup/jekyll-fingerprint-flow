# frozen_string_literal: true

module Jekyll
  module FingerprintFlow
    class Rewriter
      def initialize(site, hasher: Hasher.new)
        @config = Configuration.new(site)
        @dest = File.expand_path(site.dest)
        tagger = UrlTagger.new(site: site, config: @config, hasher: hasher)
        @html_rewriter = HtmlDocumentRewriter.new(tagger)
      end

      def run
        return unless @config.enabled?

        files = Dir.glob(File.join(@dest, "**", "*.{html,htm}"))
        changed = files.count { |file| rewrite_file(file) }
        summary = "#{files.size} HTML files scanned, #{changed} rewritten, " \
                  "#{@html_rewriter.tagged} refs tagged"
        Jekyll.logger.info("fingerprint-flow:", summary)
      end

      def rewrite_file(path)
        return unless safe_output_path?(path)

        source = File.binread(path)
        output = @html_rewriter.rewrite(source, path)
        return unless output && output != source

        File.binwrite(path, output)
      end

      private

      def safe_output_path?(path)
        return false if File.symlink?(path)

        root = File.realpath(@dest)
        real = File.realpath(path)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        File.file?(real) && real.start_with?(prefix)
      rescue SystemCallError
        false
      end
    end
  end
end
