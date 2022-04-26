def password_is_strong(password)
    # ^                 Start anchor
    # (?=.*[a-z])       Ensure string has one lowercase letter.
    # (?=.*[A-Z])       Ensure string has one uppcercase letter.
    # (?=.*[0-9])       Ensure string has one digit.
    # (?=.*[!@#$&*_])   Ensure string has one special case letter.
    # (?=.{8,})         Ensure string has atleast 8 characters.

    return (password =~ /^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*_])(?=.{8,})/) != nil
end

def email_is_valid(email)
    return (email =~ /([-!#-'*+-9=?A-Z^-~]+(\.[-!#-'*+-9=?A-Z^-~]+)*)@[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?(\.[0-9A-Za-z]([0-9A-Za-z-]{0,61}[0-9A-Za-z])?)+/) != nil
end

def is_empty(str)
    return (str =~ /^.*[^\s].*$/) == nil
end


x = "    "

p is_empty(x)
