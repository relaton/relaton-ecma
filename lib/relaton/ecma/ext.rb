module Relaton
  module Ecma
    class Ext < Bib::Ext
      attribute :schema_version, method: :get_schema_version

      def get_schema_version
        Relaton.schema_versions["relaton-model-ecma"]
      end
    end
  end
end
