module Model

    require "securerandom"
    require "set"

    require_relative "constants"


    # Rounds a float to nearest half
    #
    # @param [Float] number The number to round
    #
    # @return [Float] The rounded number 
    def round_to_nearest_half(number)
        return (number.to_f * 2).round / 2.0
    end


    # Connects to a database and sets the results to return as a hash
    #
    # @param [String] name The name of the database
    # @param [String] rootDir The root directory of the database
    #
    # @return [Database Object] The connection to the database
    def connect_to_db(name, rootDir="db")
        db = SQLite3::Database.new("#{rootDir}/#{name}.db")
        db.results_as_hash = true
        return db
    end


    # Counts the number of times a certain attribute value appears in a database
    #
    # @param [Database Object] db The connection to the database
    # @param [String] table The table in the database to check
    # @param [String] attribute The attribute in the database to check
    # @param [String] check The value to check the attribute against
    #
    # @return [Integer] The number of times the value appears in the database.
    def count_db(db, table, attribute, check)
        query = "SELECT * FROM #{table} WHERE #{attribute} = ?"
        result = db.execute(query, check)
        result.length
    end


    # Checks if a given database entry already exists
    #
    # @param [Database Object] db The connection to the database
    # @param [String] table The table in the database to check
    # @param [String] attribute The attribute in the database to check
    # @param [String] check The value to check the attribute against
    #
    # @return [Boolean] True if the count of the database entry is 0 else False
    #
    # @see Model#count_db
    def is_unique(db, table, attribute, check)
        return count_db(db, table, attribute, check) == 0
    end


    # Checks if a given string could be converted to an number value
    #
    # @param [String] str The string to check
    #
    # @return [Boolean] True if the given string could be converted to a number else False
    def string_is_int(str)
        return str.to_i.to_s == str || str.to_f.to_s == str
    end


    # Checks if a given string contains a number
    #
    # @param [String] str The string to check
    # 
    # @return [Boolean] True if the string contains a number else False
    def str_contains_nr(str)
        return (str =~ /[0-9]/) != nil
    end


    # Checks if a given string contains a special character
    #
    # @param [String] str The string to check
    #
    # @return [Boolean] True if the user contains a special character else False 
    def str_contains_special_char(str)
        return (str =~ /[^a-zA-Z0-9]/) != nil
    end


    # Combines urls to use in before-blocks
    #
    # @param [Array] urls An array of urls to combine
    #
    # @return [String] A string with the combined urls
    def combine_urls(*urls)
        return urls.join('|')
    end


    # Generates a unique random string with a given length
    #
    # @param [Set] A set with the given
    # @param [Integer] length The length of the generated string in bits
    #
    # @return [String] The generated string
    def generate_random_str(used=nil, length=16)
        str = SecureRandom.urlsafe_base64(length)
        while used != nil and used.include?(str)
            str = SecureRandom.urlsafe_base64
        end
        
        return str
    end


    # Get the size of a file in Mega Bytes
    #
    # @param [File] The file to check the size of
    #
    # @return [Float] The size of the given file in Mega Bytes
    def get_file_size_mb(file)
        return (File.size(file).to_f / 1024000).round(2)
    end


    # Get the file extension of a file
    #
    # @param [String] file The name of the file
    #
    # @return [String] The file extension
    def get_file_ext(file)
        return file.split('.').last
    end


    # Get all files in a directory
    #
    # @param [String] dir The directory to get all files from 
    # 
    # @return [Array] An array of all filenames in the directory
    def get_files_in_dir(dir)
        return Dir["#{dir}/**/*.*"].map { |f| f.split("/").last }
    end


    # Creates a notification to be displayed on the website
    #
    # @param [String] type The type of the notification
    # @param [String] message The message of the notification
    #
    # @return [Hash] 
    #   * :type The type of the notification
    #   * :message The message of the notification
    #   * :icon The icon of the notification
    def make_notification(type, message)
        alertIcons = {
            "info" => "info",
            "success" => "check_circle",
            "warning" => "error_outline",
            "error" => "cancel"
        }

        return {type: type, message: message, icon: alertIcons[type]}
    end


    # Validates a user-inputed image
    #
    # @param [Hash] image
    #
    # @return [Array] 
    #   * [Boolean] success True if the image passed all checks else False
    #   * [String] message The error message of the validation
    #
    # @see Model#get_file_size_mb
    def check_image(image)
        if image == nil
            return [false, "No image provided!"]
        elsif image["type"] != "image/jpeg" and image["type"] != "image/png"
            return [false, "Image type invalid!"]
        elsif get_file_size_mb(image["tempfile"]) > MAX_IMAGE_SIZE
            return [false, "Image size is too large!"]
        end

        return [true, "Image is valid!"]
    end


    # Get the image path of a file on the server
    #
    # @param [Hash] image The image submitted by the user
    # @param [String] subDir The subdirectory of the image file
    # @param [String] filename The name of the image file
    #
    # @return [String] The path to the image file on the server
    #
    # @see Model#get_files_in_dir
    # @see Model#generate_random_str
    # @see Model#get_file_ext
    def get_image_path(image, subDir="", filename="")
        existingFiles = Set.new(get_files_in_dir("./public/uploads/img"))
        fileName = filename == "" ? "#{generate_random_str(existingFiles)}.#{get_file_ext(image["filename"])}" : filename
        return "/uploads/img/#{subDir}/#{fileName}"
    end


    # Downloads an image to the server
    #
    # @param [Hash] image The user-submitted image to be downloaded
    # @param [String] subDir The subdirectory to download the image to
    # @param [String] filename The name of the image file
    #
    # @return [String] The path to the image on the server
    #
    # @see Model#get_image_path
    def download_image(image, subDir="", filename="")
        file = image["tempfile"]
        path = get_image_path(image, subDir, filename)

        File.open("./public" + path, 'wb') do |f|
            f.write(file.read)
        end

        return path
    end


    # Updates an image on the server
    #
    # @param [String] subDir The subdirectory that the image lies in on the server
    # @param [String] filename The name of the file on the server
    # @param [Hash] newImage Whether to replace the image with a new one. If set to nil, the old image will be deleted.
    #
    # @return [String] The path to the image on the server
    # @return [Boolean] False if no new image is provided
    def update_image(subDir, filename, newImage=nil)
        if newImage != nil
            return download_image(newImage, subDir, filename)
        else
            File.delete("./public/uploads/img/#{subDir}/#{filename}")
        end

        return false
    end


    # Checks if a given password is strong
    #
    # @param [String] password
    #
    # @return [Boolean] True if the password is strong else False
    def password_is_strong(password)
        # ^                 Start anchor
        # (?=.*[a-z])       Ensure string has one lowercase letter.
        # (?=.*[A-Z])       Ensure string has one uppcercase letter.
        # (?=.*[0-9])       Ensure string has one digit.
        # (?=.*[!@#$&*_])   Ensure string has one special case letter.
        # (?=.{8,})         Ensure string has atleast 8 characters.

        return (password =~ /^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*_])(?=.{8,})/) != nil
    end


    # Checks if a given email addres is valid
    # 
    # @param [String] email The email to check
    #
    # @return [Boolean] True if the email is valid else False
    def email_is_valid(email)
        return (email =~ /([-!#-'*+-9=?A-Z^-~]+(\.[-!#-'*+-9=?A-Z^-~]+)*)@[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?(\.[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?)+/) != nil
    end


    # Checks if a string is empty
    #
    # @param [String] str The string to check
    #
    # @return [Boolean] True if the string is empty else False
    def is_empty(str)
        return str == nil || (str =~ /^.*[^\s].*$/) == nil
    end


    # Validates user inputed acount credentials
    # 
    # @param [Database Object] db
    # @param [Hash] credentials The user inputed credentials
    #  
    # @return [Array]
    #   * [Boolean] True if all credentials passede the tests else False
    #   * [String] The error message
    #
    # @see Model#is_empty
    # @see Model#string_is_int
    # @see Model#password_is_strong
    # @see Model#is_unique
    def check_account_credentials(db, credentials, updating=false)
        if is_empty(credentials[:username])
            return [false, "No username provided"]
        elsif credentials[:username].length > MAX_USERNAME_LENGTH
            return [false, "Username is too long"]
        elsif is_empty(credentials[:password]) and not updating
            return [false, "No password provided!"]
        elsif is_empty(credentials[:role]) or !string_is_int(credentials[:role]) or !ROLES.has_value?(credentials[:role].to_i)
            return [false, "Invalid role provided!"]
        elsif credentials[:password] != credentials[:confirm_password]
            return [false, "Passwords didn't match!"]
        elsif not password_is_strong(credentials[:password]) and credentials[:password] != ""
            return [false, "Password is too weak!"]
        elsif not is_unique(db, "accounts", "username", credentials[:username])
            if updating
                accountId = db.execute('SELECT id FROM accounts WHERE username = ?', credentials[:username]).first["id"]
                wrongId = accountId != credentials[:account_id]
            end

            if not updating or wrongId
                return [false, "Username is already taken!"]
            end
        end
        
        return [true, "Account creation possible."]
    end


    # Registers a user to the provided database
    #
    # @param [Database Object] db The database to register the user to
    # @param [String] username The username of the user
    # @param [String] password The password of the user
    # @param [Integer] role The role of the user
    # 
    # @return [Integer] The id of the created user
    def register_account(db, username, password, role=ROLES[:customer]) 
        passwordDigest = BCrypt::Password.create(password)
        db.execute('INSERT INTO accounts (username, password, role) VALUES (?, ?, ?)', username, passwordDigest, role)
        accountId = db.execute('SELECT id FROM accounts WHERE username = ?', username).first
        return accountId["id"]
    end


    # Validates the customer credentials
    # 
    # @param [Database Object] 
    # @param [Hash] 
    # @param [Boolean] 
    #
    # @return [Hash]
    def check_customer_credentials(db, credentials, updating=false)
        empty = ""
        
        if is_empty(credentials[:fname])
            empty = "first name"
        elsif is_empty(credentials[:lname])
            empty = "last name"
        elsif is_empty(credentials[:email])
            empty = "email"
        elsif is_empty(credentials[:address])
            empty = "address"
        elsif is_empty(credentials[:city])
            empty = "city"
        elsif is_empty(credentials[:postal_code])
            empty = "postal code"
        end
        
        if empty != ""
            return [false, "No #{empty} provided!"]

        # FIRST NAME
        elsif str_contains_nr(credentials[:fname])
            return [false, "First name can't contain numbers!"]
        elsif credentials[:fname].length > MAX_NAME_LENGTH
            return [false, "First name is too long!"]

        # LAST NAME
        elsif str_contains_nr(credentials[:lname])
            return [false, "Last name can't contain numbers!"]
        elsif credentials[:lname].length > MAX_NAME_LENGTH
            return [false, "Last name is too long!"]

        # EMAIL
        elsif not email_is_valid(credentials[:email])
            return [false, "Invalid e-mail!"]
        elsif credentials[:email].length > MAX_EMAIL_LENGTH
            return [false, "E-mail is too long!"]
        elsif not is_unique(db, "customers", "email", credentials[:email])
            if updating
                accountId = db.execute('SELECT account_id FROM customers WHERE email = ?', credentials[:email]).first["account_id"]
                wrongId = accountId != credentials[:account_id]
            end

            if not updating or wrongId
                return [false, "E-mail already in use!"]
            end

        # POSTAL CODE
        elsif !string_is_int(credentials[:postal_code]) or credentials[:postal_code].length != 5
            return [false, "Invalid postal code!"]
        
        # CITY
        elsif str_contains_special_char(credentials[:city]) or str_contains_nr(credentials[:city])
            return [false, "City can't contain numbers or special characters!"]
        elsif credentials[:city].length > MAX_CITY_LENGTH
            return [false, "City is too long!"]
        
        # Address
        elsif str_contains_special_char(credentials[:address])
            return [false, "Address can't contain special characters!"]
        elsif credentials[:address].length > MAX_ADDRESS_LENGTH
            return [false, "Address is too long!"]
        end

        return [true, "Customer creation possible."]
    end


    def register_customer(db, accountId, fname, lname, email, address, city, postalCode) 
        db.execute('INSERT INTO customers (account_id, fname, lname, email, address, city, postal_code) VALUES (?, ?, ?, ?, ?, ?, ?)', accountId, fname, lname, email, address, city, postalCode)
    end

    def register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode, role=ROLES[:customer])
        db = connect_to_db("database")
        accountSuccess, accountMsg = check_account_credentials(db, {username: username, password: password, confirm_password: confirmPassword, role: role.to_s})
        
        if not accountSuccess
            return accountSuccess, accountMsg
        end

        if role.to_i != ROLES[:admin]
            customerSuccess, customerMsg = check_customer_credentials(db, {fname: fname, lname: lname, email: email, address: address, city: city, postal_code: postalCode})
            
            if not customerSuccess
                return customerSuccess, customerMsg
            end    
        end

        accountId = register_account(db, username, password, role.to_i)

        if role.to_i != ROLES[:admin]
            register_customer(db, accountId, fname, lname, email, address, city, postalCode)
        end

        return [true, "User successfully created!"]
    end

    def update_account(db, accountId, username, password, role)
        db.execute('UPDATE accounts SET username = ?, role = ? WHERE id = ?', username, role, accountId)

        if password != ""
            passwordDigest = BCrypt::Password.create(password)
            db.execute('UPDATE accounts SET password = ? WHERE id = ?', passwordDigest, accountId)
        end
    end


    def update_customer(db, accountId, fname, lname, email, address, city, postalCode)
        db.execute('UPDATE customers SET fname = ?, lname = ?, email = ?, address = ?, city = ?, postal_code = ? WHERE account_id = ?', fname, lname, email, address, city, postalCode, accountId)
    end


    def update_user(accountId, username, password, confirmPassword, fname, lname, email, address, city, postalCode, role=ROLES[:customer])
        db = connect_to_db("database")

        accountSuccess, accountMsg = check_account_credentials(db, {account_id: accountId, username: username, password: password, confirm_password: confirmPassword, role: role.to_s}, true)
        
        if not accountSuccess
            return accountSuccess, accountMsg
        end

        update_account(db, accountId, username, password, role)  # TODO: role

        if role.to_i != ROLES[:admin]
            customerSuccess, customerMsg = check_customer_credentials(db, {account_id: accountId, fname: fname, lname: lname, email: email, address: address, city: city, postal_code: postalCode}, true)
        
            if not customerSuccess
                return customerSuccess, customerMsg
            end

            update_customer(db, accountId, fname, lname, email, address, city, postalCode)
        end

        return [true, "User successfully updated!"]
    end


    def authenticate_user(username, password)
        db = connect_to_db("database")
        result = db.execute("SELECT * FROM accounts WHERE username = ?", username).first

        if result == nil
            return [false, "Username doesn't exist!"]
        elsif BCrypt::Password.new(result["password"]) != password
            return [false, "Wrong Password!"]
        else
            return [true, {id: result["id"], role: result["role"]}]
        end
    end


    def delete_user(database, accountId)
        db = connect_to_db(database)

        role = db.execute('SELECT role FROM accounts WHERE id = ?', accountId).first["role"]

        if role == ROLES[:customer]
            db.execute('DELETE FROM reviews WHERE customer_id = (SELECT id FROM customers WHERE account_id = ?)', accountId)
            db.execute('DELETE FROM likes WHERE customer_id = (SELECT id FROM customers WHERE account_id = ?)', accountId)
            db.execute('DELETE FROM carts WHERE customer_id = (SELECT id FROM customers WHERE account_id = ?)', accountId)
            db.execute('DELETE FROM customers WHERE account_id = ?', accountId)
        end
        
        db.execute('DELETE FROM accounts WHERE id = ?', accountId)

        return [true, "User successfully deleted!"]
    end


    def get_account(id, database)
        db = connect_to_db(database)
        user = db.execute("SELECT * FROM accounts WHERE id = ?", id).first
        
        if user == nil
            return [false, "User doesn't exist!"]
        else
            return [true, user]
        end
    end


    def get_customer(database, account_id)
        db = connect_to_db(database)
        return db.execute("SELECT * FROM customers WHERE account_id = ?", account_id).first
    end

    def get_customer_details(database, customer_id)
        db = connect_to_db(database)
        return db.execute("SELECT * FROM customers WHERE id = ?", customer_id).first
    end

    def get_users(database)
        db = connect_to_db(database)
        admins = db.execute("SELECT * FROM accounts WHERE role = ?", ROLES[:admin])
        customers = db.execute("SELECT * from accounts INNER JOIN customers ON accounts.id = customers.account_id")
        return {admins: admins, customers: customers}
    end


    def get_user_role(accountId)
        db = connect_to_db("database")
        user = db.execute("SELECT role FROM accounts WHERE id = ?", accountId).first
        
        if user == nil
            return [false, "User doesn't exist!"]
        else
            return [true, user["role"].to_i]
        end
    end


    def check_product_credentials(credentials, updating=false)
        if is_empty(credentials[:name])
            return [false, "Product name cannot be empty!"]
        elsif credentials[:name].length > MAX_PRODUCT_NAME_LENGTH
            return [false, "Product name cannot be longer than #{MAX_PRODUCT_NAME_LENGTH} characters!"]
        elsif is_empty(credentials[:brand])
            return [false, "Product brand cannot be empty!"]
        elsif credentials[:brand].length > MAX_PRODUCT_BRAND_LENGTH
            return [false, "Product brand cannot be longer than #{MAX_PRODUCT_BRAND_LENGTH} characters!"]
        elsif is_empty(credentials[:description])
            return [false, "Product description cannot be empty!"]
        elsif credentials[:description].length > MAX_PRODUCT_DESCRIPTION_LENGTH
            return [false, "Product description cannot be longer than #{MAX_PRODUCT_DESCRIPTION_LENGTH} characters!"]
        elsif is_empty(credentials[:specification])
            return [false, "Product specification cannot be empty!"]
        elsif credentials[:specification].length > MAX_PRODUCT_SPECIFICATION_LENGTH
            return [false, "Product specification cannot be longer than #{MAX_PRODUCT_SPECIFICATION_LENGTH} characters!"]
        elsif is_empty(credentials[:price]) or !string_is_int(credentials[:price]) or credentials[:price].to_i < 0
            return [false, "Product price invalid!"]
        elsif credentials[:price].length > MAX_PRODUCT_PRICE_LENGTH
            return [false, "Product price cannot be longer than #{MAX_PRODUCT_PRICE_LENGTH} characters!"]
        elsif credentials[:image] != nil
            success, msg = check_image(credentials[:image])
            if not success
                return [false, msg]
            end
        elsif !updating
            return [false, "Product image cannot be empty!"]
        end

        return [true, "Product creation possible."]
    end


    def add_product(db, imagePath, name, brand, description, specification, price)
        db.execute('INSERT INTO products (image_url, name, brand, description, specification, price) VALUES (?, ?, ?, ?, ?, ?)', imagePath, name, brand, description, specification, price)
    end


    def create_product(database, image, name, brand, description, specification, price)
        db = connect_to_db(database)

        success, msg = check_product_credentials({image: image, name: name, brand: brand, description: description, specification: specification, price: price})

        if not success
            return success, msg
        end

        path = download_image(image, "products")

        add_product(db, path, name, brand, description, specification, price)

        return [true, "Product successfully created!"]
    end

    def update_product(database, productId, image, name, brand, description, specification, price)
        db = connect_to_db(database)

        success, msg = check_product_credentials({image: image, name: name, brand: brand, description: description, specification: specification, price: price}, true)
        
        if not success
            return success, msg
        end

        if image != nil
            success, product = get_product(database, productId)
            
            if not success
                return success, product
            end

            filename = product["image_url"].delete_prefix("/uploads/img/products/")
            path = update_image("products", filename, image)
            db.execute('UPDATE products SET image_url = ? WHERE id = ?', path, productId)
        end

        db.execute('UPDATE products SET name = ?, brand = ?, description = ?, specification = ?, price = ? WHERE id = ?', name, brand, description, specification, price, productId)

        return [true, "Product successfully updated!"]
    end

    def delete_product(database, productId)
        db = connect_to_db(database)

        db.execute('DELETE FROM reviews WHERE product_id = ?', productId)
        db.execute('DELETE FROM likes WHERE product_id = ?', productId)
        db.execute('DELETE FROM carts WHERE product_id = ?', productId)

        # TODO: delete image corresponding to productId correctly

        success, product = get_product(database, productId)

        if !success
            return success, product
        end

        subDir = "/products"
        fileName = product["image_url"].split("/").last
        update_image(subDir, fileName)


        db.execute('DELETE FROM products WHERE id = ?', productId)

        return [true, "Product successfully deleted!"]
    end

    def get_products(database)
        db = connect_to_db(database)
        products = db.execute("SELECT * FROM products")
        products.each do |product|
            product["price"] = product["price"].round == product["price"] ? product["price"].to_i : product["price"]
        end
        return products
    end

    def get_product(database, id)
        db = connect_to_db(database)
        product = db.execute("SELECT * FROM products WHERE id = ?", id).first
        
        if product == nil
            return [false, "Product doesn't exist!"]
        end
        
        product["price"] = product["price"].round == product["price"] ? product["price"].to_i : product["price"]

        return [true, product]
    end

    def get_product_rating(database, productId)
        db = connect_to_db(database)
        result = db.execute("SELECT AVG(rating) FROM reviews WHERE product_id = ?", productId).first["AVG(rating)"]
        return result == nil ? 0 : result.to_f
    end


    def check_review_credentials(credentials)
        if credentials[:rating] == nil or !string_is_int(credentials[:rating]) or credentials[:rating].to_i < 0 or credentials[:rating].to_i > 5
            return [false, "Rating invalid!"]
        elsif is_empty(credentials[:comment])
            return [false, "Review cannot be empty!"]
        elsif credentials[:comment].length > MAX_REVIEW_LENGTH
            return [false, "Review cannot be longer than #{MAX_REVIEW_LENGTH} characters!"]
        end

        return [true, "Review creation possible."]
    end

    def user_has_reviewed_product(database, customerId, productId)
        db = connect_to_db(database)
        return db.execute("SELECT * FROM reviews WHERE customer_id = ? AND product_id = ?", customerId, productId).any?
    end


    def add_review(database, customerId, productId, rating, comment)
        success, msg = check_review_credentials({rating: rating, comment: comment})

        if !success
            return [false, msg]
        else
            db = connect_to_db(database)
            date = Time.now.strftime("%Y-%m-%d")

            if user_has_reviewed_product(database, customerId, productId)
                db.execute('UPDATE reviews SET date = ?, rating = ?, comment = ? WHERE customer_id = ? AND product_id = ?', date, rating, comment, customerId, productId)
                return [true, "Review successfully updated!"]
            else
                db.execute('INSERT INTO reviews (customer_id, product_id, date, rating, comment) VALUES (?, ?, ?, ?, ?)', customerId, productId, date, rating, comment)
                return [true, "Review successfully added!"]
            end
        end
    end

    def delete_review(database, customerId, productId)
        db = connect_to_db(database)
        db.execute('DELETE FROM reviews WHERE customer_id = ? AND product_id = ?', customerId, productId)
        return [true, "Review successfully deleted!"]
    end

    def get_reviews(database, productId)
        db = connect_to_db(database)
        return db.execute("SELECT * FROM reviews WHERE product_id = ?", productId)
    end

    def get_user_review(database, customerId, productId)
        db = connect_to_db(database)
        return db.execute("SELECT * FROM reviews WHERE customer_id = ? AND product_id = ?", customerId, productId).first
    end

    def get_cart(database, customerId)
        db = connect_to_db(database)
        return db.execute("SELECT product_id FROM carts WHERE customer_id = ?", customerId)
    end

end