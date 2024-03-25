module RelatonEcma
  class DataParser
    MATTRS = %i[docid title date link doctype].freeze
    ATTRS = MATTRS + %i[abstract relation edition doctype].freeze

    #
    # Initialize parser
    #
    # @param [Nokogiri::XML::Element] hit document hit
    #
    def initialize(hit)
      @hit = hit
      @bib = {
        type: "standard", language: ["en"], script: ["Latn"], place: ["Geneva"]
      }
      @agent = Mechanize.new
    end

    def parse # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      if @hit[:href]
        @agent.user_agent_alias = Mechanize::AGENT_ALIASES.keys[rand(21)]
        @doc = get_page @hit[:href]
        ATTRS.each { |a| @bib[a] = send "fetch_#{a}" }
      else
        MATTRS.each { |a| @bib[a] = send "fetch_mem_#{a}" }
      end
      @bib[:contributor] = contributor
      items = [BibliographicItem.new(**@bib)]
      items + parse_editions
    end

    #
    # Get page with retries
    #
    # @param [String] url url to fetch
    #
    # @return [Mechanize::Page] document
    #
    def get_page(url)
      3.times do |n|
        sleep n
        doc = @agent.get url
        return doc
      rescue StandardError => e
        Util.error e.message
      end
    end

    #
    # Parse editions
    #
    # @param [Mechanize::Page] doc document
    # @param [Hash] bib bibliographic item the last edition
    #
    # @return [void]
    #
    def parse_editions # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return [] unless @doc

      docid = @bib[:docid]
      @doc.xpath('//div[@id="main"]/div[1]/div/main/article/div/div/standard/div/ul/li').map do |hit|
        id, ed, @bib[:date], vol = edition_id_parts hit.at("./span", "./a").text
        @bib[:link] = edition_link(hit) + edition_translation_link(ed)
        next if ed.nil? || ed.empty?

        @bib[:docid] = id.nil? || id.empty? ? docid : fetch_docid(id)
        @bib[:edition] = RelatonBib::Edition.new(content: ed)
        @bib[:extent] = vol && [RelatonBib::Locality.new("volume", vol)]
        BibliographicItem.new(**@bib)
      end.compact
    end

    def edition_link(hit)
      { "src" => hit.at("./a"), "pdf" => hit.at("./span/a") }.map do |type, a|
        RelatonBib::TypedUri.new(type: type, content: a[:href]) if a
      end.compact
    end

    #
    # Parse edition and date
    #
    # @param [String] text identifier text
    #
    # @return [Array<String,nil,Array<RelatonBib::BibliographicDate>>] edition and date
    #
    def edition_id_parts(text) # rubocop:disable Metrics/MethodLength
      %r{^
        (?<id>\w+(?:[\d-]+|\sTR/\d+)),?\s
        (?:Volume\s(?<vol>[\d.]+),?\s)?
        (?<ed>[\d.]+)(?:st|nd|rd|th)?\sedition
        (?:[,.]\s(?<dt>\w+\s\d+))?
      }x =~ text
      date = [dt].compact.map do |d|
        on = Date.strptime(d, "%B %Y").strftime("%Y-%m")
        RelatonBib::BibliographicDate.new(type: "published", on: on)
      end
      [id, ed, date, vol]
    end

    # @return [Array<RelatonBib::DocumentIdentifier>]
    def fetch_docid(id = nil)
      id ||= @hit.text
      [RelatonBib::DocumentIdentifier.new(type: "ECMA", id: id, primary: true)]
    end

    # @return [Array<RelatonBib::TypedUri>]
    def fetch_link # rubocop:disable Metrics/AbcSize
      link = []
      link << RelatonBib::TypedUri.new(type: "src", content: @hit[:href]) if @hit[:href]
      ref = @doc.at('//div[@class="ecma-item-content-wrapper"]/span/a',
                    '//div[@class="ecma-item-content-wrapper"]/a')
      link << RelatonBib::TypedUri.new(type: "pdf", content: ref[:href]) if ref
      link + edition_translation_link(@bib[:edition]&.content)
    end

    def fetch_mem_link
      @hit.xpath("./div/section/div/p/a").map do |a|
        RelatonBib::TypedUri.new(type: "pdf", content: a[:href])
      end
    end

    def edition_translation_link(edition)
      translation_link.select { |l| l[:ed] == edition }.map { |l| l[:link] }
    end

    def translation_link
      return [] unless @doc

      @translation_link ||= @doc.xpath("//main/article/div/div/standard/div[2]/ul/li").map do |l|
        a = l.at("span/a")
        id = l.at("span").text
        %r{\w+[\d-]+,\s(?<lang>\w+)\sversion,\s(?<ed>[\d.]+)(?:st|nd|rd|th)\sedition} =~ id
        case lang
        when "Japanese"
          { ed: ed, link: RelatonBib::TypedUri.new(type: "pdf", language: "ja", script: "Jpan", content: a[:href]) }
        end
      end.compact
    end

    # @return [Array<Hash>]
    def fetch_title
      @doc.xpath('//p[@class="ecma-item-short-description"]').map do |t|
        { content: t.text.strip, language: "en", script: "Latn" }
      end
    end

    # @return [Array<RelatonBib::FormattedString>]
    def fetch_abstract
      content = @doc.xpath('//div[@class="ecma-item-content"]/p').map do |a|
        a.text.strip.squeeze(" ").gsub("\r\n", "")
      end.join "\n"
      return [] if content.empty?

      [RelatonBib::FormattedString.new(content: content, language: "en", script: "Latn")]
    end

    # @return [Array<RelatonBib::BibliographicDate>]
    def fetch_date
      @doc.xpath('//p[@class="ecma-item-edition"]').map do |d|
        date = d.text.split(", ").last
        RelatonBib::BibliographicDate.new type: "published", on: date
      end
    end

    # @return [Array<Hash>]
    def fetch_relation # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      @doc.xpath("//ul[@class='ecma-item-archives']/li").filter_map do |rel|
        ref, ed, date, vol = edition_id_parts rel.at("span").text
        next if ed.nil? || ed.empty?

        fref = RelatonBib::FormattedRef.new content: ref, language: "en", script: "Latn"
        docid = RelatonBib::DocumentIdentifier.new(type: "ECMA", id: ref, primary: true)
        link = rel.xpath("span/a").map { |l| RelatonBib::TypedUri.new type: "pdf", content: l[:href] }
        edition = RelatonBib::Edition.new content: ed
        extent = vol && [RelatonBib::Locality.new("volume", vol)]
        bibitem = BibliographicItem.new(
          docid: [docid], formattedref: fref, date: date, edition: edition,
          link: link, extent: extent
        )
        { type: "updates", bibitem: bibitem }
      end
    end

    #
    # @return [RelatonBib::Edition, nil]
    #
    def fetch_edition
      cnt = @doc.at('//p[@class="ecma-item-edition"]')&.text&.match(/^\d+(?=(?:st|nd|th|rd))/)&.to_s
      RelatonBib::Edition.new(content: cnt) if cnt && !cnt.empty?
    end

    def contributor
      org = RelatonBib::Organization.new name: "Ecma International"
      [{ entity: org, role: [{ type: "publisher" }] }]
    end

    # @return [Array<RelatonBib::DocumentIdentifier>]
    def fetch_mem_docid
      code = "ECMA MEM/#{@hit.at('div[1]//p').text}"
      fetch_docid code
    end

    def fetch_mem_date
      date = @hit.at("div[2]//p").text
      on = Date.strptime(date, "%B %Y").strftime "%Y-%m"
      [RelatonBib::BibliographicDate.new(type: "published", on: on)]
    end

    def fetch_mem_title
      year = @hit.at("div[1]//p").text
      content = "\"Memento #{year}\" for year #{year}"
      [{ content: content, language: "en", script: "Latn" }]
    end

    def fetch_doctype
      RelatonBib::DocumentType.new type: "document"
    end

    alias_method :fetch_mem_doctype, :fetch_doctype
  end
end
