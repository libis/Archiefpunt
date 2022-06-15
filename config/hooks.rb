module Solis
  module HooksHelper
    def self.hooks(queue)
      {
        hooks: {
          read: {
            before: lambda do |scope|
              puts "-----------before - #{Graphiti.context[:object].query_user}"
              scope
            end,
            after: lambda do |data|
              puts "-----------after - #{Graphiti.context[:object].query_user}"

              audit_ids = data.map{|m| "<#{m.class.graph_name}#{m.name.tableize}/#{m.id}>"}

              pp audit_ids
            end
          },
          create: {
            before: lambda do |model|

              if model.class.metadata[:attributes].keys.include?('identificatienummer') && model.identificatienummer.nil?
                model.identificatienummer = Identificatienummer.new(id: model.id, waarde: 'Archiefpunt', type: {id: '13A6-70DC-CCB6-1996-97651CTTI9A4'})
                #model.identificatienummer = Identificatienummer.new(id: model.id)
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
        if model.instance_variable_get("@#{m}").class.ancestors.include?(Solis::Model)
          n[m] = properties_to_hash(model.instance_variable_get("@#{m}"))
        else
          n[m] = model.instance_variable_get("@#{m}")
        end
      end

      n
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
        misc: Graphiti.context[:object].other_data || {},
        change_reason: reason
      }
    end
  end
end
