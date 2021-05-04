require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

#-----------------------------------------------------------------
# PATH PLANNING
# modified - makes it easier to guess the url that will achieve
# a desired outcome

# GET  /lists       -> view all lists
# GET  /lists/new   -> new list form
# POST /lists       -> create new list
# GET  /list/1      -> view a single list

#-----------------------------------------------------------------

# View list of all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

#-----------------------------------------------------------------
# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

#-----------------------------------------------------------------
# Return error message if list name invalid, return nil otherwise
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters long."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created!"
    redirect "/lists"
  end
end

#-----------------------------------------------------------------
# View speific to do list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

#-----------------------------------------------------------------
# Edit existing to do list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

#-----------------------------------------------------------------
# Update existing to do list
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if @list[:name] == list_name
    @list[:name] = list_name
    session[:success] = "The list has been updated!"
    redirect "/lists/#{@list_id}"
  elsif error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated!"
    redirect "/lists/#{@list_id}"
  end
end

#-----------------------------------------------------------------
# Delete existing to do list
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = "The list has been successfully deleted."
  redirect "/lists"
end

#-----------------------------------------------------------------
# Return error message if to do text invalid, return nil otherwise
def error_for_todo(todo)
  if !(1..100).cover? todo.size
    "To do must be between 1 and 100 characters long."
  end
end

# Add a to do to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_text = params[:todo].strip

  error = error_for_todo(todo_text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_text, completed: false }
    session[:success] = "The to do item has been added!"
    redirect "/lists/#{@list_id}"
  end
end

#-----------------------------------------------------------------
# Delete a to do from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

#-----------------------------------------------------------------
# Update to do completion status
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The to do has been updated!"
  redirect "/lists/#{@list_id}"
end

#-----------------------------------------------------------------
# Mark as complete all items on a to do list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All to do items have been completed!"

  redirect "/lists/#{@list_id}"
end

