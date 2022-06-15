require 'json'
require 'stopwords'
require 'solis/store/sparql/client'

module Sinatra
  module MainHelper
    def endpoints(base_path=Solis::ConfigFile[:services][$SERVICE_ROLE][:base_path])
      settings.solis.list_shapes.map {|m| "#{base_path}#{m.tableize}"}.sort
    end

    def api_error(status, source, title="Unknown error", detail="", e = nil)
      content_type :json

      puts e.backtrace.join("\n") unless e.nil?

      message = {"errors": [{
                    "status": status,
                    "source": {"pointer":  source},
                    "title": title,
                    "detail": detail
                  }]}.to_json
    end

    def for_resource
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}") if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.solis.shape_as_resource(klass)
    end

    def for_model
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}") if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.solis.shape_as_model(klass)
    end

    def recursive_compact(hash_or_array)
      p = proc do |*args|
        v = args.last
        v.delete_if(&p) if v.respond_to? :delete_if
        v.nil? || v.respond_to?(:"empty?") && v.empty?
      end

      hash_or_array.delete_if(&p)
    end

    def storage?
      sparql = SPARQL::Client.new(Solis::ConfigFile[:solis][:sparql_endpoint])

      sparql.query("ASK WHERE { ?s ?p ?o }")
    rescue StandardError => e
      return false
    end

    def audit_api?
      result = HTTP.get("#{Solis::ConfigFile[:services][:audit][:host]}/_audit/ping")
      return ::JSON.parse(result.body.to_s)
    rescue HTTP::Error => e
      return {'api': false, 'storage': false}
    end

    def search_api?
      result = HTTP.get("#{Solis::ConfigFile[:services][:search][:host]}/_search/ping")
      return ::JSON.parse(result.body.to_s)
    rescue HTTP::Error => e
      return {'api': false, 'storage': false}
    end

    def load_context
      id = '0'
      other_data = {}
      if request.has_header?('HTTP_X_FRONTEND')
        data = request.get_header('HTTP_X_FRONTEND')
        halt 500, api_error('400', request.url, 'Error parsing header X-Frontend', 'Error parsing header X-Frontend') if data.nil? || data.empty?
        data = data.split(';').map{|m| m.split('=')}.to_h
        halt 500, api_error('400', request.url, 'Error parsing header X-Frontend', 'Header must include key/value id=1234567') unless data.key?('id')

        id = data.key?('id') ? data['id'] : '0'
        other_data = data.select{|k,v| !k.eql?('id') }
      else
        logger.warn("No X-Frontend header found for : #{request.url}")
      end

      OpenStruct.new(query_user: id, other_data: other_data, language: params[:language] || Solis::ConfigFile[:solis][:language] || 'nl')
    end

    def logic_ui_lijst(key)
      result = {}

      result = settings.cache[key] if settings.cache.key?(key)

      if result.nil? || result.empty? || (params.key?(:from_cache) && params[:from_cache].eql?('0'))
        f = Stopwords::Snowball::Filter.new "nl"
        filename = "./config/constructs/#{key}.sparql"
        return result unless File.exist?(filename)

        q = File.read(filename)
        c = Solis::Store::Sparql::Client.new(Solis::ConfigFile[:solis][:sparql_endpoint], Solis::ConfigFile[:solis][:graph_name])
        r = c.query(q)
        t = r.query('select * where{?s ?p ?o}')

        result = {}
        u= {}
        t.each do |s|
          u[s.s.value] = {} unless u.key?(s.s.value)
          u[s.s.value][s.p.value.split('/').last] = s.o.value
        end

        u.each do |k,v|
          n = v['naam']
          next if n.nil? || n.empty?
          az = f.filter(n.downcase.gsub(/^\W*/,' ').strip.gsub(/[^\w|\s|[^\x00-\x7F]+\ *(?:[^\x00-\x7F]| )*]/,'').split).join(' ')[0] rescue '0'
          az = '0' if az.nil?

          naam = result[az] || []
          naam << n
          naam.uniq!
          naam.compact!
          result[az] = naam
        end

        result = result.sort.to_h
        settings.cache.store(key, result, expires: 86400)
      end

      result
    rescue StandardError => e
      puts e.message
      {}
    end

  end
  helpers MainHelper
end