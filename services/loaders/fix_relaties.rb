require 'json'
require 'hashdiff'
require 'logger'
require 'http'
require 'active_support/all'
require 'solis'

def graph_to_object(model, solutions)
  return [] if solutions.empty?
  target_class = model.metadata[:target_class].value.split('/').last
  result = []
  record_uri = ''

  begin
    # solutions.sort! { |x, y| x.s.value <=> y.s.value }.map { |m| m.s.value }
    solution_types = solutions.dup.filter!(p: RDF::RDFV.type)
    solution_types.each do |type|
      solution_model = model.graph.shape_as_model(type.o.value.split('/').last)
      data = {}
      statements = solutions.dup.filter!(s: type.s)
      statements.each do |statement|
        next if statement.p.eql?(RDF::RDFV.type)

        begin
          record_uri = statement.s.value
          attribute = statement.p.value.split('/').last.underscore

          if statement.o.valid?
            if statement.o.is_a?(RDF::URI)
              object = statement.o.canonicalize.value
            else
              object = statement.o.canonicalize.object
            end
          else
            object = Integer(statement.o.value) if Integer(statement.o.value) rescue nil
            object = Float(statement.o.value) if object.nil? && Float(statement.o.value) rescue nil
            object = statement.o.value if object.nil?
          end

          begin
            datatype = RDF::Vocabulary.find_term(model.metadata[:attributes][attribute][:datatype_rdf])
            if RDF::Literal(statement.o).datatype.value != datatype
              if statement.o.is_a?(RDF::URI)
                object = RDF::Literal.new(statement.o.canonicalize.value, datatype: RDF::URI).object
              else
                object = RDF::Literal.new(statement.o.canonicalize.object, datatype: datatype).object
              end
            end
          rescue StandardError => e
            if object.is_a?(Hash)
              object = if object.key?(:fragment) && !object[:fragment].nil?
                         "#{object[:path]}##{object[:fragment]}"
                       else
                         object[:path]
                       end
            end
          end

          # fix non matching attributes by data type
          if solution_model.metadata[:attributes][attribute].nil?
            candidates = solution_model.metadata[:attributes].select { |_k, s| s[:class] == statement.p }.keys - data.keys
            attribute = candidates.first unless candidates.empty?
          end

          begin
            unless solution_model.metadata[:attributes][attribute][:node_kind].nil?
              node_class = solution_model.metadata[:attributes][attribute][:class].value.split('/').last
              object = solution_model.graph.shape_as_model(node_class).new({ id: object.split('/').last })
            end
          rescue StandardError => e
            puts e.message
          end

          if data.key?(attribute) # attribute exists
            raise "Cardinality error, max = #{solution_model.metadata[:attributes][attribute][:maxcount]}" if solution_model.metadata[:attributes][attribute][:maxcount] == 0
            if solution_model.metadata[:attributes][attribute][:maxcount] == 1 && data.key?(attribute)
              raise "Cardinality error, max = #{solution_model.metadata[:attributes][attribute][:maxcount]}"
            elsif solution_model.metadata[:attributes][attribute][:maxcount] == 1
              data[attribute] = object
            else
              data[attribute] = [data[attribute]] unless data[attribute].is_a?(Array)
              data[attribute] << object
            end
          else
            if solution_model.metadata[:attributes][attribute][:maxcount].nil? || solution_model.metadata[:attributes][attribute][:maxcount] > 1
              if data.include?(attribute)
                data[attribute] << object
              else
                data[attribute] = [object]
              end
            else
              data[attribute] = object
            end
          end
        rescue StandardError => e
          puts e.backtrace.first
          Solis::LOGGER.error("#{record_uri} - graph_to_object - #{attribute} - #{e.message}")
          g = RDF::Graph.new
          g << [statement.s, statement.p, statement.o]
          Solis::LOGGER.error(g.dump(:ttl).to_s)
        end
      end
      result << solution_model.new(data) unless data.empty?
    end
  rescue StandardError => e
    Solis::LOGGER.error("#{record_uri} - graph_to_object - #{e.message}")
  end
end



SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)
STDOUT.sync = true
LOGGER = Logger.new(STDOUT)

raise RuntimeError, "ARCHIEFPUNT_APIKEY not found " unless ENV.include?('ARCHIEFPUNT_APIKEY')

key = ENV['ARCHIEFPUNT_APIKEY']
http = HTTP.use(logging: {logger: LOGGER}).auth("Bearer #{key}")

file_blocks = Dir.glob('/Users/mehmetc/Downloads/files/*.f').map {|f| [File.mtime(f).to_s, f]}.group_by{|g| g.shift}.transform_values{|v| v.flatten}

file_blocks.each do |_, files|
  files.each do |file|
    delta = JSON.parse(File.read(file))
    host = delta['entity']['graph']
    entity_plural_name = delta['entity']['name_plural'].underscore
    entity_name = delta['entity']['name']
    id = delta['entity']['id']
    entity = SOLIS.shape_as_model(entity_name)

    g = RDF::Graph.new
    a = RDF::Graph.load("#{host}#{entity_plural_name}/#{id}?accept=application/jsonld&apikey=#{key}")
    #a.graph_name = RDF::URI(entity.graph_name)
    q = SPARQL.parse("SELECT * WHERE { ?s ?p ?o }")
    a.query(q).each do |s|
      g << [s.s, s.p, s.o]
    end

    #b = graph_to_object(entity, a.query(q) )

    context = JSON.parse %(
{
    "@context": {
        "@vocab": "#{Solis::Options.instance.get[:graph_name]}",
        "id": "@id"
    },
    "@type": "#{entity}",
    "@embed": "@always"
}
   )


    framed = nil
    JSON::LD::API.fromRDF(g) do |e|
      framed = JSON::LD::API.frame(e, context)
    end

    Solis::Query::Runner(framed)

    response = http.get("#{host}#{entity_plural_name}/#{id}?accept=text/turtle")

    case response.code
    when 200
      data = JSON.parse(response.body.to_s)
      entity = SOLIS.shape_as_model(entity_name)
      Hashdiff.patch!(data, delta)
    else
      puts response.body.to_s
    end
  end
end