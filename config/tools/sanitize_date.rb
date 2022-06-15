require 'date'

tests = ['1938-1965', '1830 ; 1892-1995', 'Circa 1858 - circa 1930','1807-','[1910]-[1940]','1996-heden', '1920 ; 1980-heden',
         '19de eeuw-heden', '1960/1980', '1832 tot heden', '1809-nu', '11/01/1993–11/01/1993', 'Datering Niet geidentificeerd -1017390']


tests.each do |t|
  parsed = []
  t.scan(/\u2013|-|;|\/|heden|nu|tot heden|\w*|\d*/) do |token|
    token_offset = $~.offset(0)
    deleted = token.empty? ? true : false
    parsed << {value: token, deleted: deleted, offset: token_offset}
  end

  pp parsed
end