require 'SQlite3'

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


db = connect_to_db("database")
p is_unique(db, "accounts", "username", "test OR 1=1;")
# p is_unique(db, "accounts", "username", "chrille0313")
