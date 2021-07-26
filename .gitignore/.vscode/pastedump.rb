# Add a todo item
post "/lists/:id/todos" do
  id = params[:id].to_i
  todo = params[:todo].strip
  session[:lists][id][:todos] << todo
  redirect "/lists"  
end


<% params[:todo] 



# PATH PLANNING
# modified - makes it easier to guess the url that will achieve
# a desired outcome

# GET  /lists       -> view all lists
# GET  /lists/new   -> new list form
# POST /lists       -> create new list
# GET  /list/1      -> view a single list
