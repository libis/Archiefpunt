require 'solis/options'
require 'solis/query'
require 'date'
require 'lib/logic_helper'

module Logic
  module Dashboard
    def bewerkte_fiches_persoon(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])


      q=%(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <https://data.archiefpunt.be/_audit/>

select ?persoon (count(?persoon) as ?aantal_bewerkte_fiches) from audit:
where {
  values ?persoon{#{ids}}
  ?s ?p ?o;
     audit:creator_name ?persoon;
     audit:created_date ?datum;
  a audit:ChangeSet

  filter(?datum > '#{van_datum.xmlschema}'^^xsd:dateTime && ?datum < '#{tot_datum.xmlschema}'^^xsd:dateTime)

}
group by ?persoon
      )

      c = Solis::Store::Sparql::Client.new(config[:solis][:sparql_endpoint], config[:solis][:graph_name])
      r=c.query(q)

      r.map{|m| {persoon: m.persoon.value, aantal_bewerkte_fiches: m.aantal_bewerkte_fiches.value, van: van_datum.xmlschema, tot: tot_datum.xmlschema} }.to_json
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def bewerkte_fiches_groep(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      q=%(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <https://data.archiefpunt.be/_audit/>

select ?groep (count(?groep) as ?aantal_bewerkte_fiches) from audit:
where {
  values ?groep{#{ids}}
  ?s ?p ?o;
     audit:creator_group ?groep;
     audit:created_date ?datum;
  a audit:ChangeSet

  filter(?datum > '#{van_datum.xmlschema}'^^xsd:dateTime && ?datum < '#{tot_datum.xmlschema}'^^xsd:dateTime)

}
group by ?groep
      )

      c = Solis::Store::Sparql::Client.new(config[:solis][:sparql_endpoint], config[:solis][:graph_name])
      r=c.query(q)

      r.map{|m| {groep: m.groep.value, aantal_bewerkte_fiches: m.aantal_bewerkte_fiches.value, van: van_datum.xmlschema, tot: tot_datum.xmlschema} }.to_json
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def aangemaakte_fiches_persoon(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])


      q=%(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <https://data.archiefpunt.be/_audit/>

select ?persoon (count(?persoon) as ?aantal_aangemaakte_fiches) from audit:
where {
  values ?persoon{#{ids}}
  ?s ?p ?o;
     audit:creator_name ?persoon;
     audit:created_date ?datum;
     audit:change_reason 'create'
  a audit:ChangeSet

  filter(?datum > '#{van_datum.xmlschema}'^^xsd:dateTime && ?datum < '#{tot_datum.xmlschema}'^^xsd:dateTime)

}
group by ?persoon
      )

      c = Solis::Store::Sparql::Client.new(config[:solis][:sparql_endpoint], config[:solis][:graph_name])
      r=c.query(q)

      r.map{|m| {persoon: m.persoon.value, aantal_aangemaakte_fiches: m.aantal_aangemaakte_fiches.value, van: van_datum.xmlschema, tot: tot_datum.xmlschema} }.to_json
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def aangemaakte_fiches_groep(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      q=%(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <https://data.archiefpunt.be/_audit/>

select ?groep (count(?groep) as ?aantal_aangemaakte_fiches) from audit:
where {
  values ?groep{#{ids}}
  ?s ?p ?o;
     audit:creator_groep ?groep;
     audit:created_date ?datum;
     audit:change_reason 'create'
  a audit:ChangeSet

  filter(?datum > '#{van_datum.xmlschema}'^^xsd:dateTime && ?datum < '#{tot_datum.xmlschema}'^^xsd:dateTime)

}
group by ?groep
      )

      c = Solis::Store::Sparql::Client.new(config[:solis][:sparql_endpoint], config[:solis][:graph_name])
      r=c.query(q)

      r.map{|m| {groep: m.groep.value, aantal_aangemaakte_fiches: m.aantal_aangemaakte_fiches.value, van: van_datum.xmlschema, tot: tot_datum.xmlschema} }.to_json
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def verrijkte_fiches_persoon(params={})
      required_parameters(params, ['id', 'van', 'tot'])
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def verrijkte_fiches_groep(params={})
      required_parameters(params, ['id', 'van', 'tot'])
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    private
    include Logic::Helper
    def config
      Solis::ConfigFile[:services][:audit]
    end
  end
end