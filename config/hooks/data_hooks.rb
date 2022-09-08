module Solis
  module HooksHelper
    def self.hooks(queue)
      {
        hooks: {
          read: {
            before: lambda do |scope|
              #puts "-----------before - #{Graphiti.context[:object].query_user}"
              scope
            end,
            after: lambda do |data|
              #puts "-----------after - #{Graphiti.context[:object].query_user}"

              data.map { |m| m._audit = "#{Solis::ConfigFile[:solis_data][:graph_name].gsub(/\/$/, '')}#{Solis::ConfigFile[:services][:audit_logic][:base_path]}/list?id=#{m.id}&entity=#{m.class.name.underscore}"; m }
              audit_ids = data.map { |m| m.id }

              unless audit_ids.nil? || audit_ids.empty?
                if File.exists?("./config/constructs/bronverwijzing_#{data.first.class.name.underscore}.sparql")
                  bronverwijzingen = Solis::Query.run_construct_with_file("./config/constructs/bronverwijzing_#{data.first.class.name.underscore}.sparql", "#{data.first.class.name.underscore}_id", data.first.class.name, audit_ids)

                  if data && bronverwijzingen && !bronverwijzingen.empty?
                    bronverwijzingen.each do |bronverwijzing|
                      link = ''

                      if data.first.class.name.eql?('Agent')
                        q = %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX abv: <https://data.archiefpunt.be/>

select distinct ?id ?entity_type where {
	values ?agent_id { {{VALUES}} }
  ?s abv:agent ?agent_id;
     abv:id ?id;
  rdf:type ?entity_type.

  filter (?entity_type in ( <#{Solis::ConfigFile[:solis_data][:graph_name]}Samensteller>, <#{Solis::ConfigFile[:solis_data][:graph_name]}Archief>, <#{Solis::ConfigFile[:solis_data][:graph_name]}Beheerder>) )
}
                    ).gsub(/{{VALUES}}/, "<#{bronverwijzing["id"]}>")

                        qr = Solis::Query.run('Agent', q)
                        unless qr.empty?
                          id = qr.first[:id]
                          entity_type = qr.first[:entity_type].split('/').last.underscore
                        end
                        link = "/#{entity_type}/#{id}"
                      end

                      entity = data.find{|f| f.id.eql?(bronverwijzing['id'].split('/').last)}

                      if entity.instance_variable_names.include?("@bronverwijzing_archief")
                        bronverwijzing_archief = bronverwijzing['archiefbestand'].is_a?(Array) ? bronverwijzing['archiefbestand'].first : bronverwijzing['archiefbestand']
                        entity.bronverwijzing_archief = bronverwijzing_archief.gsub(/{{LINK}}/, link)
                      end

                      if entity.instance_variable_names.include?("@bronverwijzing_record")
                        bronverwijzing_record = bronverwijzing['archiefbankrecord'].is_a?(Array) ? bronverwijzing['archiefbankrecord'].first : bronverwijzing['archiefbankrecord']
                        entity.bronverwijzing_record = bronverwijzing_record.gsub(/{{LINK}}/, link)
                      end
                    end
                  end
                end
              end
              data
            end
          },
          create: {
            before: lambda do |model|

              if model.class.metadata[:attributes].keys.include?('identificatienummer') && model.identificatienummer.nil?
                model.identificatienummer = Identificatienummer.new(id: model.id, waarde: 'Archiefpunt', type: { id: '13A6-70DC-CCB6-1996-97651CTTI9A4' })
                #model.identificatienummer = Identificatienummer.new(id: model.id)
              end

              model.class.metadata[:attributes].select { |k, v| v[:node_kind].is_a?(RDF::URI) }.keys.each do |k|
                inner_model = model.instance_variable_get(:"@#{k}")
                if inner_model
                  if inner_model.is_a?(Hash)
                    unless inner_model.key?('id')
                      inner_model['id'] = model.id
                    end
                    inner_model.identificatienummer = Identificatienummer.new(id: model.id, waarde: 'Archiefpunt', type: { id: '13A6-70DC-CCB6-1996-97651CTTI9A4' })
                  else
                    if model.class.metadata[:attributes][k][:node].is_a?(RDF::URI) && inner_model.instance_variable_get(:'@identificatienummer').nil? && inner_model.class.metadata[:attributes].key?('identificatienummer')
                      inner_model.identificatienummer = Identificatienummer.new(id: inner_model.id, waarde: 'Archiefpunt', type: { id: '13A6-70DC-CCB6-1996-97651CTTI9A4' })
                    end
                  end
                end
              end

              n = properties_to_hash(model)
              n.delete("_audit") if n.key?('_audit')

              diff = Hashdiff.best_diff({}, n)

              unless diff.empty?
                new_data = build_data('create', diff, model)

                queue.push(new_data)
              end
            end
          },
          update: {
            before: lambda do |model, updated_model|
              n = properties_to_hash(model)
              o = properties_to_hash(updated_model)
              n.delete("_audit") if n.key?('_audit')
              o.delete("_audit") if o.key?('_audit')

              diff = Hashdiff.best_diff(o, n)

              unless diff.empty?
                new_data = build_data('update', diff, model)

                queue.push(new_data)
              end
            end
          },
          delete: {
            before: lambda do |model|
              n = properties_to_hash(model)
              n.delete("_audit") if n.key?('_audit')
              diff = Hashdiff.best_diff(n, {})
              unless diff.empty?
                new_data = build_data('delete', diff, model)

                queue.push(new_data)
              end
            end
          }
        }
      }
    end

    private

    def self.properties_to_hash(model)

      n = {}
      model.class.metadata[:attributes].each_key do |m|
        if model.instance_variable_get("@#{m}").is_a?(Array)
          n[m] = model.instance_variable_get("@#{m}").map { |iv| iv.class.ancestors.include?(Solis::Model) ? properties_to_hash(iv) : iv }
        elsif model.instance_variable_get("@#{m}").class.ancestors.include?(Solis::Model)
          n[m] = properties_to_hash(model.instance_variable_get("@#{m}"))
        else
          n[m] = model.instance_variable_get("@#{m}")
        end
      end

      n.compact!
    end

    def self.build_data(reason, diff, model)
      new_data = {
        entity: {
          id: model.id,
          name: model.name,
          name_plural: model.name(true),
          graph: model.class.graph_name
        },
        diff: diff,
        timestamp: Time.now,
        user: Graphiti.context[:object].query_user || 'unknown',
        group: Graphiti.context[:object].query_group || 'unknown',
        misc: Graphiti.context[:object].other_data || {},
        change_reason: reason
      }
    end
  end
end