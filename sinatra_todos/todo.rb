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
# 
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

# Return an error message if the list name is invalid, otherwise return nil
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters long."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, id: session[:lists].size,  todos: []}
    session[:success] = "The list has been created!"
    redirect "/lists"
  end
end

get "/lists/:id" do
  id = params[:id].to_i
  @lists = session[:lists]
  @list = []
  session[:lists].each do |hash|
    @list << hash if hash[:id] == id
  end
  erb :list, layout: :layout
end