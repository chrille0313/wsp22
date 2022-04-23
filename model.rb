ROLES = { 
    admin: 0,
    customer: 1,
 }


def connect_to_db(name, rootDir="db")
    db = SQLite3::Database.new("#{rootDir}/#{name}.db")
    db.results_as_hash = true
    return db
end


def is_unique(db, table, attribute, check)
    query = "SELECT * FROM #{table} WHERE #{attribute} = ?"
    result = db.execute(query, check)
    return result.length == 0
end


def is_empty(str)
    return str.length == 0
end


def string_is_int(str)
    return str.to_i.to_s == str
end


def combine_urls(*urls)
    return urls.join('|')
end


def make_notification(type, message)
    alertIcons = {
        "info" => "info",
        "success" => "check_circle",
        "warning" => "error_outline",
        "error" => "cancel"
    }

    return {type: type, message: message, icon: alertIcons[type]}
end


def password_is_strong(password)
    # ^                 Start anchor
    # (?=.*[A-Z])       Ensure string has one uppcercase letter.
    # (?=.*[!@#$&*])    Ensure string has one special case letter.
    # (?=.*[0-9])       Ensure string has one digit.
    # (?=.*[a-z])       Ensure string has three lowercase letters.
    # (?=.{8,})         Ensure string has atleast 8 characters.

    return password.match("^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#$%^&*])(?=.{8,})")
end


def check_account_credentials(db, credentials)
    if credentials[:username] == ""
        return [false, "No username provided"]
    elsif credentials[:password] == ""
        return [false, "No password provided!"]
    elsif credentials[:password] != credentials[:confirm_password]
        return [false, "Passwords didn't match!"]
    elsif not password_is_strong(credentials[:password])
        return [false, "Password is too weak!"]
    elsif not is_unique(db, "accounts", "username", credentials[:username])
        return [false, "Username already taken!"]
    else
        return [true, "Account creation possible."]
    end
end


def register_account(db, username, password, admin=false) 
    passwordDigest = BCrypt::Password.create(password)
    db.execute('INSERT INTO accounts (username, password, role) VALUES (?, ?, ?)', username, passwordDigest, admin ? 0 : 1)
    accountId = db.execute('SELECT id FROM accounts WHERE username = ?', username).first
    return accountId["id"]
end


def check_customer_credentials(db, credentials)
    empty = ""
    
    if credentials[:fname] == ""
        empty = "first name"]
    elsif credentials[:lname] == ""
        empty = "last name"
    elsif credentials[:email] == ""
        empty = "email"
    elsif credentials[:address] == ""
        empty = "address"
    elsif credentials[:city] == ""
        empty = "city"
    elsif credentials[:postal_code] == ""
        empty = "postal code"
    end
    
    if empty != ""
        return [false, "No #{empty} provided!"]
    elsif not is_unique(db, "customers", "email", credentials[:email])
        return [false, "E-mail already in use!"]
    else
        return [true, "Customer creation possible."]
    end
end


def register_customer(db, accountId, fname, lname, email, address, city, postalCode) 
    db.execute('INSERT INTO customers (account_id, fname, lname, email, address, city, postal_code) VALUES (?, ?, ?, ?, ?, ?, ?)', accountId, fname, lname, email, address, city, postalCode)
end


def register_user(username, password, confirmPassword, fname, lname, email, address, city, postalCode)
    db = connect_to_db("database")
    accountSuccess, accountMsg = check_account_credentials(db, {username: username, password: password, confirm_password: confirmPassword})
    customerSuccess, customerMsg = check_customer_credentials(db, {fname: fname, lname: lname, email: email, address: address, city: city, postal_code: postalCode})
    
    if not accountSuccess
        return accountSuccess, accountMsg
    elsif not customerSuccess
        return customerSuccess, customerMsg
    end

    accountId = register_account(db, username, password)
    register_customer(db, accountId, fname, lname, email, address, city, postalCode)

    return [true, "User successfully created!"]
end


def authenticate_user(username, password)
    db = connect_to_db("database")
    result = db.execute("SELECT * FROM accounts WHERE username = ?", username).first

    # TODO: 
    if result == nil
        return [false, "Username doesn't exist!"]
    elsif BCrypt::Password.new(result["password"]) != password
        return [false, "Wrong Password!"]
    else
        return [true, result["id"]]
    end
end


def get_account(id, database)
    db = connect_to_db(database)
    return db.query("SELECT * FROM accounts WHERE id = ?", id).first
end


def get_customer(account_id, database)
    db = connect_to_db(database)
    return db.query("SELECT * FROM customers WHERE account_id = ?", account_id).first
end
