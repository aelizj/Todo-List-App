require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end


#------------------------------------------------------------------------
# Resource-based route names -- centered around resource being modified - makes it easier to guess the url that will achieve a desired outcome

# GET  /lists       -> view all lists
# GET  /lists/new   -> new list form
# POST /lists       -> create new list
# GET  /list/1      -> view a single list
#------------------------------------------------------------------------


# View all of the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  session[:lists] << { name: params[:list_name], todos: [] }
  redirect "/lists"
end

