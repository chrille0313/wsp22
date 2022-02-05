require 'sinatra'
require 'slim'
require 'sqlite3'


def connect_to_db(name, rootDir="db")
    db = SQLite3::Database.new("#{rootDir}/#{name}.db")
    db.results_as_hash = true
    return db
end


get('/')  do
  slim(:home)
end
