module Relaton
  module Ecma
    class Ext < Bib::Ext
      def get_schema_version = Relaton.schema_versions["relaton-model-ecma"]
    end
  end
end
