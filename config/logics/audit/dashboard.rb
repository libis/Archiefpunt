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
      select distinct (?persoon as ?entity) ?soc from audit:
      where{
      values ?persoon{#{ids}}
        ?change_set_id audit:creator_name ?persoon;
    	  audit:subject_of_change ?soc;
          audit:created_date ?datum;
          audit:change_reason ?reason;
          a audit:ChangeSet.

        filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
      }
    order by ?soc
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def bewerkte_fiches_groep(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      q=%(
      select distinct (?groep as ?entity) ?soc from audit:
      where{
      values ?groep{#{ids}}
        ?change_set_id audit:creator_group ?groep;
    	  audit:subject_of_change ?soc;
          audit:created_date ?datum;
          audit:change_reason ?reason;
          a audit:ChangeSet.

        filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
      }
    order by ?soc
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def aangemaakte_fiches_persoon(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])


      q=%(
      select distinct (?persoon as ?entity) ?soc from audit:
      where{
      values ?persoon{#{ids}}
        ?change_set_id audit:creator_name ?persoon;
    	  audit:subject_of_change ?soc;
          audit:created_date ?datum;
          audit:change_reason 'create';
          a audit:ChangeSet.

        filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
      }
    order by ?soc
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def aangemaakte_fiches_groep(params={})
      required_parameters(params, [:id, :van, :tot])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      q=%(
      select distinct (?groep as ?entity) ?soc from audit:
      where{
      values ?groep{#{ids}}
        ?change_set_id audit:creator_group ?groep;
    	  audit:subject_of_change ?soc;
          audit:created_date ?datum;
          audit:change_reason 'create';
          a audit:ChangeSet.

        filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
      }
    order by ?soc
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def verrijkte_fiches_persoon(params={})
      required_parameters(params, ['id', 'van', 'tot'])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      #endpoint voor fiches die aangemaakt zijn door persoon met creator_name X, en bewerkt zijn door iemand anders tussen datum Y & datum Z (waar X,Y,Z parameters zijn)
      q=%(
select distinct ?entity (?b_soc as ?soc) from audit:
where {

{
    select distinct ?a_change_set_id ?entity from audit:
    where{
	    values ?entity{#{ids}}
    	?a_change_set_id audit:creator_name ?entity;
	        audit:subject_of_change ?a_soc;
		    audit:created_date ?datum;
            audit:change_reason 'create';
    		a audit:ChangeSet.
    }
}

{
    select distinct ?b_change_set_id ?b_soc ?datum from audit:
    where{
    	?b_change_set_id  audit:created_date ?datum;
			    audit:creator_name ?persoon;
    	        audit:subject_of_change ?b_soc;
            	audit:change_reason ?reason;
	    		a audit:ChangeSet.

	    filter(!contains(?reason, 'create'))
    }
}

    filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
    filter(?a_change_set_id != ?b_change_set_id)
  }
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    def verrijkte_fiches_groep(params={})
      required_parameters(params, ['id', 'van', 'tot'])

      ids = params[:id].split(',').map {|m| "'#{m}'"}.join(' ')
      van_datum = DateTime.parse(params[:van])
      tot_datum = DateTime.parse(params[:tot])

      #endpoint voor fiches die aangemaakt zijn door persoon met creator_name X, en bewerkt zijn door iemand anders tussen datum Y & datum Z (waar X,Y,Z parameters zijn)
      q=%(
select distinct ?entity (?b_soc as ?soc) from audit:
where {

{
    select distinct ?a_change_set_id ?entity from audit:
    where{
	    values ?entity{#{ids}}
    	?a_change_set_id audit:creator_group ?entity;
	        audit:subject_of_change ?a_soc;
		      audit:created_date ?datum;
          audit:change_reason 'create';
    		  a audit:ChangeSet.
    }
}

{
    select distinct ?b_change_set_id ?b_soc ?datum from audit:
    where{
    	?b_change_set_id  audit:created_date ?datum;
			    audit:creator_group ?groep;
    	    audit:subject_of_change ?b_soc;
          audit:change_reason ?reason;
	    		a audit:ChangeSet.

	    filter(!contains(?reason, 'create'))
    }
}

    filter(?datum > '#{van_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime && ?datum < '#{tot_datum.strftime('%Y-%m-%d')}'^^xsd:dateTime)
    filter(?a_change_set_id != ?b_change_set_id)
  }
      )

      perform_query(q)
    rescue StandardError => e
      raise RuntimeError, e.message
    end

    private

    def perform_query(q)
      c = Solis::Store::Sparql::Client.new(config[:solis][:sparql_endpoint], config[:solis][:graph_name])
      r_count = c.query(count_query(q))
      r = c.query(header + q)

      p_count = {}
      r_count.map { |m| p_count[m.entity.value] = m.aantal.value }

      data = {}
      r.map do |m|
        unless data.key?(m.entity.value)
          data[m.entity.value] = []
        end
        data[m.entity.value] << m.soc.value
      end

      result = []
      p_count.each do |entity_id, aantal|
        result << {
          id: entity_id,
          aantal: aantal,
          data: data[entity_id]
        }
      end

      result.to_json
    end

    include Logic::Helper
    def config
      Solis::ConfigFile[:services][:audit]
    end

    def header
      %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <https://data.archiefpunt.be/_audit/>
      )
    end

    def count_query(query)
      %(
      #{header}
      select ?entity (count(?soc) as ?aantal)  from audit:
      where {
        {
#{query}
        }
      }
)
    end
  end
end