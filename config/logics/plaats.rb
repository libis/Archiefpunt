require 'solis/query'
require 'solis/options'
require 'active_support/all'

module Logic
  def plaats(params = {})
    result = cache['plaats'] || nil

    if result.nil? || result.empty? || (params.key?(:from_cache) && params[:from_cache].eql?('0'))

      query = %(
prefix abv: <https://data.archiefpunt.be/>
construct {
 ?s a abv:Plaats;
    abv:label ?naam_nl.
}
where {
  ?s ?p ?o ;
    a abv:Plaats.

  optional{
    ?s abv:plaatsnaam/abv:waarde ?naam.
  }

  FILTER (lang(?naam) = 'nl')
  bind(str(?naam) as ?naam_nl)
}
      )

      result = Solis::Query.run('Plaats', query)
      cache.store('plaats', result, expires: 86400)
    end

    result.to_json
  end
end