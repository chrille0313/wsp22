require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'

enable :sessions


helpers do 

end


# TODO - Add before-blocks to authenticate users before certain routes
# TODO - Add after-blocks to check for redirects 


before do
    # Alerts
    if not session[:alerts]
        session[:alerts] = []
    end

    session[:last_alerts] = session[:alerts]
end

after do
    # Alerts
    if session[:alerts] == session[:last_alerts]
        session[:alerts] = []
    end
end


get('/')  do
  slim(:index)
end


# USERS

before(combine_urls('/login', '/users/new')) do
    userId = session[:userId]
    if userId != nil
        redirect("/users/#{userId}")
    end
end

before("/users/:id") do
    if string_is_int(params[:id]) && params[:id].to_i != session[:userId]
        redirect("/error/401")
    end
end

get('/users/new') do
    slim(:'users/new')
end

get('/users/:id') do
    id = params[:id].to_i
    account = get_account(id, "database")
    role = account["role"]

    if role == ROLES[:admin]
        data = { fname: account["username"], role: role }
    elsif role == ROLES[:customer]
        data = get_customer(account["id"], "database")
        data[:role] = role
    end
    
    slim(:'users/show', locals:{ user: data })
end

post('/users') do
    username = params[:username]
    password = params[:password]
    confirmPassword = params[:'confirm-password']

    fname = params[:fname]
    lname = params[:lname]
    email = params[:email]
    address = params[:address]
    city = params[:city]
    postalCode = params[:'postal-code']

    success, responseMsg = register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode)

    p success, responseMsg

    if success
        authenticate_user(username, password)
        session[:alerts] = [make_notification("success", responseMsg)]
        redirect('/')
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        redirect('/users/new')
    end
end

get('/login') do
    slim(:login)
end

post('/login') do
    username = params[:username]
    password = params[:password]

    success, msg = authenticate_user(username, password)

    if success
        session[:userId] = msg.to_i
        session[:alerts] = [make_notification("success", "Successfully logged in!")]
        redirect('/')
    else
        session[:alerts] = [make_notification("error", msg)]
        redirect('/login')
    end
end

before('/logout') do
    if session[:userId] == nil
        redirect('/')
    end
end

get('/logout') do
    session[:userId] = nil
    session[:alerts] = [make_notification("success", "Successfully logged out!")]
    redirect('/')
end


# PRODUCTS

get('/products') do
    slim(:'/products/index')
end


# ERRORS

get('/error/:id') do
    errors = {
        401 => 'Unauthorized access.',
        404 => 'Page not found :('
    }

    if errors.has_key?(params[:id].to_i)
        errorId = string_is_int(params[:id]) ? params[:id].to_i : 404
        errorMsg = errors[errorId]
    else
        redirect('/error/404')
    end
    
    slim(:error, locals: {errorId: errorId, errorMsg: errorMsg})
end

not_found do
    redirect('/error/404')
end
