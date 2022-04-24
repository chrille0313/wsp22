ROLES = { 
    admin: 0,
    customer: 1,
}


def connect_to_db(name, rootDir="db")
    db = SQLite3::Database.new("#{rootDir}/#{name}.db")
    db.results_as_hash = true
    return db
end


def count_db(db, table, attribute, check)
    query = "SELECT * FROM #{table} WHERE #{attribute} = ?"
    result = db.execute(query, check)
    result.length
end

def is_unique(db, table, attribute, check)
    return count_db(db, table, attribute, check) == 0
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
    # (?=.*[a-z])       Ensure string has one lowercase letter.
    # (?=.*[A-Z])       Ensure string has one uppcercase letter.
    # (?=.*[0-9])       Ensure string has one digit.
    # (?=.*[!@#$&*_])   Ensure string has one special case letter.
    # (?=.{8,})         Ensure string has atleast 8 characters.

    return password.match(/^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*_])(?=.{8,})/)
end


def email_is_valid(email)
    return email.match(/([-!#-'*+-9=?A-Z^-~]+(\.[-!#-'*+-9=?A-Z^-~]+)*)@[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?(\.[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?)+/)
end


# TODO: limit lengths
def check_account_credentials(db, credentials, updating=false)
    if credentials[:username] == ""
        return [false, "No username provided"]
    elsif credentials[:password] == "" and not updating
        return [false, "No password provided!"]
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


def register_account(db, username, password, role=ROLES[:customer]) 
    passwordDigest = BCrypt::Password.create(password)
    db.execute('INSERT INTO accounts (username, password, role) VALUES (?, ?, ?)', username, passwordDigest, role)
    accountId = db.execute('SELECT id FROM accounts WHERE username = ?', username).first
    return accountId["id"]
end

# TODO: limit lengths
def check_customer_credentials(db, credentials, updating=false)
    empty = ""
    
    if credentials[:fname] == ""
        empty = "first name"
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
    elsif not email_is_valid(credentials[:email])
        return [false, "Invalid e-mail!"]
    elsif not is_unique(db, "customers", "email", credentials[:email])
        if updating
            accountId = db.execute('SELECT account_id FROM customers WHERE email = ?', credentials[:email]).first["account_id"]
            wrongId = accountId != credentials[:account_id]
        end

        if not updating or wrongId
            return [false, "E-mail already in use!"]
        end
    end
    return [true, "Customer creation possible."]
end


def register_customer(db, accountId, fname, lname, email, address, city, postalCode) 
    db.execute('INSERT INTO customers (account_id, fname, lname, email, address, city, postal_code) VALUES (?, ?, ?, ?, ?, ?, ?)', accountId, fname, lname, email, address, city, postalCode)
end


# TODO: role
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


def update_user(accountId, username, password, confirmPassword, fname, lname, email, address, city, postalCode)
    db = connect_to_db("database")

    accountSuccess, accountMsg = check_account_credentials(db, {account_id: accountId, username: username, password: password, confirm_password: confirmPassword}, true)
    customerSuccess, customerMsg = check_customer_credentials(db, {account_id: accountId, fname: fname, lname: lname, email: email, address: address, city: city, postal_code: postalCode}, true)
    
    if not accountSuccess
        return accountSuccess, accountMsg
    elsif not customerSuccess
        return customerSuccess, customerMsg
    end

    update_account(db, accountId, username, password, ROLES[:customer])  # TODO: role
    update_customer(db, accountId, fname, lname, email, address, city, postalCode)

    return [true, "User successfully updated!"]
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


def delete_user(accountId)
    db = connect_to_db("database")

    role = db.execute('SELECT role FROM accounts WHERE id = ?', accountId).first["role"]

    db.execute('DELETE FROM accounts WHERE id = ?', accountId)

    if role == ROLES[:customer]
        db.execute('DELETE FROM customers WHERE account_id = ?', accountId)
    end

    return [true, "User successfully deleted!"]
end


def get_account(id, database)
    db = connect_to_db(database)
    return db.execute("SELECT * FROM accounts WHERE id = ?", id).first
end


def get_customer(account_id, database)
    db = connect_to_db(database)
    return db.execute("SELECT * FROM customers WHERE account_id = ?", account_id).first
end
