module RelatonEcma
  module HashConverter
    include RelatonBib::HashConverter
    extend self

    # @param item_hash [Hash]
    # @return [RelatonEcma::BibliographicItem]
    def bib_item(item_hash)
      BibliographicItem.new(**item_hash)
    end
  end
end
