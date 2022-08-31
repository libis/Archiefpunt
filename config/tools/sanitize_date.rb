require 'iso8601'

tests = ['11/01/1993–11/01/1993', '1832 tot heden', '1960/1980', '1920 ; 1980-heden', '1938-1965', '1830 ; 1892-1995',
         'Circa 1858 - circa 1930','1807-','[1910]-[1940]','1996-heden', '19de eeuw-heden', '1809-nu', 'Datering Niet geidentificeerd -1017390']

def convert(parsed)
  new_t = []
  if parsed.length == 2  && parsed[0][:value]  =~ /\d{4}/ && parsed[1][:value]  =~ /\d{4}/
    new_t << "#{parsed[0][:value]}/#{parsed[1][:value]}"
  elsif parsed.length == 1  && parsed[0][:value]  =~ /\d{4}/
    new_t << "#{parsed[0][:value]}/P1Y"
  elsif (token = parsed.select{|s| s[:value].eql?('/')}).length > 0
    token_index = parsed.index(token[0])
    parsed.delete_at(token_index)

    new_t << convert(parsed).first
  elsif (token = parsed.select{|s| s[:value].eql?(';')}).length > 0
    token_index = parsed.index(token[0])
    one = parsed[0..token_index-1]
    two = parsed[token_index+1..]

    new_t << convert(one).first
    new_t << convert(two).first
  elsif (token = parsed.select{|s| s[:value].downcase.eql?('heden') ||  s[:value].downcase.eql?('tot heden') || s[:value].downcase.eql?('nu')}).length > 0
    token_index = parsed.index(token[0])
    parsed[token_index][:value] = '9999'

    new_t << convert(parsed).first
  elsif (token = parsed.select{|s| s[:value] =~ /de$/ }).length > 0
    token_index = parsed.index(token[0])
    parsed[token_index][:value].gsub!('de', '00')

    new_t << convert(parsed).first
  elsif (token = parsed.select{|s| s[:value].eql?('–')}).length > 0
    token_index = parsed.index(token[0])
    one = parsed[0..token_index-1]
    two = parsed[token_index+1..]

    d1 = ISO8601::DateTime.new(Date.parse(one.map{|m| m[:value]}.join('/')).iso8601)
    d2 = ISO8601::DateTime.new(Date.parse(two.map{|m| m[:value]}.join('/')).iso8601)

    new_t << ISO8601::TimeInterval.from_datetimes(d1,d2).to_s
    one

  end
  new_t
end


tests.each do |t|
  parsed = []

  t.scan(/\u2013|-|;|\/|heden|nu|tot heden|\w*|\d*/) do |token|
    token_offset = $~.offset(0)
    deleted = token.empty? || token.eql?('-') || token.eql?('eeuw') || token.downcase.eql?('circa') ? true : false

    parsed << {value: token, deleted: deleted, offset: token_offset}
  end

  parsed.delete_if { |d|d[:deleted] }

  new_t = convert(parsed)

  puts t, new_t
end