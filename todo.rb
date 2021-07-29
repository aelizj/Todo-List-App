require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

## CONFIG----------------------------------------------------------------------
configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

## HELPER METHODS--------------------------------------------------------------
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
    complete_lists, incomplete_lists = lists.partition do |list|
      list_complete?(list)
    end

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition do |todo|
      todo[:completed]
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

## SESSION PERSISTENCE CLASS---------------------------------------------------
class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |l| l[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, new_list_name)
    list = find_list(id)
    list[:name] = new_list_name
  end

  def create_new_todo(list_id, todo_text)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << { id: id, name: todo_text, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }

  end

  def update_todo_completion_status(list_id, todo_id, new_completion_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = new_completion_status
  end

  def mark_all_todos_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_element_id(elements)
    max = elements.map { |el| el[:id] }.max || 0
    max + 1
  end
end

## METHODS---------------------------------------------------------------------
# Return error message if list_id invalid, return nil otherwise
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "We couldn't find that list."
  redirect "/lists"
end

# Return error message if list name invalid, return nil otherwise
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters long."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return error message if to do text invalid, return nil otherwise
def error_for_todo(todo)
  msg = "To do must be between 1 and 100 characters long."
  return msg unless (1..100).cover? todo.size
end

## PATHING---------------------------------------------------------------------
before do
  @storage = SessionPersistence.new(session)
end

get "/" do
  redirect "/lists"
end

# View list of all lists
get "/lists" do
  @lists = @storage.all_lists
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
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created!"
    redirect "/lists"
  end
end

# View a to do list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit existing to do list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update existing to do list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if @list[:name] == list_name
    @storage.update_list_name(id, list_name)
    session[:success] = "The list has been updated!"
    redirect "/lists/#{id}"
  elsif error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(id, list_name)
    session[:success] = "The list has been updated!"
    redirect "/lists/#{id}"
  end
end

# Delete existing to do list
post "/lists/:id/delete" do
  id = params[:id].to_i

  @storage.delete_list(id)

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
    @storage.create_new_todo(@list_id, todo_text)

    session[:success] = "The to do item has been added!"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a to do from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)
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
  @storage.update_todo_completion_status(@list_id, todo_id, is_completed)

  session[:success] = "The to do has been updated!"
  redirect "/lists/#{@list_id}"
end

# Mark all items on a to do list as complete
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_complete(@list_id)

  session[:success] = "All to do items have been completed!"
  redirect "/lists/#{@list_id}"
end
