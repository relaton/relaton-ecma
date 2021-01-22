module RelatonEcma
  module Scrapper
    ENDPOINT = "https://www.ecma-international.org/publications-and-standards/".freeze

    class << self
      # @param code [String]
      # @return [RelatonBib::BibliographicItem]
      def scrape_page(code)
        if code.match? /^ECMA-TR/i then scrape_tr code
        else scrape_standard code
        end
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      private

      def scrape_standard(code)
        # num = /\d+$/.match(code).to_s.rjust 3, "0"
        url = "#{ENDPOINT}standards/#{code.downcase}"
        parse_page code, url
      end

      def scrape_tr(code)
        url = "#{ENDPOINT}technical-reports/#{code.downcase}"
        parse_page code, url
      end

      # @param code [String]
      # @param url [String]
      # @retrurn [RelatonBib::BibliographicItem]
      def parse_page(code, url)
        doc = Nokogiri::HTML OpenURI.open_uri url
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
        ref = doc.at('//div[@class="ecma-item-content-wrapper"]/span/a')
        link << RelatonBib::TypedUri.new(type: "doi", content: ref[:href]) if ref
        link
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_title(doc)
        doc.xpath('//p[@class="ecma-item-short-description"]').map do |t|
          { content: t.text.strip, language: "en", script: "Latn" }
        end
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::FormattedString>]
      def fetch_abstract(doc)
        a = doc.xpath('//div[@class="ecma-item-content"]/p').map do |a|
          a.text.strip.squeeze(" ").gsub /\r\n/, ""
        end.join "\n"
        return [] if a.empty?

        [RelatonBib::FormattedString.new(content: a, language: "en", script: "Latn")]
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::BibliographicDate>]
      def fetch_date(doc)
        doc.xpath('//p[@class="ecma-item-edition"]').map do |d|
          date = d.text.split(", ").last
          RelatonBib::BibliographicDate.new type: "published", on: date
        end
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [String]
      def fetch_edition(doc)
        doc.at('//p[@class="ecma-item-edition"]')&.text&.match(/^\d+(?=th)/)&.to_s
      end

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relation(doc) # rubocop:disable Metrics/AbcSize
        doc.xpath("//ul[@class='ecma-item-archives']/li").map do |rel|
          ref, ed, on = rel.at("span").text.split ", "
          fref = RelatonBib::FormattedRef.new content: ref, language: "en", script: "Latn"
          date = []
          date << RelatonBib::BibliographicDate.new(type: "published", on: on) if on
          link = rel.xpath("span/a").map { |l| RelatonBib::TypedUri.new type: "doi", content: l[:href] }
          bibitem = RelatonBib::BibliographicItem.new formattedref: fref, edition: ed.match(/^\d+/).to_s, link: link
          { type: "updates", bibitem: bibitem }
        end
      end
    end
  end
end
