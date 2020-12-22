module RelatonEcma
  module Scrapper
    ENDPOINT = "https://www.ecma-international.org/publications/standards/".freeze

    class << self
      # @param code [String]
      # @return [RelatonBib::BibliographicItem]
      def scrape_page(code) # rubocop:disable Metrics/AbcSize
        num = /\d+$/.match(code).to_s.rjust 3, "0"
        url = ENDPOINT + code.capitalize.sub(/\d+$/, num) + ".htm"
        doc = Nokogiri::HTML OpenURI.open_uri url
        parse_page doc, code, url
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      private

      # @param doc [Nokogiri::HTML::Document]
      # @param code [String]
      # @param url [String]
      # @retrurn [RelatonBib::BibliographicItem]
      def parse_page(doc, code, url)
        RelatonBib::BibliographicItem.new(
          type: "standard", docid: fetch_docid(code), language: ["en"], script: ["Latn"],
          link: fetch_link(doc, url), title: fetch_title(doc), abstract: fetch_abstract(doc),
          date: fetch_date(doc), relation: fetch_relation(doc), place: ["Geneva"],
          edition: fetch_edition(doc), doctype: "document"
        )
      end

      # @param code [String]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(code)
        [RelatonBib::DocumentIdentifier.new(type: "ECMA", id: code)]
      end

      # @param doc [Nokogiri::HTM::Document]
      # @param url [String]
      # @return [Array<RelatonBib::TypedUri>]
      def fetch_link(doc, url)
        link = [RelatonBib::TypedUri.new(type: "src", content: url)]
        ref = doc.at('//tr[@class="STbody"]/td/a')
        link << RelatonBib::TypedUri.new(type: "doi", content: ref[:href]) if ref
        link
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_title(doc)
        doc.xpath('//span[@class="STsubtitle"]').map do |t|
          { content: t.text.strip, language: "en", script: "Latn" }
        end
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::FormattedString>]
      def fetch_abstract(doc)
        a = doc.xpath('//p[@class="STdescription"]').map do |a|
          a.text.strip.squeeze(" ").gsub /\r\n/, ""
        end.join "\n"
        return [] if a.empty?

        [RelatonBib::FormattedString.new(content: a, language: "en", script: "Latn")]
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::BibliographicDate>]
      def fetch_date(doc)
        doc.xpath('//span[@class="STedition"]').map do |d|
          date = d.text.match(/(?<=\()\w+\s\d{4}(?=\))/).to_s
          RelatonBib::BibliographicDate.new type: "published", on: date
        end
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [String]
      def fetch_edition(doc)
        doc.at('//span[@class="STedition"]')&.text&.strip&.match(/^\d+(?=th)/)&.to_s
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relation(doc)
        history = doc.at "//p[contains(., 'historical')]/a"
        return [] unless history

        rel_doc = Nokogiri::HTML OpenURI.open_uri(ENDPOINT + history[:href])
        rel_doc.xpath("//tr[@class='STbody']/td[1]/*").map do |rel|
          fref = RelatonBib::FormattedRef.new content: rel.text, language: "en", script: "Latn"
          bibitem = RelatonBib::BibliographicItem.new formattedref: fref
          { type: "updates", bibitem: bibitem }
        end
      end
    end
  end
end
