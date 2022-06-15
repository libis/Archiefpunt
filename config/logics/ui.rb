require 'linkeddata'
require 'date'

require 'solis/query'
require 'lib/logic_helper'

module Logic
  def ui_archiefvormer_lijst(params = {})
    ui_lijst('ui_archiefvormer_lijst', params).to_json
  rescue StandardError => e
    raise RuntimeError, "Error loading 'ui_archiefvormer_lijst'"
  end

  def ui_bewaarplaats_lijst(params = {})
    ui_lijst('ui_bewaarplaats_lijst', params).to_json
  rescue StandardError => e
    raise RuntimeError, "Error loading 'ui_bewaarplaats_lijst'"
  end

  def archief(params)
    resolve('./config/constructs/expanded_archief2.sparql', 'archief_id', 'Archief', params['id'], params['from_cache']).to_json
  rescue StandardError => e
    raise RuntimeError, "Error loading 'archief'"
  end

  def beheerder(params)
    resolve('./config/constructs/expanded_beheerder.sparql', 'beheerder_id', 'Beheerder', params['id'], params['from_cache']).to_json
  rescue StandardError => e
    raise RuntimeError, "Error loading 'beheerder'"
  end

  def samensteller(params)
    resolve('./config/constructs/expanded_samensteller.sparql', 'samensteller_id', 'Samensteller', params['id']).to_json
  rescue StandardError => e
    raise RuntimeError, "Error loading 'samensteller'"
  end

  private

  include Logic::Helper

  def ui_lijst(key, params)
    result = {}

    result = cache[key] if cache.key?(key)

    if result.nil? || result.empty? || (params.key?(:from_cache) && params[:from_cache].eql?('0'))
      f = Stopwords::Snowball::Filter.new "nl"
      filename = "./config/constructs/#{key}.sparql"
      return result unless File.exist?(filename)

      q = File.read(filename)
      c = Solis::Store::Sparql::Client.new(Solis::ConfigFile[:solis][:sparql_endpoint], Solis::ConfigFile[:solis][:graph_name])
      r = c.query(q)
      t = r.query('select * where{?s ?p ?o}')

      result = {}
      u = {}
      t.each do |s|
        u[s.s.value] = {} unless u.key?(s.s.value)
        u[s.s.value][s.p.value.split('/').last] = s.o.value
      end

      u.each do |k, v|
        n = v['naam']
        next if n.nil? || n.empty?
        az = f.filter(n.downcase.gsub(/^\W*/, ' ').strip.gsub(/[^\w|\s|[^\x00-\x7F]+\ *(?:[^\x00-\x7F]| )*]/, '').split).join(' ')[0] rescue '0'
        az = '0' if az.nil?

        naam = result[az] || []
        naam << n
        naam.uniq!
        naam.compact!
        result[az] = naam
      end

      result = result.sort.to_h
      cache.store(key, result, expires: 86400)
    end

    result
  rescue StandardError => e
    puts e.message
    {}
  end
end