require 'solis/options'
require 'solis/query'
require 'date'
require 'lib/logic_helper'
require 'csv'

module Logic
  module Statistic

    def aantal_fiches_in_archiefpunt(params={})
      required_parameters(params, [:jaar])

      jaar = params[:jaar]
      q =%(
select ?type ?reden ?gebruiker ?instelling (count(?soc) as ?aantal) ?jaar ?maand ?jaar_maand from audit:
      where{
        ?change_set_id audit:subject_of_change ?soc;
          audit:created_date ?datum;
          audit:change_reason ?reden;
          audit:creator_name ?gebruiker;
          audit:creator_group ?instelling;
          a audit:ChangeSet.

        bind(year(?datum) as ?jaar)
        bind(month(?datum) as ?maand)
	      bind(concat('"',str(year(?datum)),'-',str(month(?datum)),'"') as ?jaar_maand)
		    bind(strbefore(lcase(replace(str(?soc), "https://data.q.archiefpunt.be/","")), "/") as ?type)
        filter(?datum > '#{jaar}-01-01'^^xsd:dateTime && ?datum < '#{jaar}-12-31'^^xsd:dateTime)
      }
group by ?type ?gebruiker ?instelling ?reden ?jaar_maand ?jaar ?maand
order by ?jaar ?maand ?gebruiker ?type
      )

      aantal = Solis::Query.run('stats', count_query(q))
      result = Solis::Query.run('stats', header + q)
      csv_header = result.first.keys.map{|m| m.to_s}.join(',')
      csv_data = result.map{|m| m.values.join(',')}.join("\n")

      if params.key?(:accept) && params[:accept].eql?('text/csv')
        csv_header+"\n"+csv_data
      else
        {aantal: aantal.first[:aantal].to_i, data: result}.to_json
      end

    rescue StandardError => e
      raise RuntimeError, e.message
    end

    private
    include Logic::Helper
    def config
      Solis::ConfigFile[:services][:audit]
    end
    def count_query(query)
      %(
#{header}
select ?entity (count(*) as ?aantal)  from audit:
where {
        {
#{query}
        }
      }
)
    end

    def header
      %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX audit: <#{Solis::Options.instance.get[:graph_name]}>
      )
    end
  end
end
