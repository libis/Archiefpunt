$LOAD_PATH << '.'
require 'rack/cors'
require 'app/controllers/main_controller'

#raise 'Please set SERVICE_ROLE environment parameter' unless ENV.include?('SERVICE_ROLE')

#$SERVICE_ROLE=ENV['SERVICE_ROLE'].downcase.to_sym
$SERVICE_ROLE=:data
puts "setting SERVICE_ROLE=#{$SERVICE_ROLE}"

use Rack::Cors do
  allow do
    origins '*'
    resource '*', methods: [:get], headers: :any
  end
end


map "#{Solis::ConfigFile[:services][$SERVICE_ROLE][:base_path]}" do
  Solis::LOGGER.info("Mounting 'MainController' on #{Solis::ConfigFile[:services][$SERVICE_ROLE][:base_path]}")
  run MainController
end
