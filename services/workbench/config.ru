require 'sinatra'
require 'sinatra/contrib'
require 'data_collector'

require 'app/controllers/main_controller'

use Rack::RewindableInput::Middleware

map "/#{DataCollector::ConfigFile[:endpoint]}" do
  run MainController
end