require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

require_relative 'model.rb'


=begin
configure do
    enable :sessions
    set :session_secret, "713a5b64aab63c9a039390f4b6057438b6c24cf68203dbadb7d59aa36196b14b5931d39220a90faa6481d41a2699a5aa56d0d98a5f4a78764efc22331f84d169f1566663428f4c7aed2be028fbf11b84bc1e41bce228f3c07b16d931e813b2804e16b7eae04dc55f19de1dd2cc497cfbb3492afa052a3672e72d33a66355956b"
end
=end

use Rack::Session::Pool  # Multi-process session (to handle large data in session)


# set :port, 80
# set :bind, '192.168.10.157'


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

    def is_rate_limited(diff=RATE_LIMIT)
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
            if is_rate_limited()
                session[:alerts] = [make_notification("error", "You're doing that too much. Try again in a few seconds.")]
                log_time()

                redirect("/")
            end

            log_time()
        elsif request.request_method == "GET" and request.path_info == "/users"
            if !is_admin()
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
    else
        id = params[:id].to_i
        success, account = get_account(id, "database")

        if !success
            redirect("/error/404")
        end
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

    success, responseMsg = register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode, is_admin() ? role : ROLES[:customer])

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect('/login')
    else
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

        session[:alerts] = [make_notification("error", responseMsg)]
        redirect('/users/new')
    end
end

get('/users/:id') do
    id = params[:id].to_i
    success, account = get_account(id, "database")

    data = {account: account}

    if account["role"] == ROLES[:customer]
        data[:user] = get_customer("database", account["id"])
    end
    
    slim(:'users/show', locals: data)
end

get('/users/:id/edit') do
    accountId = params[:id].to_i
    success, account = get_account(accountId, "database")

    data = {account: account}

    if account["role"].to_i == ROLES[:customer]
        data[:user] = get_customer("database", accountId)
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

    success, responseMsg = update_user(id, username, password, confirmPassword, fname, lname, email, address, city, postalCode, is_admin() ? role : ROLES[:customer])

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
    else
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

before('/products') do
    if request.request_method == "POST"
        if is_rate_limited()
            session[:alerts] = [make_notification("error", "You're doing that too much. Try again in a few seconds.")]
            log_time()
            redirect("/products")
        end

        log_time()
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

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect('/products')
    else
        session[:auto_fill] = {
            name: name,
            brand: brand,
            desc: desc,
            spec: spec,
            price: price,
        }

        session[:alerts] = [make_notification("error", responseMsg)]
        redirect('/products/new')
    end
end

get('/products/:id') do
    id = params[:id].to_i
    success, product = get_product("database", id)
    
    if !success
        redirect("/error/404")
    end

    reviews = get_reviews("database", id)
    rating = round_to_nearst_half(get_product_rating("database", id))
    product["rating"] = rating

    slim(:"/products/show", locals: { product: product, reviews: reviews })
end

get('/products/:id/edit') do
    id = params[:id].to_i
    success, product = get_product("database", id)

    if !success
        redirect("/error/404")
    end

    slim(:'/products/edit', locals: { product: product })
end

post('/products/:id/update') do
    id = params[:id].to_i
    image = params[:image]
    name = params[:name]
    brand = params[:brand]
    desc = params[:desc]
    spec = params[:spec]
    price = params[:price]

    success, responseMsg = update_product("database", id, image, name, brand, desc, spec, price)

    if success
        session[:alerts] = [make_notification("success", responseMsg)]
        session[:auto_fill] = nil
        redirect("/products/#{id}")
    else
        session[:auto_fill] = {
            name: name,
            brand: brand,
            desc: desc,
            spec: spec,
            price: price,
        }

        session[:alerts] = [make_notification("error", responseMsg)]
        redirect("/products/#{id}/edit")
    end
end

post('/products/:id/delete') do
    id = params[:id].to_i
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

post('/products/:id/reviews') do
    customerId = get_customer("database", session[:userId])["id"]

    rating = params[:rating]
    comment = params[:comment]

    success, msg = add_review("database", customerId, params[:id], rating, comment)
    session[:alerts] = [make_notification(success ? "success" : "error", msg)]

    if !success
        session[:auto_fill] = {
            rating: rating,
            comment: comment
        }
    else
        session[:auto_fill] = nil
    end

    redirect("/products/#{params[:id]}")
end

post('/products/:id/reviews/delete') do
    customerId = get_customer("database", session[:userId])["id"]
    productId = params[:id]

    success, msg = delete_review("database", customerId, productId)
    session[:alerts] = [make_notification(success ? "success" : "error", msg)]

    redirect("/products/#{productId}")
end


# CART

get('/users/:id/cart') do
    cart = get_cart("database", session[:userId])

    slim(:'carts/show', locals: { cart: cart })
end

post("/carts") do

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
