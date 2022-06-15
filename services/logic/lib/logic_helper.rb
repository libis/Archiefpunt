module Logic
  module Helper
    private
    def api_error(status, source, title="Unknown error", detail="")
      {"errors": [{
                    "status": status,
                    "source": {"pointer":  source},
                    "title": title,
                    "detail": detail
                  }]}
    end

    def required_parameters(params, required)
      if required.is_a?(Array)
        raise RuntimeError, api_error('400', '', "Missing parameter", "Missing parameter: one of #{required.join(', ')} is needed") unless (required.map(&:to_s) - params.keys.map(&:to_s)).empty?
      else
        raise RuntimeError, api_error('400', '', "Missing parameter", "Missing #{required.to_s} parameter") unless params.keys.map(&:to_s).include?(required.to_s)
      end
    rescue StandardError => e
      Solis::LOGGER.error('Unable to check required parameters')
      raise e
    end

    def resolve(filename, id_name, entity, ids, from_cache = '1')
      raise 'Please supply one or more uuid\'s' if ids.nil? || ids.empty?

      result = {}

      key = Digest::SHA256.hexdigest("#{entity}-#{ids}")
      result = cache[key] if cache.key?(key)

      if result.nil? || result.empty? || (from_cache.eql?('0'))
        f = File.read(filename)

        ids = ids.split(',').map { |m| "<#{Solis::ConfigFile[:solis][:graph_name]}#{entity.tableize}/#{m}>" }
        ids = [ids] unless ids.is_a?(Array)
        ids = ids.join(" ")

        q = f.gsub('{{VALUES}}', "VALUES ?#{id_name} { #{ids} }")

        result = Solis::Query.run(entity, q)
        cache.store(key, result, expires: 86400)
      end
      result
    rescue StandardError => e
      puts e.message
      raise e
    end

    def cache
      @cache ||= Moneta.new(:File, dir: Solis::ConfigFile[:cache], expires: 86400)
    end

  end
end
