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


get('/')  do
  slim(:index)
end


# FIXME - Check if logged in and if so redirect to "/"
get('/users/new') do
    slim(:'users/new')
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

    if successs
        authenticate_user(username, password)
        redirect('/')
    else
        redirect('/users/new')
    end
end


# FIXME - Check if logged in and if so redirect to "/"
get('/login') do
    slim(:login)
end


post('/login') do
    username = params[:username]
    password = params[:password]

    success, msg = authenticate_user(username, password)

    if success
        session[:userId] = msg.to_i
        redirect('/')
    else
        p msg
        redirect('/login')
    end
end


get('/logout') do
    session.destroy()
    redirect('/')
end


get('/products') do
    slim(:'/products/index')
end


get('/error/:id') do
    errors = {
        401 => 'Unauthorized access.',
        404 => 'Page not found :('
    }

    errorId = params['id'].to_i
    errorMsg = errors[errorId]

    slim(:error, locals: {errorId: errorId, errorMsg: errorMsg})
end


get('*') do
    redirect('/error/404')
end
