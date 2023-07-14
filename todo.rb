require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'f5246446f438dd9901236f444ac56259d32831b7216301325cb8b17a7e017193'
end

helpers do
  def list_complete?(list)
    todos_remaining_count(list) == 0 && todos_total_count(list) > 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_total_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each { |list| yield list, lists.index(list) }
    complete.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }
    
    incomplete.each { |todo| yield todo, todos.index(todo) }
    complete.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return error message string if name is invalid or nil if valid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    'Todo must be between 1 and 100 characters.'
  end
end

def load_list(id)
  list = session[:lists][id] if id && session[:lists][index]
  return list if list
  
  session[:error] = "The specified list was not found."
  redirect '/lists'
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View Todos on a Single List
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit Existing To-Do List
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update Existing To-Do List
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Delete Existing To-Do List
post '/lists/:id/delete' do
  id = params[:id].to_i
  list = session[:lists].delete_at(id)
  session[:success] = "The list '#{list[:name]}' has been deleted."
  
  redirect '/lists'
end

# Add Todos to a List
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo_name, completed: false}
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete Existing Todo from List
post '/lists/:list_id/todos/:id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  deleted_todo = @list[:todos].delete_at(todo_id)
  session[:success] = "The todo '#{deleted_todo[:name]}' has been deleted."

  redirect "/lists/#{@list_id}"
end

# Update Todo Status
post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i
  completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = completed
  session[:success] = "The todo has been updated."

  redirect "/lists/#{@list_id}"
end

# Complete all todos in a list
post '/lists/:id/complete_all' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been updated."

  redirect "/lists/#{@list_id}"
end