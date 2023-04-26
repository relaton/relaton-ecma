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

    # @param code [String]
    # @return [Array<RelatonBib::DocumentIdentifier>]
    # def fetch_docid(code)
    #   [RelatonBib::DocumentIdentifier.new(type: "ECMA", id: code, primary: true)]
    # end

    # @param doc [Nokogiri::HTML::Document]
    # @return [Array<Hash>]
    # def fetch_title(doc)
    #   doc.xpath('//p[@class="ecma-item-short-description"]').map do |t|
    #     { content: t.text.strip, language: "en", script: "Latn" }
    #   end
    # end

    # @param doc [Mechanize::Page]
    # @return [Array<RelatonBib::BibliographicDate>]
    # def fetch_date(doc)
    #   doc.xpath('//p[@class="ecma-item-edition"]').map do |d|
    #     date = d.text.split(", ").last
    #     RelatonBib::BibliographicDate.new type: "published", on: date
    #   end
    # end

    #
    # @param doc [Mechanize::Page]
    #
    # @return [RelatonBib::Edition, nil]
    #
    # def fetch_edition(doc)
    #   cnt = doc.at('//p[@class="ecma-item-edition"]')&.text&.match(/^\d+(?=(?:st|nd|th|rd))/)&.to_s
    #   RelatonBib::Edition.new(content: cnt) if cnt && !cnt.empty?
    # end

    # @param doc [Mechanize::Page]
    # @return [Array<Hash>]
    # def fetch_relation(doc) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
    #   doc.xpath("//ul[@class='ecma-item-archives']/li").map do |rel|
    #     ref, ed, on = rel.at("span").text.split ", "
    #     fref = RelatonBib::FormattedRef.new content: ref, language: "en", script: "Latn"
    #     docid = RelatonBib::DocumentIdentifier.new(type: "ECMA", id: ref, primary: true)
    #     date = []
    #     date << RelatonBib::BibliographicDate.new(type: "published", on: on) if on
    #     link = rel.xpath("span/a").map { |l| RelatonBib::TypedUri.new type: "pdf", content: l[:href] }
    #     ed_cnt = ed&.match(/^\d+/).to_s
    #     edition = RelatonBib::Edition.new content: ed_cnt if ed_cnt && !ed_cnt.empty?
    #     bibitem = BibliographicItem.new(
    #       docid: [docid], formattedref: fref, date: date, edition: edition, link: link,
    #     )
    #     { type: "updates", bibitem: bibitem }
    #   end
    # end

    # @param doc [Mechanize::Page]
    # @param url [String, nil]
    # @return [Array<RelatonBib::TypedUri>]
    # def fetch_link(doc, url = nil)
    #   link = []
    #   link << RelatonBib::TypedUri.new(type: "src", content: url) if url
    #   ref = doc.at('//div[@class="ecma-item-content-wrapper"]/span/a',
    #                '//div[@class="ecma-item-content-wrapper"]/a',
    #                "//div/p/a")
    #   link << RelatonBib::TypedUri.new(type: "pdf", content: ref[:href]) if ref
    #   link + translation_link(doc)
    # end

    # def translation_link(doc)
    #   doc.xpath("//main/article/div/div/standard/div[2]/ul/li").map do |l|
    #     a = l.at("span/a")
    #     %r{\w+[\d-]+,\s(?<lang>\w+)\sversion,\s(?<ed>[\d.]+)(?:st|nd|rd|th)\sedition} =~ a.text
    #     case lang
    #     when "Japanese"
    #       { lang: "ja", script: "Jpan", ed: ed, href: a[:href] }
    #     end
    #   end
    # end

    # @param doc [Mechanize::Page]
    # @return [Array<RelatonBib::FormattedString>]
    # def fetch_abstract(doc)
    #   content = doc.xpath('//div[@class="ecma-item-content"]/p').map do |a|
    #     a.text.strip.squeeze(" ").gsub(/\r\n/, "")
    #   end.join "\n"
    #   return [] if content.empty?

    #   [RelatonBib::FormattedString.new(content: content, language: "en", script: "Latn")]
    # end

    # @param hit [Nokogiri::XML::Element]
    # @return [Array<RelatonBib::DocumentIdentifier>]
    # def fetch_mem_docid(hit)
    #   code = "ECMA MEM/#{hit.at('div[1]//p').text}"
    #   fetch_docid code
    # end

    # def fetch_mem_title(hit)
    #   year = hit.at("div[1]//p").text
    #   content = "\"Memento #{year}\" for year #{year}"
    #   [{ content: content, language: "en", script: "Latn" }]
    # end

    # def fetch_mem_date(hit)
    #   date = hit.at("div[2]//p").text
    #   on = Date.strptime(date, "%B %Y").strftime "%Y-%m"
    #   [RelatonBib::BibliographicDate.new(type: "published", on: on)]
    # end

    # def contributor
    #   org = RelatonBib::Organization.new name: "Ecma International"
    #   [{ entity: org, role: [{ type: "publisher" }] }]
    # end

    # @param bib [RelatonItu::ItuBibliographicItem]
    def write_file(bib) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      id = bib.docidentifier[0].id.gsub(%r{[/\s]}, "_")
      id += "-#{bib.edition.content.gsub('.', '_')}" if bib.edition
      extent = bib.extent.detect { |e| e.type == "volume" }
      id += "-#{extent.reference_from}" if extent
      file = "#{@output}/#{id}.#{@ext}"
      if @files.include? file
        warn "Duplicate file #{file}"
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
      # bib = { type: "standard", language: ["en"], script: ["Latn"],
      #         contributor: contributor, place: ["Geneva"], doctype: "document" }
      # if hit[:href]
      #   @agent.user_agent_alias = Mechanize::AGENT_ALIASES.keys[rand(21)]
      #   @agent.cookie_jar.clear!
      #   doc = get_page hit[:href]
      #   bib[:docid] = fetch_docid(hit.text)
      #   bib[:link] = fetch_link(doc, hit[:href])
      #   bib[:title] = fetch_title(doc)
      #   bib[:abstract] = fetch_abstract(doc)
      #   bib[:date] = fetch_date(doc)
      #   bib[:relation] = fetch_relation(doc)
      #   bib[:edition] = fetch_edition(doc)
      # else
      #   bib[:docid] = fetch_mem_docid(hit)
      #   bib[:link] = fetch_link(hit)
      #   bib[:title] = fetch_mem_title(hit)
      #   bib[:date] = fetch_mem_date(hit)
      # end
      # item = BibliographicItem.new(**bib)
      # write_file item
      # parse_editions doc, bib if doc
      DataParser.new(hit).parse.each { |item| write_file item }
    end

    #
    # Parse editions
    #
    # @param [Mechanize::Page] doc document
    # @param [Hash] bib bibliographic item the last edition
    #
    # @return [void]
    #
    # def parse_editions(doc, bib) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    #   docid = bib[:docid]
    #   doc.xpath('//div[@id="main"]/div[1]/div/main/article/div/div/standard/div/ul/li').each do |hit|
    #     bib[:link] = edition_link hit
    #     id, ed, bib[:date], vol = edition_id_parts hit.at("./span", "./a").text
    #     next if ed.nil? || ed.empty?

    #     bib[:docid] = id.nil? || id.empty? ? docid : fetch_docid(id)
    #     bib[:edition] = RelatonBib::Edition.new(content: ed)
    #     bib[:extent] = vol && [RelatonBib::Locality.new("volume", vol)]
    #     item = BibliographicItem.new(**bib)
    #     write_file item
    #   end
    # end

    # def edition_link(hit)
    #   { "src" => hit.at("./a"), "pdf" => hit.at("./span/a") }.map do |type, a|
    #     RelatonBib::TypedUri.new(type: type, content: a[:href]) if a
    #   end.compact
    # end

    #
    # Parse edition and date
    #
    # @param [String] text identifier text
    #
    # @return [Array<String,nil,Array<RelatonBib::BibliographicDate>>] edition and date
    #
    # def edition_id_parts(text) # rubocop:disable Metrics/MethodLength
    #   %r{^
    #     (?<id>\w+(?:[\d-]+|\sTR/\d+)),?\s
    #     (?:Volume\s(?<vol>[\d.]+),?\s)?
    #     (?<ed>[\d.]+)(?:st|nd|rd|th)?\sedition
    #     (?:[,.]\s(?<dt>\w+\s\d+))?
    #   }x =~ text
    #   date = [dt].compact.map do |d|
    #     on = Date.strptime(d, "%B %Y").strftime("%Y-%m")
    #     RelatonBib::BibliographicDate.new(type: "published", on: on)
    #   end
    #   [id, ed, date, vol]
    # end

    #
    # Get page with retries
    #
    # @param [String] url url to fetch
    #
    # @return [Mechanize::Page] document
    #
    # def get_page(url)
    #   3.times do |n|
    #     sleep n
    #     doc = @agent.get url
    #     return doc
    #   rescue StandardError => e
    #     warn e.message
    #   end
    # end

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
        warn e.message
        warn e.backtrace
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
