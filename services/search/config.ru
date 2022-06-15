$LOAD_PATH << '.'
raise 'Please set SERVICE_ROLE environment parameter' unless ENV.include?('SERVICE_ROLE')
$SERVICE_ROLE=ENV['SERVICE_ROLE'].downcase.to_sym
puts "setting SERVICE_ROLE=#{$SERVICE_ROLE}"

require 'rack/cors'
require 'logger'
require 'app/controllers/main_controller'
require 'lib/config_file'

LOGGER=Logger.new(STDOUT)

use Rack::Cors do
    allow do
        origins '*'
        resource '*', methods: [:get], headers: :any
    end
end


map "#{ConfigFile[:services][$SERVICE_ROLE][:base_path]}" do
    LOGGER.info("Mounting 'MainController' on #{ConfigFile[:services][$SERVICE_ROLE][:base_path]}")
    run MainController
end