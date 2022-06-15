$LOAD_PATH << '.'
require 'logger'
require 'solis'
require 'sinatra/base'
require 'app/controllers/main_controller'

LOGGER=Logger.new(STDOUT)

map "#{Solis::ConfigFile[:services][:logic][:base_path]}" do
  LOGGER.info("Mounting 'MainController' on #{Solis::ConfigFile[:services][:logic][:base_path]}")
  run MainController
end