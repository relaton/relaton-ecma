module Relaton
  module Ecma
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
