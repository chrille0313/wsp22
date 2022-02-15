def connect_to_db(name, rootDir="db")
    db = SQLite3::Database.new("#{rootDir}/#{name}.db")
    db.results_as_hash = true
    return db
end


# FIXME - Check if it's possible to sql-inject with this
def is_unique(db, table, attribute, check)
    query = "SELECT * FROM #{table} WHERE #{attribute} = ?"
    result = db.execute(query, check)
    return result.length == 0
end


# TODO - Implement valid password check
def password_is_strong(password)
    return true
end


def can_register_account(db, username, password, confirmPassword) 
    if password != confirmPassword
        return [false, "Passwords didn't match!"]
    elsif not password_is_strong(password)
        return [false, "Password is too weak!"]
    elsif not is_unique(db, "accounts", "username", username)
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


def can_register_customer(db, email)
    if not is_unique(db, "customers", "email", email)
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
    accountSuccess, accountMsg = can_register_account(db, username, password, confirmPassword)
    customerSuccess, customerMsg = can_register_customer(db, email)
    
    if not accountSuccess
        return accountSuccess, accountMsg
    elsif not customerSuccess
        return  customerSuccess, customerMsg
    end

    accountId = register_account(db, username, password)
    register_customer(db, accountId, fname, lname, email, address, city, postalCode)

    return [true, "User successfully created!"]
end


def authenticate_user(username, password)
    db = connect_to_db("database")
    result = db.execute("SELECT * FROM accounts WHERE username = ?", username).first

    if result == nil
        return [false, "Username doesn't exist!"]
    elsif BCrypt::Password.new(result["password"]) != password
        return [false, "Wrong Password!"]
    else
        return [true, result["id"]]
    end
end
