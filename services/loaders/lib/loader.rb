require 'data_collector'

include DataCollector::Core

module LoaderHelper
  def logic_config
    Solis::ConfigFile[:services][:data_logic]
  end

  def elastic_config
    @elastic_config ||= Solis::ConfigFile[:services][:search][:elastic]
  end

  def load_data(elastic, total, filename, entity, entity_id)
    limit = 1000
    offset = 0

    while offset < total
      puts "#{entity} reading #{offset}/#{total}"
      ids = Solis::Query.run('', "SELECT DISTINCT ?s FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}#{entity}>.} limit #{limit} offset #{offset}").map { |m| m[:s] }

      s = 0
      e = 0
      step = 100

      while e < ids.length
        d = ids.length - e
        e = if d < step
              ids.length
            else
              s + step
            end

        data = Solis::Query.run_construct_with_file(filename, entity_id, entity, ids[s..e])
        #data = data.map{|m| {"#{entity.underscore}": m}}
        begin
          yield data, entity
        rescue StandardError => x
          puts x.message
        end

        s = e
      end
      offset += limit
    end
  rescue StandardError => x
    puts x.message
  end

  def apply_data_to_query_list(data, entity, query_list)
    new_data = []
    return new_data if data.nil?
    data.each do |d|
      id = filter(d, '$.id').first

      query_list.each do |index_key, v|
        v = [v] unless v.is_a?(Array)
        nd = []
        v.each do |w|
          w.each do |i, j|
            j = [j] unless j.is_a?(Array)
            j.each do |k|
              if k.is_a?(Hash)
                sout = {}
                k.each { |a, b|
                  t = filter(d, b)
                  t.each do |s|
                    # ss = sout.select{|s| s =~ /^#{a}/}
                    # if ss.length > 0
                    #   if ss.length == 1
                    #     sd = sout.delete(a)
                    #     sout["#{a}.#{sd.hash.abs.to_s(36)}"] = sd
                    #   end
                    #
                    #   sout["#{a}.#{s.hash.abs.to_s(36)}"] = s
                    # else
                    #   sout[a] = s
                    # end

                    #sout["#{a}.#{s.hash.abs.to_s(36)}"] = s
                    #sout[a] = s
                    if sout.key?(a)
                      sd = sout[a].is_a?(Array) ? sout[a] : [sout[a]]
                      sd << s

                      sout[a] = sd
                    else
                      sout[a] = s
                    end
                  end
                }
                #.hash.abs.to_s(36)

                nd << { index_key => { 'id' => id, i => sout } }
              else
                t = filter(d, k)
                t.each do |s|
                  if i.eql?('datering') || i.eql?('datering_systematisch')
                    gte, lte = s.to_s.split('/')
                    if s.is_a?(ISO8601::TimeInterval)
                      if s.size < 0
                        lte = s.start_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                        gte = s.end_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                      else
                        gte = s.start_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                        lte = s.end_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                      end

                      nd << { index_key => { 'id' => id, i => { 'gte' => gte, 'lte' => lte } } }
                    elsif s.is_a?(Array)
                      s.each do |e|
                        gte, lte = s.to_s.split('/')
                        if s.is_a?(ISO8601::TimeInterval)
                          if s.size < 0
                            lte = s.start_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                            gte = s.end_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                          else
                            gte = s.start_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                            lte = s.end_time.strftime('%Y-%m-%dT%H:%M:%S.%L%z').to_datetime.utc.iso8601
                          end
                        end
                        nd << { index_key => { 'id' => id, i => { 'gte' => gte, 'lte' => lte } } }
                      end
                    else
                      begin
                        intervals = ISO8601::TimeInterval.from_datetimes(ISO8601::DateTime.new(gte), ISO8601::DateTime.new(lte))
                        if intervals.size < 0
                          nd << { index_key => { 'id' => id, i => { 'gte' => intervals.end_time.to_datetime.utc.iso8601, 'lte' => intervals.start_time.to_datetime.utc.iso8601 } } }
                        else
                          nd << { index_key => { 'id' => id, i => { 'gte' => intervals.start_time.to_datetime.utc.iso8601, 'lte' => intervals.end_time.to_datetime.utc.iso8601 } } }
                        end
                      rescue StandardError => e
                        nd << { index_key => { 'id' => id, i => { 'gte' => gte, 'lte' => lte } } }
                      end
                    end
                  else
                    nd << { index_key => { 'id' => id, i => s } }
                  end
                end
              end
            end
          end
        end

        if v.length == 1
          new_data.concat(nd)
        else
          tnd = {}
          nd.map { |m| m[index_key] }.compact.map { |m| m.delete_if { |k, v| k.eql?('id') } }.each { |e|
            if tnd.key?(e.keys.first)
              a = tnd[e.keys.first]
              # if a.is_a?(Hash)
              #   a = a.merge(e.values.first)
              # else
              a = [a] unless a.is_a?(Array)
              a << e.values.first
              # end

              tnd[e.keys.first] = a
            else
              tnd[e.keys.first] = e.values.first
            end
          }

          new_data << { index_key => { 'id' => id }.merge(tnd) }
        end
      end

      # new_data << { "#{entity.underscore}" => d }
    end
    new_data.each do |fiche|
      if fiche['fiche']['data']['datering_systematisch'].is_a?(Array)
        fiche['fiche']['data']['datering_systematisch'].each do |fiche_item|
          fiche_item = fiche_item.to_s unless fiche_item.is_a?(String)
        end
      elsif fiche['fiche']['data']['datering_systematisch']
        fiche['fiche']['data']['datering_systematisch'] = fiche['fiche']['data']['datering_systematisch'].to_s unless fiche['fiche']['data']['datering_systematisch'].is_a?(String)
      end

      if fiche['fiche']['data'].key?('agent') && !fiche['fiche']['data']['agent'].empty?
        fiche['fiche']['data']['agent'].each do |agent|
          agent['datering_systematisch'] = agent['datering_systematisch'].to_s unless agent['datering_systematisch'].is_a?(String)
        end
      end

    end

    new_data
  end

  def archieven_query_list
    {
      'fiche' => [{ 'sayt' => { 'titel' => '$..titel', 'beheerder' => '$..beheerder[*].naam', 'samensteller' => '$..samensteller[*].naam', 'agent' => '$..beheerder[*].naam', 'trefwoord' => '$..associatie[*].onderwerp', 'geografie' => ["$..associatie[*].plaatsnaam", "$..beheerder[*].adres[*].gemeente"] } },
                  { 'titel' => '$..titel' },
                  { 'record_type' => '$..record_type' },
                  { 'beschrijvingsniveau' => '$..beschrijvingsniveau' },
                  { 'beheerder' => { 'naam' => '$..beheerder[*].naam', 'rol' => '$..beheerder[*].rol' } },
                  { 'geografie' => ["$..associatie[*].plaatsnaam", "$..beheerder[*].adres[*].gemeente"] },
                  { 'samensteller' => { 'naam' => '$..samensteller[*].naam', 'rol' => '$..samensteller[*].rol' } },
                  { 'agent' => [{ 'naam' => '$..beheerder[*].naam', 'record_type' => '$..beheerder[*].rol' }, { 'naam' => '$..samensteller[*].naam', 'record_type' => '$..samensteller[*].rol' }] },
                  { 'trefwoord' => '$..associatie[*].onderwerp' },
                  { 'materiaal_type' => '$..omvang[*].trefwoord' },
                  { 'datering' => '$..datering_systematisch' },
                  { 'datering_text' => '$..datering_text' },
                  { 'generated_date' => '$..generated_date' },
                  { 'data' => '@' }]
    }
  end


  def load_archieven(elastic)
    total_archieven = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Archief>.}").first[:count].to_i
    load_data(elastic, total_archieven, './config/constructs/expanded_archief3.sparql', 'Archief', 'archief_id') do |data, entity|

      new_data = apply_data_to_query_list(data, entity, archieven_query_list)

      elastic.index.insert(new_data, 'id', true)
    end
  end

  def beheerders_query_list
    {
      'fiche' => [{ 'sayt' => { 'beheerder' => '$..agent[*].naam[*].waarde', 'agent' => '$..agent[*].naam[*].waarde', 'geografie' => "$..adres[*].gemeente" } },
                  { 'record_type' => '$..record_type' },
                  { 'beheerder' => { 'naam' => '$..agent[*].naam[*].waarde', 'rol' => '$..agent[*].naam[*].type' } },
                  { 'agent' => { 'naam' => '$..agent[*].naam[*].waarde', 'record_type' => '$..record_type' } },
                  { 'geografie' => "$..adres[*].gemeente" },
                  { 'datering' => '$..agent[*].datering_systematisch' },
                  { 'datering_text' => '$..datering_text' },
                  { 'generated_date' => '$..generated_date' },
                  { 'data' => '@' }
      ]
    }
  end

  def load_beheerders(elastic)
    totaal_beheerders = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Beheerder>.}").first[:count].to_i
    load_data(elastic, totaal_beheerders, './config/constructs/expanded_beheerder.sparql', 'Beheerder', 'beheerder_id') do |data, entity|

      new_data = apply_data_to_query_list(data, entity, beheerders_query_list)
      elastic.index.insert(new_data, 'id', true)
    end
  end

  def samenstellers_query_list
    {
      'fiche' => [{ 'record_type' => '$..record_type' },
                  { 'sayt' => { 'samensteller' => '$..agent[*].naam[*].waarde', 'agent' => '$..agent[*].naam[*].waarde', 'geografie' => "$..agent[*].associaties[*].plaats" } },
                  { 'samensteller' => { 'naam' => '$..agent[*].naam[*].waarde', 'rol' => '$..agent[*].type' } },
                  { 'agent' => { 'naam' => '$..agent[*].naam[*].waarde', 'record_type' => '$..record_type' } },
                  { 'geografie' => "$..agent[*].associaties[*].plaats" },
                  { 'datering' => '$..agent[*].datering_systematisch' },
                  { 'datering_text' => '$..datering_text' },
                  { 'generated_date' => '$..generated_date' },
                  { 'data' => '@' }]
    }
  end
  def load_samenstellers(elastic)
    totaal_samenstellers = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Samensteller>.}").first[:count].to_i
    load_data(elastic, totaal_samenstellers, './config/constructs/expanded_samensteller.sparql', 'Samensteller', 'samensteller_id') do |data, entity|

      new_data = apply_data_to_query_list(data, entity, samenstellers_query_list)
      elastic.index.insert(new_data, 'id', true)
    end
  end

  def load_plaatsen(elastic)
    response = HTTP.get("#{logic_config[:host]}/#{logic_config[:base_path]}/plaats")
    data = {}
    if response.status == 200
      data = JSON.parse(response.body.to_s)
    end

    plaatsen = []
    data.each do |d|
      plaatsen << { "plaats": d }
    end

    elastic.index.insert(plaatsen, 'id', true)
  end
end