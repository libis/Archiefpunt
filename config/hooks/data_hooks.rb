module Solis
  module HooksHelper
    def self.hooks(queue)
      {
        hooks: {
          read: {
            before: lambda do |scope|
              # puts "-----------before - #{Graphiti.context[:object].query_user}"
              scope
            end,
            after: lambda do |data|
              # puts "-----------after - #{Graphiti.context[:object].query_user}"

              data.map { |m| m._audit = "#{Solis::ConfigFile[:solis_data][:graph_name].gsub(/\/$/, '')}#{Solis::ConfigFile[:services][:audit_logic][:base_path]}/list?id=#{m.id}&entity=#{m.class.name.underscore}"; m }
              audit_ids = data.map { |m| m.id }

              unless audit_ids.nil? || audit_ids.empty?
                if File.exist?("./config/constructs/bronverwijzing_#{data.first.class.name.underscore}.sparql")
                  bronverwijzingen = Solis::Query.run_construct_with_file("./config/constructs/bronverwijzing_#{data.first.class.name.underscore}.sparql", "#{data.first.class.name.underscore}_id", data.first.class.name, audit_ids)

                  if data && bronverwijzingen && !bronverwijzingen.empty?
                    bronverwijzingen.each do |bronverwijzing|
                      link = ''

                      if data.first.class.name.eql?('Agent')
                        q = %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX abv: <#{Solis::Options.instance.get[:graph_name]}>

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

                      entity = data.find { |f| f.id.eql?(bronverwijzing['id'].split('/').last) }

                      # if entity.instance_variable_names.include?("@bronverwijzing_archief")
                      if entity.class.instance_methods.include?(:bronverwijzing_archief)
                        bronverwijzing_archief = bronverwijzing['archiefbestand'].is_a?(Array) ? bronverwijzing['archiefbestand'].first : bronverwijzing['archiefbestand']
                        entity.bronverwijzing_archief = bronverwijzing_archief.is_a?(String) ? bronverwijzing_archief.gsub(/{{LINK}}/, link) : bronverwijzing_archief
                      end

                      if entity.class.instance_methods.include?(:bronverwijzing_record)
                        # if entity.instance_variable_names.include?("@bronverwijzing_record")
                        bronverwijzing_record = bronverwijzing['archiefbankrecord'].is_a?(Array) ? bronverwijzing['archiefbankrecord'].first : bronverwijzing['archiefbankrecord']
                        entity.bronverwijzing_record = bronverwijzing_record.is_a?(String) ? bronverwijzing_record.gsub(/{{LINK}}/, link) : bronverwijzing_record
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
              if model.class.ancestors.include?(Codetabel)
                model = model.query.filter({ language: nil, filters: { id: [model.id] } }).find_all.map { |m| m }&.first
              end
              if model.class.metadata[:attributes].keys.include?('identificatienummer') && model.identificatienummer.nil?
                model.identificatienummer = Identificatienummer.new(id: model.id, waarde: "BE/#{model.id}", type: { id: '36E3-3A9D-FAB6-A870-5A751CTTI9A4' }) # persistente URI
                #model.save
              end

              model.class.metadata[:attributes].select { |k, v| v[:node_kind].is_a?(RDF::URI) }.keys.each do |k|
                inner_models = model.instance_variable_get(:"@#{k}")
                inner_models = [inner_models] unless inner_models.is_a?(Array)
                inner_models.each do |inner_model|
                  if inner_model
                    if inner_model.is_a?(Hash)
                      unless inner_model.key?('id')
                        inner_model['id'] = model.id
                      end
                      inner_model.identificatienummer = Identificatienummer.new(id: inner_model.id, waarde: "BE/#{inner_model.id}", type: { id: '36E3-3A9D-FAB6-A870-5A751CTTI9A4' })
                        # next if (inner_model.instance_values.keys - ["model_name", "model_plural_name", "language"]).eql?(["id"])
                    else
                      if inner_model.class.ancestors.include?(Codetabel)
                        existing_inner_model = inner_model.query.filter({ language: nil, filters: { id: [inner_model.id] } }).find_all.map { |m| m }&.first
                        unless existing_inner_model.nil?
                          inner_model = existing_inner_model
                          model.instance_variable_set(:"@#{k}", inner_model)
                        end
                      end

                      if model.class.metadata[:attributes][k][:node].is_a?(RDF::URI) && inner_model.instance_variable_get(:'@identificatienummer').nil? && inner_model.class.metadata[:attributes].key?('identificatienummer')
                        #next if (inner_model.instance_values.keys - ["model_name", "model_plural_name", "language"]).eql?(["id"])
                          inner_model.identificatienummer = Identificatienummer.new(id: inner_model.id, waarde: "BE/#{inner_model.id}", type: { id: '36E3-3A9D-FAB6-A870-5A751CTTI9A4' })
                      end
                    end
                  end
                end
              end


              traverse_model(model) do |m,n|
                traverse_model(m) do |s,t|
                  traverse_model(s) do |u,v|
                    if codetabel_lijst.include?(u.class.name)
                      s.instance_variable_set(:"@#{v}", u.class.new(id: u.id))
                    end
                  end
                  if codetabel_lijst.include?(s.class.name)
                    m.instance_variable_set(:"@#{t}", s.class.new(id: s.id))
                  end
                end
              end

              #puts model.to_ttl(true)

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
              if model.class.metadata[:attributes].keys.include?('identificatienummer') && updated_model.identificatienummer.nil?
                updated_model.identificatienummer = Identificatienummer.new(id: updated_model.id, waarde: "BE/#{updated_model.id}", type: { id: '36E3-3A9D-FAB6-A870-5A751CTTI9A4' }) # persistente URI
                model.identificatienummer = Identificatienummer.new(id: model.id, waarde: "BE/#{model.id}", type: { id: '36E3-3A9D-FAB6-A870-5A751CTTI9A4' }) # persistente URI
              end

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

    def self.codetabel_lijst
      c = Object.const_get('Codetabel'.to_sym)
      c.descendants.map { |m| m.name.to_s }
    end

    def self.traverse_model(models, &block)
      models = [models] unless models.is_a?(Array)
      models.each do |model|
        model.class.metadata[:attributes].select { |k, v| v[:node_kind].is_a?(RDF::URI) }.keys.each do |k|
          inner_models = model.instance_variable_get(:"@#{k}")
          inner_models = [inner_models] unless inner_models.is_a?(Array)
          inner_models.each do |inner_model|
            if inner_model
              yield inner_model, k if block_given?
            end
          end
        end
      end
    end
  end
end
