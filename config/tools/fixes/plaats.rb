# ssh -L 8892:127.0.0.1:8890 -R 6666:127.0.0.1:9292 abv2
require 'csv'
require 'solis/store/sparql/client'
require 'solis/error'

def all_plaatsen_q
  %(
prefix abv: <#{NAMESPACE}>
select ?plaats_id ?naam_id where {
    ?plaats_id abv:plaatsnaam ?naam_id;
        a abv:Plaats
}
)
end

def update_plaats_query_q(plaats_id, naam_id, new_naam_id)
  %(
prefix abv: <#{NAMESPACE}>

with abv:
delete {
  <#{plaats_id}> abv:plaatsnaam "#{naam_id}"
}
insert {
  <#{plaats_id}> abv:plaatsnaam <#{new_naam_id}>
}
)
end
def update_plaats_query(plaats_id, naam_id, new_naam_id)
  %(
prefix abv: <#{NAMESPACE}>

with abv:
delete {
  <#{plaats_id}> abv:plaatsnaam <#{naam_id}>
}
insert {
  <#{plaats_id}> abv:plaatsnaam <#{new_naam_id}>
}
)
end


NAMESPACE = 'https://data.archiefpunt.be/'

lookup = {}
ABV = Solis::Store::Sparql::Client.new('http://127.0.0.1:8892/sparql', NAMESPACE)
data = CSV.read('config/tools/fixes/plaatsen.csv', headers: true)

data.each do |a|
  #lookup[a['plaats_id'].gsub('data.archiefpunt', 'data.q.archiefpunt')] = a['naam_id'].gsub('data.archiefpunt', 'data.q.archiefpunt').gsub('/namen/', '/plaatsnamen/')
  lookup[a['plaats_id']] = a['naam_id'].gsub('/namen/', '/plaatsnamen/')
end

result=ABV.query(all_plaatsen_q)

result.each do |record|
  if record['naam_id'].value.eql?('onbekend')
    #if record['naam_id'].value =~ /\/namen\//
    plaats_id = record['plaats_id'].value
    naam_id = record['naam_id'].value
    new_naam_id = lookup[plaats_id]
    r = ABV.query(update_plaats_query(plaats_id, naam_id, new_naam_id))
    puts "#{plaats_id} - #{r.first['callret-0']}\n\n"
    #puts update_plaats_query(plaats_id, naam_id, new_naam_id)
  end
end