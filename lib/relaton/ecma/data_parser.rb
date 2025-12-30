module Relaton
  module Ecma
    class DataParser
      MATTRS = %i[docidentifier title date source ext].freeze
      ATTRS = MATTRS + %i[abstract relation edition ext].freeze

      #
      # Initialize parser
      #
      # @param [Nokogiri::XML::Element] hit document hit
      #
      def initialize(hit)
        @hit = hit
        @bib = {
          type: "standard", language: ["en"], script: ["Latn"], place: [Bib::Place.new(city: "Geneva")]
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
        items = [ItemData.new(**@bib)]
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
      # @return [Array<Relaton::Ecma::ItemData>] editions
      #
      def parse_editions # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        return [] unless @doc

        docid = @bib[:docid]
        @doc.xpath('//div[@id="main"]/div[1]/div/main/article/div/div/standard/div/ul/li').map do |hit|
          id, ed, @bib[:date], vol = edition_id_parts hit.at("./span", "./a").text
          @bib[:source] = edition_source(hit) + edition_translation_source(ed)
          next if ed.nil? || ed.empty?

          @bib[:docidentifier] = id.nil? || id.empty? ? docid : fetch_docidentifier(id)
          @bib[:edition] = Bib::Edition.new(content: ed)
          @bib[:extent] = create_extent(vol)
          ItemData.new(**@bib)
        end.compact
      end

      def create_extent(vol)
        return unless vol && !vol.empty?

        locality = Bib::Locality.new(type: "volume", reference_from: vol)
        [Bib::Extent.new(locality: [locality])]
      end

      def edition_source(hit)
        { "src" => hit.at("./a"), "pdf" => hit.at("./span/a") }.map do |type, a|
          Bib::Uri.new(type: type, content: a[:href]) if a
        end.compact
      end

      #
      # Parse edition and date
      #
      # @param [String] text identifier text
      #
      # @return [Array<String,nil,Array<Relaton::Bib::Date>>] edition and date
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
          Bib::Date.new(type: "published", at: on)
        end
        [id, ed, date, vol]
      end

      # @return [Array<Relaton::Bib::Docidentifier>]
      def fetch_docidentifier(id = nil)
        id ||= @hit.text
        [Bib::Docidentifier.new(type: "ECMA", content: id, primary: true)]
      end

      # @return [Array<Relaton::Bib::Uri>]
      def fetch_source # rubocop:disable Metrics/AbcSize
        source = []
        source << Bib::Uri.new(type: "src", content: @hit[:href]) if @hit[:href]
        ref = @doc.at('//div[@class="ecma-item-content-wrapper"]/span/a',
                      '//div[@class="ecma-item-content-wrapper"]/a')
        source << Bib::Uri.new(type: "pdf", content: ref[:href]) if ref
        source + edition_translation_source(@bib[:edition]&.content)
      end

      def fetch_mem_source
        @hit.xpath("./div/section/div/p/a").map do |a|
          Bib::Uri.new(type: "pdf", content: a[:href])
        end
      end

      def edition_translation_source(edition)
        translation_source.select { |s| s[:ed] == edition }.map { |s| s[:source] }
      end

      def translation_source
        return [] unless @doc

        @translation_source ||= @doc.xpath("//h2[.='Translations']/following-sibling::ul/li").map do |l|
          a = l.at("span/a")
          id = l.at("span").text
          %r{\w+[\d-]+,\s(?<lang>\w+)\sversion,\s(?<ed>[\d.]+)(?:st|nd|rd|th)\sedition} =~ id
          case lang
          when "Japanese"
            { ed: ed, source: Bib::Uri.new(type: "pdf", language: "ja", script: "Jpan", content: a[:href]) }
          end
        end.compact
      end

      # @return [Array<Relaton::Bib::Title>]
      def fetch_title
        @doc.xpath('//p[@class="ecma-item-short-description"]').map do |t|
          Bib::Title.new(content: t.text.strip, language: "en", script: "Latn")
        end
      end

      # @return [Array<Relaton::Bib::LocalizedMarkedUpString>]
      def fetch_abstract
        content = @doc.xpath('//div[@class="ecma-item-content"]/p').map do |a|
          a.text.strip.squeeze(" ").gsub("\r\n", "")
        end.join "\n"
        return [] if content.empty?

        [Bib::LocalizedMarkedUpString.new(content: content, language: "en", script: "Latn")]
      end

      # @return [Array<Relaton::Bib::Date>]
      def fetch_date
        @doc.xpath('//p[@class="ecma-item-edition"]').map do |d|
          date = d.text.split(", ").last
          Bib::Date.new type: "published", at: date
        end
      end

      # @return [Array<Relaton::Bib::Relation>]
      def fetch_relation # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
        @doc.xpath("//ul[@class='ecma-item-archives']/li").filter_map do |rel|
          ref, ed, date, vol = edition_id_parts rel.at("span").text
          next if ed.nil? || ed.empty?

          docid = Bib::Docidentifier.new(type: "ECMA", content: ref, primary: true)
          source = rel.xpath("span/a").map { |l| Bib::Uri.new type: "pdf", content: l[:href] }
          edition = Bib::Edition.new content: ed
          extent = create_extent(vol)
          bibitem = ItemData.new(
            docidentifier: [docid], formattedref: ref, date: date, edition: edition,
            source: source, extent: extent
          )
          Bib::Relation.new(type: "updates", bibitem: bibitem)
        end
      end

      #
      # @return [Relaton::Bib::Edition, nil]
      #
      def fetch_edition
        cnt = @doc.at('//p[@class="ecma-item-edition"]')&.text&.match(/^\d+(?=(?:st|nd|th|rd))/)&.to_s
        Bib::Edition.new(content: cnt) if cnt && !cnt.empty?
      end

      def contributor
        orgname = Bib::TypedLocalizedString.new(content: "Ecma International", language: "en", script: "Latn")
        org = Bib::Organization.new name: [orgname]
        role = Bib::Contributor::Role.new type: "publisher"
        [Bib::Contributor.new(organization: org, role: [role])]
      end

      # @return [Array<Relaton::Bib::Docidentifier>]
      def fetch_mem_docidentifier
        code = "ECMA MEM/#{@hit.at('div[1]//p').text}"
        fetch_docidentifier code
      end

      def fetch_mem_date
        date = @hit.at("div[2]//p").text
        on = Date.strptime(date, "%B %Y").strftime "%Y-%m"
        [Bib::Date.new(type: "published", at: on)]
      end

      def fetch_mem_title
        year = @hit.at("div[1]//p").text
        content = "\"Memento #{year}\" for year #{year}"
        [Bib::Title.new(content: content, language: "en", script: "Latn")]
      end

      def fetch_ext
        Ext.new(doctype: fetch_doctype, flavor: "ecma")
      end

      def fetch_doctype
        Bib::Doctype.new content: "document"
      end

      alias_method :fetch_mem_ext, :fetch_ext
    end
  end
end
