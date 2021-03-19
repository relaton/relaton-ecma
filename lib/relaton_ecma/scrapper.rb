module RelatonEcma
  module Scrapper
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-ecma/master/data/".freeze

    class << self
      # @param code [String]
      # @return [RelatonBib::BibliographicItem]
      def scrape_page(code)
        url = "#{ENDPOINT}#{code.gsub(/[\/\s]/, '_').upcase}.yaml"
        parse_page url
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      private

      # @param url [String]
      # @retrurn [RelatonBib::BibliographicItem]
      def parse_page(url)
        doc = OpenURI.open_uri url
        RelatonBib::BibliographicItem.from_hash YAML.safe_load(doc)
      end
    end
  end
end
