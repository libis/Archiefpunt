# frozen_string_literal: true

module Solis
  module HooksHelper
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

    def self.hooks(queue)
      {
        hooks: {
          create: {
            before: lambda do |model|
              n = {}

              if model._meta.nil?
                model._meta = EntiteitMetadata.new({aangepast_op: Time.now, aangemaakt_op: Time.now, verwijderd_op: Time.now})
              else
                model._meta = EntiteitMetadata.new({id: model._meta.id, aangepast_op: Time.now, aangemaakt_op: Time.now})
              end

              n = properties_to_hash(model)
              n.delete("_meta") if n.key?('_meta')

              diff = Hashdiff.best_diff({}, n)

              unless diff.empty?
                new_data = {
                  entity: {
                    id: model.id,
                    name: model.name,
                    name_plural: model.name(true),
                    graph: model.class.graph_name
                  },
                  diff: diff,
                  timestamp: Time.now,
                  user: 'unknown',
                  change_reason: 'create'
                }

                queue.push(new_data)
              end
            end
          },
          delete: {
            before: lambda do |model|
              n = {}

              if model._meta.nil?
                model._meta = EntiteitMetadata.new({aangepast_op: Time.now, aangemaakt_op: Time.now, verwijderd_op: Time.now})
              else
                model._meta = EntiteitMetadata.new({id: model._meta.id, aangepast_op: model._meta.aangepast_op, aangemaakt_op: model._meta.aangemaakt_op, verwijderd_op: Time.now})
              end

              n = properties_to_hash(model)
              n.delete("_meta") if n.key?('_meta')

              diff = Hashdiff.best_diff(n, {})
              unless diff.empty?
                new_data = {
                  entity: {
                    id: model.id,
                    name: model.name,
                    name_plural: model.name(true),
                    graph: model.class.graph_name
                  },
                  diff: diff,
                  timestamp: Time.now,
                  user: 'unknown',
                  change_reason: 'delete'
                }

                queue.push(new_data)
              end
            end
          },
          update: {
            before: lambda do |model, updated_model|
              o = {}
              model.instance_variable_names.each do |m|
                o[m.gsub(/^@/, '')] =
                  model.instance_variable_get(m)
              end
              n = {}
              updated_model.instance_variable_names.each do |m|
                n[m.gsub(/^@/, '')] =
                  updated_model.instance_variable_get(m)
              end

              if model._meta.nil?
                updated_model._meta = EntiteitMetadata.new({aangepast_op: Time.now, aangemaakt_op: Time.now})
              else
                updated_model._meta = EntiteitMetadata.new({id: model._meta.id, aangepast_op: model._meta.aangepast_op, aangemaakt_op: Time.now})
              end

              n = properties_to_hash(model)
              o = properties_to_hash(updated_model)
              n.delete("_meta") if n.key?('_meta')
              o.delete("_meta") if o.key?('_meta')

              diff = Hashdiff.best_diff(o, n)

              unless diff.empty?
                new_data = {
                  entity: {
                    id: model.id,
                    name: model.name,
                    name_plural: model.name(true),
                    graph: model.class.graph_name
                  },
                  diff: Hashdiff.diff(o, n),
                  timestamp: Time.now,
                  user: 'unknown',
                  change_reason: 'update'
                }

                queue.push(new_data)
              end
            end
          }
        }
      }
    end
  end
end
