require_relative 'generic_controller'
class MainController < GenericController
  get '/' do
    erb :index
  end
end