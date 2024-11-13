$LOAD_PATH << '.' << './lib'
require "active_support/all"
require 'solis'

key = Solis::ConfigFile[:key]
['abv','audit','oaipmh'].each do |sheet_name|
  puts "\n\n\n#{sheet_name}"
  s = Solis::Shape::Reader::Sheet.read(key, Solis::ConfigFile[:sheets][sheet_name.to_sym], from_cache: false)

  File.open("./solis/#{sheet_name}_shacl.ttl", 'wb') { |f| f.puts s[:shacl] }
  File.open("./solis/#{sheet_name}.json", 'wb') { |f| f.puts s[:inflections] }
  File.open("./solis/#{sheet_name}_schema.ttl", 'wb') { |f| f.puts s[:schema] }
  File.open("./solis/#{sheet_name}.puml", 'wb') { |f| f.puts s[:plantuml] }
  File.open("./solis/#{sheet_name}.sql", 'wb') { |f| f.puts s[:sql] }

  `plantuml -tsvg ./solis/#{sheet_name}.puml`

  `rsvg-convert -d 300 -p 300 -f png -o ./solis/#{sheet_name}.png ./solis/#{sheet_name}.svg`
end
