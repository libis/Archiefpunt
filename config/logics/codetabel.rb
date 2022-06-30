require 'solis/query'
require 'solis/options'
require 'active_support/all'

module Logic
  def codetabel(params)
    if params['naam'].eql?('*')
      kv_codetabel = []
      codetabel_lijst.each do |v|
        kv_codetabel << {id: v.underscore, label: v.classify}
      end
      return kv_codetabel.to_json
    end

    naam = params['naam'].classify
    result = {}

    raise "#{naam} not a 'codetabel'" unless codetable?(naam)

    key = naam
    result = cache[key] if cache.key?(key)

    if result.nil? || result.empty? || (params.key?(:from_cache) && params[:from_cache].eql?('0'))

      query = %(
prefix abv: <#{Solis::Options.instance.get[:graph_name]}>
construct {
 ?s a abv:#{naam};
    abv:label ?o.
}
where {
  ?s ?p ?o ;
      abv:label ?o ;
a abv:#{naam}.
}
      )

#       query = %(
# prefix abv: <#{Solis::ConfigFile[:solis][:graph_name]}>
# select ?id ?naam
# where {
#   ?id abv:label ?naam ;
# a abv:#{naam}.
#
# }
#       )

      result = Solis::Query.run(naam, query)
      cache.store(key, result, expires: 86400)
    end
    result.to_json
  rescue StandardError => e
    puts e.message
    raise RuntimeError, "Error loading '#{naam}'. #{e.message}"
  end

  private
  def codetabel_lijst
    c = Object.const_get('Codetabel'.to_sym)
    c.descendants.map{|m| m.name.to_s}
  end

  def codetable?(naam)
    codetabel_lijst.include?(naam)
    #    ct = Object.const_get(naam.to_sym)
    #    ct ? ct.metadata[:target_node].value.eql?("#{Solis::Options.instance.get[:graph_name]}CodetabelShape") : false
  rescue StandardError => e
    false
  end
end