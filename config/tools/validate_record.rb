require 'solis'
require 'shacl'

SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)

#data = { resource: ArchiefResource, id: "C634-3AF2-609A-1960-23CA14432AE9" }
data = { resource: RolBeheerderResource, id: "EE86-F083-A863-2600-778128CTRB9A" }
#data = { resource: TypeIdentificatienummerResource, id: "141D-A7A8-45A3-5326-DAB01CTTI9A4" }

#data = { resource: IdentificatienummerResource, id: "ID1D-A7A8-45A3-5326-DAB01CTTI9A4" }


resource = data[:resource].find({id: data[:id]})
puts resource.data.to_json
ttl_data = resource.data.dump(:ttl, true)
graph = RDF::Graph.new.from_ttl(ttl_data)

shacl = SHACL.open(SOLIS_CONF[:shape])
results = shacl.execute(graph)

puts results.to_s
puts ttl_data