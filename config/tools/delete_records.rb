require 'http'
require 'logger'
require 'solis/store/sparql/client'


query = %(
PREFIX abv: <https://data.q.archiefpunt.be/>

SELECT DISTINCT ?archief_id
WHERE {
  VALUES ?beheerder_id {
    <https://data.q.archiefpunt.be/beheerders/BH80-23F7-1DF3-9960-1F11229BW9A4>
  }

  ?archief_id abv:beheerder ?beheerder_id;
              a abv:Archief.
}
ORDER BY ?archief_id
)

sparql = Solis::Store::Sparql::Client.new("http://127.0.0.1:8892/sparql", 'https://data.q.archiefpunt.be/')
ids = sparql.query(query).map(&:archief_id).map(&:to_s)

logger = Logger.new(STDOUT)
key = "Bearer #{ENV['ARCHIEFPUNT_KEY']}"
File.open('./liberas_fail.txt',  'wb') do |f|
  #File.readlines('/Users/mehmetc/Dropbox/AllSources/Archiefpunt/config/tools/liberas.txt', chomp: true).each do |archief_id|
  ids.each do |id|
    #archief_id = id.gsub('data.archiefpunt.be', '127.0.0.1:9292').gsub('https', 'http')
    archief_id = id
    response = HTTP.follow.delete(archief_id, {headers: {'Authorization': key}})
    if response.code >= 200 && response.code <= 299
      logger.info("#{response.code}:#{archief_id}")
      puts response.body.to_s
    else
      logger.error("#{response.code}:#{response.body}:#{archief_id}")
      f.puts archief_id
    end
  end
end