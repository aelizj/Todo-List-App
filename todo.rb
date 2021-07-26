require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

## CONFIG--------------------------------------------------------------------------------
configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

## HELPER METHODS------------------------------------------------------------------------
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

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

## METHODS-------------------------------------------------------------------------------
# Return error message if list_id invalid, return nil otherwise
def load_list(list_id)
  list = session[:lists].find { |list| list[:id] == list_id }
  return list if list

  session[:error] = "We couldn't find that list."
  redirect "/lists"
end

# Return the next available id number for to do items
def next_element_id(elements)
  max = elements.map { |el| el[:id] }.max || 0
  max + 1
end

# Return error message if list name invalid, return nil otherwise
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters long."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return error message if to do text invalid, return nil otherwise
def error_for_todo(todo)
  if !(1..100).cover? todo.size
    "To do must be between 1 and 100 characters long."
  end
end

def next_element_id(els)
  max = els.map { |todo| todo[:id] }.max || 0
  max + 1
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: []}

    session[:success] = "The list has been created!"
    redirect "/lists"
  end
end

# View a to do list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list_name = @list[:name]  #? Necessary?
  @list_id = @list[:id]      #? Necessary?

  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Edit existing to do list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Update existing to do list
post "/lists/:list_id" do
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

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

# Delete existing to do list
post "/lists/:list_id/delete" do
  list_id = params[:list_id].to_i
  session[:lists].reject! { |list| list[:id] == list_id }
  session[:success] = "The list has been successfully deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

# Add a to do to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_text = params[:todo].strip

  error = error_for_todo(todo_text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: todo_text, completed: false }

    session[:success] = "The to do item has been added!"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a to do from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update to do completion status
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The to do has been updated!"
  redirect "/lists/#{@list_id}"
end

# Mark all items on a to do list as complete
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All to do items have been completed!"

  redirect "/lists/#{@list_id}"
end
