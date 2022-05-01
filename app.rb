require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'

enable :sessions


set :port, 80
set :bind, '192.168.10.157'


helpers do
    def is_authenticated()
        return session[:userId] != nil
    end

    def is_admin(role=nil)
        return (is_authenticated() and (role == nil ? session[:userRole] : role) == ROLES[:admin])
    end

    def log_time()
        session[:rate_limit] = Time.now.to_i
    end

    def is_rate_limited(diff)
        return Time.now.to_i - session[:rate_limit] < diff
    end
end


before do
    # Alerts
    if session[:alerts] == nil
        session[:alerts] = []
    end

    if session[:rate_limit] == nil
        log_time()
    end

    session[:last_alerts] = session[:alerts]
end

["/login", "/users", "/users/:id/update"].each do |path|
    before(path) do
        if request.request_method == "POST"
            if is_rate_limited(3)
                session[:alerts] = [make_notification("error", "You're doing that too much. Try again in a few seconds.")]
                redirect("/users/#{params[:id]}")
            end

            log_time()
        elsif request.request_method == "GET" and request.path_info == "/users"
            if !is_authenticated() or !is_admin()
                redirect("/error/401")
            end
        end
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
        if !(is_admin() && request.path_info == '/users/new')
            redirect("/users/#{session[:userId]}")
        end
    end
end

before('/users/:id*') do
    if params[:id] == "new"
        return
    end
    
    if !is_authenticated()
        redirect("/login")
    elsif !string_is_int(params[:id])
        redirect('/error/404')
    elsif !is_admin() && params[:id].to_i != session[:userId]
        redirect("/error/401")
    end
end

get('/users') do
    users = get_users("database")
    slim(:'users/index', locals: {users: users})
end

get('/users/new') do
    slim(:'users/new')
end

post('/users') do
    username = params[:username]
    password = params[:password]
    confirmPassword = params[:'confirm-password']
    role = params[:role]

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
        postalCode: postalCode,
        role: role
    }

    success, responseMsg = register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode, is_admin() ? role : ROLES[:customer])

    if success
        if !is_authenticated()
            authenticate_user(username, password)
        end
        
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

post('/users/:id/update') do
    id = params[:id].to_i
    username = params[:username]
    password = params[:password]
    confirmPassword = params[:'confirm-password']
    role = params[:role]

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
        postalCode: postalCode,
        role: role
    }

    success, responseMsg = update_user(id, username, password, confirmPassword, fname, lname, email, address, city, postalCode, is_admin() ? role : ROLES[:customer])

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
    else
        session[:alerts] = [make_notification("error", responseMsg)]
    end

    redirect("/users/#{id}/edit")
end


post('/users/:id/delete') do
    accountId = params[:id]
    success, responseMsg = delete_user("database", accountId)

    if success
        session[:alerts] = [make_notification("success", responseMsg)]

        if !is_admin() or session[:userId] == accountId
            redirect("/logout")
        end

        redirect("/users")
    else
        session[:alerts] = [make_notification("error", responseMsg)]
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
        session[:userId] = msg[:id].to_i
        session[:userRole] = msg[:role].to_i
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
    session[:userRole] = nil
    session[:alerts] = [make_notification("success", "Successfully logged out!")]
    redirect('/')
end


# CART

get('/users/:id/cart') do
    # cart = get_cart(session[:userId], "database")
    # items = get_cart_items(cart["id"], "database")

    slim(:'cart/index') #, locals:{ cart: cart, items: items })
end


# PRODUCTS

['/products/new', '/products/:id/edit', '/products/:id/update', '/products/:id/delete'].each do |path|
    before(path) do
        if !is_admin()
            redirect("/error/401")
        end
    end
end

before('/products/:id') do
    if params[:id] == "new"
        return
    end
    
    if !string_is_int(params[:id])
        redirect("/error/404")
    end
end

get('/products') do
    products = get_products("database")
    brands = products.map { |product| product["brand"] }.uniq

    products.each_with_index do |product, index|
        rating = round_to_nearst_half(get_product_rating("database", product["id"]))
        products[index]["rating"] = rating
    end

    slim(:'/products/index', locals:{ products: products, brands: brands, categories: ["Category1", "Category2"]})
end

get('/products/new') do
    slim(:'/products/new')
end

post('/products') do
    image = params[:image]
    name = params[:name]
    brand = params[:brand]
    desc = params[:desc]
    spec = params[:spec]
    price = params[:price]

    success, responseMsg = create_product("database", image, name, brand, desc, spec, price)

    session[:auto_fill] = {
        name: name,
        brand: brand,
        desc: desc,
        spec: spec,
        price: price,
    }

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect('/products')
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        redirect('/products/new')
    end
end

get('/products/:id') do
    id = params[:id]
    product = get_product("database", id)
    
    reviews = get_reviews("database", id)
    rating = round_to_nearst_half(get_product_rating("database", id))
    product["rating"] = rating

    slim(:"/products/show", locals: { product: product, reviews: reviews })
end

get('/products/:id/edit') do
    id = params[:id]
    product = get_product("database", id)

    slim(:'/products/edit', locals: { product: product })
end

post('/products/:id/update') do
    id = params[:id]
    image = params[:image]
    name = params[:name]
    brand = params[:brand]
    desc = params[:desc]
    spec = params[:spec]
    price = params[:price]

    success, responseMsg = update_product("database", id, image, name, brand, desc, spec, price)

    session[:auto_fill] = {
        name: name,
        brand: brand,
        desc: desc,
        spec: spec,
        price: price,
    }

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect("/products/#{id}")
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        redirect("/products/#{id}/edit")
    end
end

post('/products/:id/delete') do
    id = params[:id]
    success, responseMsg = delete_product("database", id)

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        redirect('/products')
    else
        session[:alerts] = [make_notification("error", responseMsg)]
        redirect("/products/#{id}/edit")
    end
end


# PRODUCT REVIEWS

before('/products/:id/reviews') do
    if !is_authenticated()
        redirect('/error/401')
    end
end

get('/products/:id/reviews/new') do
    product = get_product("database", params[:id])

    slim(:'/reviews/new')
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