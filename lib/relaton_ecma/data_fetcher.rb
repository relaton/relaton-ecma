# frozen_string_literal: true

require "English"
require "mechanize"
require "relaton_ecma"

module RelatonEcma
  class DataFetcher
    URL = "https://www.ecma-international.org/publications-and-standards/"

    # @param [String] :output directory to output documents
    # @param [String] :format output format (xml, yaml, bibxml)
    def initialize(output: "data", format: "yaml")
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
      @index = Relaton::Index.find_or_create :ECMA
      @agent = Mechanize.new
      @agent.user_agent_alias = Mechanize::AGENT_ALIASES.keys[rand(21)]
    end

    # @param bib [RelatonItu::ItuBibliographicItem]
    def write_file(bib) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      id = bib.docidentifier[0].id.gsub(%r{[/\s]}, "_")
      id += "-#{bib.edition.content.gsub('.', '_')}" if bib.edition
      extent = bib.extent.detect { |e| e.type == "volume" }
      id += "-#{extent.reference_from}" if extent
      file = "#{@output}/#{id}.#{@ext}"
      if @files.include? file
        Util.warn "Duplicate file #{file}"
      else
        @files << file
        File.write file, render_doc(bib), encoding: "UTF-8"
        @index.add_or_update index_id(bib), file
      end
    end

    def index_id(bib)
      { id: bib.docidentifier[0].id }.tap do |i|
        i[:ed] = bib.edition.content if bib.edition
        extent = bib.extent.detect { |e| e.type == "volume" }
        i[:vol] = extent.reference_from if extent
      end
    end

    def render_doc(bib)
      case @format
      when "yaml" then bib.to_hash.to_yaml
      when "xml" then bib.to_xml bibdata: true
      when "bibxml" then bib.to_bibxml
      end
    end

    # @param hit [Nokogiri::XML::Element]
    def parse_page(hit) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      DataParser.new(hit).parse.each { |item| write_file item }
    end

    # @param type [String]
    def html_index(type) # rubocop:disable Metrics/MethodLength
      result = @agent.get "#{URL}#{type}/"
      # @last_call_time = Time.now
      result.xpath(
        "//li/span[1]/a",
        "//div[contains(@class, 'entry-content-wrapper')][.//a[.='Download']]",
      ).each do |hit|
        # workers << hit
        parse_page(hit)
      rescue StandardError => e
        Util.error { "#{e.message}\n#{e.backtrace}" }
      end
    end

    #
    # Fetch data from Ecma website.
    #
    # @return [void]
    #
    def fetch
      t1 = Time.now
      puts "Started at: #{t1}"

      FileUtils.mkdir_p @output

      html_index "standards"
      html_index "technical-reports"
      html_index "mementos"
      @index.save

      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end
  end
end
