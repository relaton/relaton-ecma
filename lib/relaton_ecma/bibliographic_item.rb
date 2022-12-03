module RelatonEcma
  class BibliographicItem < RelatonBib::BibliographicItem
    #
    # Fetch flavor ext schema version
    #
    # @return [String] schema version
    #
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-ecma"]
    end
  end
end
