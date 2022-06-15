$LOAD_PATH << '.' << './lib'
require 'solis'

key = Solis::ConfigFile[:key]
s = Solis::Shape::Reader::Sheet.read(key, Solis::ConfigFile[:sheets][:abv], from_cache: false)

File.open('./solis/abv_shacl.ttl', 'wb') {|f| f.puts s[:shacl]}
File.open('./solis/abv.json', 'wb') {|f| f.puts s[:inflections]}
File.open('./solis/abv_schema.ttl', 'wb') {|f| f.puts s[:schema]}
File.open('./solis/abv.puml', 'wb') {|f| f.puts s[:plantuml]}
File.open('./solis/abv.sql', 'wb') {|f| f.puts s[:sql]}

# `plantuml -tsvg ./solis/abv.puml`
# `gm convert ./solis/abv.svg ./solis/abv.png`
