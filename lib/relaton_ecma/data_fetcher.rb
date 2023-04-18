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
      @agent = Mechanize.new
      @agent.user_agent_alias = Mechanize::AGENT_ALIASES.keys[rand(21)]
    end

    # @param code [String]
    # @return [Array<RelatonBib::DocumentIdentifier>]
    def fetch_docid(code)
      [RelatonBib::DocumentIdentifier.new(type: "ECMA", id: code, primary: true)]
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [Array<Hash>]
    def fetch_title(doc)
      doc.xpath('//p[@class="ecma-item-short-description"]').map do |t|
        { content: t.text.strip, language: "en", script: "Latn" }
      end
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [Array<RelatonBib::BibliographicDate>]
    def fetch_date(doc)
      doc.xpath('//p[@class="ecma-item-edition"]').map do |d|
        date = d.text.split(", ").last
        RelatonBib::BibliographicDate.new type: "published", on: date
      end
    end

    #
    # @param doc [Nokogiri::HTML::Document]
    #
    # @return [RelatonBib::Edition, nil]
    #
    def fetch_edition(doc)
      cnt = doc.at('//p[@class="ecma-item-edition"]')&.text&.match(/^\d+(?=(?:st|nd|th|rd))/)&.to_s
      RelatonBib::Edition.new(content: cnt) if cnt && !cnt.empty?
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [Array<Hash>]
    def fetch_relation(doc) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      doc.xpath("//ul[@class='ecma-item-archives']/li").map do |rel|
        ref, ed, on = rel.at("span").text.split ", "
        fref = RelatonBib::FormattedRef.new content: ref, language: "en", script: "Latn"
        docid = RelatonBib::DocumentIdentifier.new(type: "ECMA", id: ref, primary: true)
        date = []
        date << RelatonBib::BibliographicDate.new(type: "published", on: on) if on
        link = rel.xpath("span/a").map { |l| RelatonBib::TypedUri.new type: "pdf", content: l[:href] }
        ed_cnt = ed&.match(/^\d+/).to_s
        edition = RelatonBib::Edition.new content: ed_cnt if ed_cnt && !ed_cnt.empty?
        bibitem = BibliographicItem.new(
          docid: [docid], formattedref: fref, date: date, edition: edition, link: link,
        )
        { type: "updates", bibitem: bibitem }
      end
    end

    # @param doc [Nokogiri::HTM::Document]
    # @param url [String, nil]
    # @return [Array<RelatonBib::TypedUri>]
    def fetch_link(doc, url = nil)
      link = []
      link << RelatonBib::TypedUri.new(type: "src", content: url) if url
      ref = doc.at('//div[@class="ecma-item-content-wrapper"]/span/a',
                   '//div[@class="ecma-item-content-wrapper"]/a',
                   "//div/p/a")
      link << RelatonBib::TypedUri.new(type: "doi", content: ref[:href]) if ref
      link
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [Array<RelatonBib::FormattedString>]
    def fetch_abstract(doc)
      content = doc.xpath('//div[@class="ecma-item-content"]/p').map do |a|
        a.text.strip.squeeze(" ").gsub(/\r\n/, "")
      end.join "\n"
      return [] if content.empty?

      [RelatonBib::FormattedString.new(content: content, language: "en", script: "Latn")]
    end

    # @param hit [Nokogiri::HTML::Element]
    # @return [Array<RelatonBib::DocumentIdentifier>]
    def fetch_mem_docid(hit)
      code = "ECMA MEM/#{hit.at('div[1]//p').text}"
      fetch_docid code
    end

    def fetch_mem_title(hit)
      year = hit.at("div[1]//p").text
      content = "\"Memento #{year}\" for year #{year}"
      [{ content: content, language: "en", script: "Latn" }]
    end

    def fetch_mem_date(hit)
      date = hit.at("div[2]//p").text
      on = Date.strptime(date, "%B %Y").strftime "%Y-%m"
      [RelatonBib::BibliographicDate.new(type: "published", on: on)]
    end

    def contributor
      org = RelatonBib::Organization.new name: "Ecma International"
      [{ entity: org, role: [{ type: "publisher" }] }]
    end

    # @param bib [RelatonItu::ItuBibliographicItem]
    def write_file(bib)
      id = bib.docidentifier[0].id.gsub(%r{[/\s]}, "_")
      file = "#{@output}/#{id}.#{@ext}"
      if @files.include? file
        warn "Duplicate file #{file}"
      else
        @files << file
      end
      File.write file, render_doc(bib), encoding: "UTF-8"
    end

    def render_doc(bib)
      case @format
      when "yaml" then bib.to_hash.to_yaml
      when "xml" then bib.to_xml bibdata: true
      when "bibxml" then bib.to_bibxml
      end
    end

    # @param hit [Nokogiri::HTML::Element]
    def parse_page(hit) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      bib = { type: "standard", language: ["en"], script: ["Latn"],
              contributor: contributor, place: ["Geneva"], doctype: "document" }
      if hit[:href]
        @agent.user_agent_alias = Mechanize::AGENT_ALIASES.keys[rand(21)]
        @agent.cookie_jar.clear!
        doc = get_page hit[:href]
        bib[:docid] = fetch_docid(hit.text)
        bib[:link] = fetch_link(doc, hit[:href])
        bib[:title] = fetch_title(doc)
        bib[:abstract] = fetch_abstract(doc)
        bib[:date] = fetch_date(doc)
        bib[:relation] = fetch_relation(doc)
        bib[:edition] = fetch_edition(doc)
      else
        bib[:docid] = fetch_mem_docid(hit)
        bib[:link] = fetch_link(hit)
        bib[:title] = fetch_mem_title(hit)
        bib[:date] = fetch_mem_date(hit)
      end
      item = RelatonBib::BibliographicItem.new(**bib)
      write_file item
    end

    def get_page(url)
      3.times do |n|
        sleep n
        doc = @agent.get url
        return doc
      rescue StandardError => e
        warn e.message
      end
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

      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end
  end
end
