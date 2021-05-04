# Add a todo item
post "/lists/:id/todos" do
  id = params[:id].to_i
  todo = params[:todo].strip
  session[:lists][id][:todos] << todo
  redirect "/lists"  
end


<% params[:todo] %>