require_relative "ext"

module Relaton
  module Ecma
    class Item < Bib::Item
      model ItemData

      attribute :ext, Ext
    end
  end
end
