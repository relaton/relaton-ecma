module RelatonEcma
  class XMLParser < RelatonBib::XMLParser
    class << self
      private

      # @param item_hash [Hash]
      # @return [RelatonEcma::BibliographicItem]
      def bib_item(item_hash)
        BibliographicItem.new(**item_hash)
      end
    end
  end
end
