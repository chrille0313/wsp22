require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

require_relative 'model.rb'

include Model

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


# Display landing page
# 
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


# Display all users (only available for admins)
#
get('/users') do
    users = get_users("database")
    slim(:'users/index', locals: {users: users})
end

# Display form to add a new user
#
get('/users/new') do
    slim(:'users/new')
end

# Creates a new user. Redirects to '/login' if registration was successful, otherwise redirects to '/users/new'
#
# @param [String] username The username of the user account
# @param [String] password The password of the user account
# @param [String] confirm-password The password of the user account again
# @param [Integer] role The role of the user account (only available for admins)
# @param [String] fname The first name of the user
# @param [String] lname The last name of the user
# @param [String] email The email of the user
# @param [String] address The address of the user
# @param [String] city The city of the user
# @param [Integer] postal-code The postal code of the user
# 
# @see Model#register_user
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


# Display a single user
#
# @param [Integer] :id the id of the user account
#
# @see Model#get_account
# @see Model#get_customer
get('/users/:id') do
    id = params[:id].to_i
    success, account = get_account(id, "database")

    data = {account: account}

    if account["role"] == ROLES[:customer]
        data[:user] = get_customer("database", account["id"])
    end
    
    slim(:'users/show', locals: data)
end


# Display form for editing user-credentials
#
# @see Model#get_acount
# @see Model#get_customer
get('/users/:id/edit') do
    accountId = params[:id].to_i
    success, account = get_account(accountId, "database")

    data = {account: account}

    if account["role"].to_i == ROLES[:customer]
        data[:user] = get_customer("database", accountId)
    end
    
    slim(:'users/edit', locals: data)
end


# Updates an existing users credentials and redirects to '/users/:id/edit'
#
# @param [Integer] :id The id of the user account
# @param [String] username The username of the user account
# @param [String] password The password of the user account
# @param [String] confirm-password The password of the user account again
# @param [Integer] role The role of the user account (only available for admins)
# @param [String] fname The first name of the user
# @param [String] lname The last name of the user
# @param [String] email The email of the user
# @param [String] address The address of the user
# @param [String] city The city of the user
# @param [Integer] postal-code The postal code of the user
# 
# @see Model#update_user
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


# Delete an existing user
#
# @param [Integer] :id The id of the user
#
# @see Model#delete_user
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


# Display form for logging in a user
#
get('/login') do
    slim(:login)
end


# Log in a user. Redirects to '/' if successful, otherwise redirects to '/login'
#
# @param [String] username The username of the user account
# @param [String] password The password of the user account
#
# @see Model#authenticate_user
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


# Log out user. Redirects to '/'
#
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


# Display all products
# 
# @see Model#get_products
# @see Model#get_product_rating
# @see Model#round_to_nearest_half
get('/products') do
    products = get_products("database")
    brands = products.map { |product| product["brand"] }.uniq

    products.each_with_index do |product, index|
        rating = round_to_nearest_half(get_product_rating("database", product["id"]))
        products[index]["rating"] = rating
    end

    slim(:'/products/index', locals:{ products: products, brands: brands, categories: ["Category1", "Category2"]})
end


# Display form for adding a new product
#
get('/products/new') do
    slim(:'/products/new')
end


# Create a new product. Redirects to '/products' if successful, otherwise redirects to '/products/new'
#
# @param [File] image The product-image
# @param [String] name The products name
# @param [String] brand The brand of the product
# @param [String] desc The description of the product
# @param [String] spec The specification of the product
# @param [Float] price The price of the product
#
# @see Model#create_product
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


# Display a single product. Redirects to /error/404 if product doesn't exist
#
# @param [Integer] :id The id of the product
#
# @see Model#get_product
# @see Model#get_reviews
# @see Model#get_product_rating
# @see Model#round_to_nearest_half
get('/products/:id') do
    id = params[:id].to_i
    success, product = get_product("database", id)
    
    if !success
        redirect("/error/404")
    end

    reviews = get_reviews("database", id)
    rating = round_to_nearest_half(get_product_rating("database", id))
    product["rating"] = rating

    slim(:"/products/show", locals: { product: product, reviews: reviews })
end


# Show form for editing a single product
#
# @param [Integer] :id The id of the product
#
# @see Model#get_product
get('/products/:id/edit') do
    id = params[:id].to_i
    success, product = get_product("database", id)

    if !success
        redirect("/error/404")
    end

    slim(:'/products/edit', locals: { product: product })
end


# Update a single product. Redirects to '/products/:id' if successful, otherwise redirects to '/products/:id/edit'
#
# @param [Integer] :id The id of the product
# @param [File] image The product-image
# @param [String] name The products name
# @param [String] brand The brand of the product
# @param [String] desc The description of the product
# @param [String] spec The specification of the product
# @param [Float] price The price of the product
#
# @see Model#update_product
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


# Delete a single product. Redirects to '/products' if successful, otherwise redirects to'/products/:id/edit'
#
# @param [Integer] id The id of the product
# 
# @see Model#delete_product
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


# Create a review from a user for a product (only allowed for logged in users). Reirects to '/products/:id'
#
# @param [Integer] :id The id of the products
# @param [Integer] :userId The id of the logged in user.
#
# @see Model#add_review
# @see Model#get_customer
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


# Delete a review. Redirects to '/products/:id'
#
# @param [Integer] :id The id of the product
# @param [Integer] :userId The user id of the logged in user
#
# @see Model#delete_review
# @see Model#get_customer
post('/products/:id/reviews/delete') do
    customerId = get_customer("database", session[:userId])["id"]
    productId = params[:id]

    success, msg = delete_review("database", customerId, productId)
    session[:alerts] = [make_notification(success ? "success" : "error", msg)]

    redirect("/products/#{productId}")
end


# ERRORS

# Display error page.
#
# @param [Integer] :id The id of the error
# @param [String] message
#
# @see Model#string_is_int
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


# Handles routes that doesn't exists. Redirects to '/error/404'
#
not_found do
    redirect('/error/404')
end
