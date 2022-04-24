require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'

enable :sessions


helpers do
    def is_authenticated()
        return session[:userId] != nil
    end
end


before do
    # Alerts
    if not session[:alerts]
        session[:alerts] = []
    end

    session[:last_alerts] = session[:alerts]
end

before('/cart') do
    if !authenticated()
        redirect('/login')
    end
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
    if is_authenticated()
        redirect("/users/#{session[:userId]}")
    end
end

before('/users/:id*') do
    if params[:id] == "new"
        return
    end
    
    if !is_authenticated()
        redirect("/login")
    elsif (string_is_int(params[:id]) && params[:id].to_i != session[:userId])
        redirect("/error/401")
    end
end

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

    session[:auto_fill] = {
        username: username,
        fname: fname,
        lname: lname,
        email: email,
        address: address,
        city: city,
        postalCode: postalCode
    }

    success, responseMsg = register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode)

    if success
        authenticate_user(username, password)
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect('/')
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        redirect('/users/new')
    end
end

get('/users/:id') do
    id = params[:id].to_i
    account = get_account(id, "database")

    data = {account: account}

    if account["role"] == ROLES[:customer]
        data[:user] = get_customer(account["id"], "database")
    end
    
    slim(:'users/show', locals: data)
end

get('/users/:id/edit') do
    accountId = params[:id].to_i
    account = get_account(accountId, "database")


    data = {account: account}

    if account["role"].to_i == ROLES[:customer]
        data[:user] = get_customer(accountId, "database")
    end
    
    slim(:'users/edit', locals: data)
end

# TODO: In htlm, use auto-fill to fill in the form
post('/users/:id/update') do
    id = params[:id].to_i
    username = params[:username]
    password = params[:password]
    confirmPassword = params[:'confirm-password']

    fname = params[:fname]
    lname = params[:lname]
    email = params[:email]
    address = params[:address]
    city = params[:city]
    postalCode = params[:'postal-code']

    session[:auto_fill] = {
        username: username,
        fname: fname,
        lname: lname,
        email: email,
        address: address,
        city: city,
        postalCode: postalCode
    }

    success, responseMsg = update_user(id, username, password, confirmPassword, fname, lname, email, address, city, postalCode)

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
    else
        session[:alerts] = [make_notification("error", responseMsg)]
    end

    redirect("/users/#{id}/edit")
end


get('/users/:id/delete') do
    accountId = params[:id].to_i
    success, responseMsg = delete_user(accountId)

    puts "deleted user"

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        puts "success"
        redirect("/logout")
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        puts "error"
        redirect("/users/#{id}/edit")
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
    if !is_authenticated()
        redirect('/')
    end
end

get('/logout') do
    session[:userId] = nil
    session[:alerts] = [make_notification("success", "Successfully logged out!")]
    redirect('/')
end


# CART
=begin
get('/cart') do
    # cart = get_cart(session[:userId], "database")
    # items = get_cart_items(cart["id"], "database")

    slim(:'cart/index') #, locals:{ cart: cart, items: items })
end
=end


# PRODUCTS

get('/products') do
    slim(:'/products/index')
end


# ERRORS

get('/error/:id') do
    errors = {
        401 => 'Unauthorized access.',
        404 => 'Page not found :(',
        500 => 'Internal server error.'
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



=begin


after("*") do
    p "after"
    p session[:next]
    if session[:next][-1] != nil
        url = session[:next].pop()
        redirect(url)
    end
end


get('/')  do
    session[:next] = []
    slim(:index)
end


=end