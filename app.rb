require 'sinatra'
require 'slim'
require 'sqlite3'

enable :sessions


def connect_to_db(name, rootDir="db")
    db = SQLite3::Database.new("#{rootDir}/#{name}.db")
    db.results_as_hash = true
    return db
end


helpers do 

end

get('/')  do
  slim(:index)
end


get('/register') do
    slim(:register)
end


post('/users/new') do 
    username = params[:username]
    password = params[:password]
    confirm_password = params[:confirm_password]

    if password = confirm_password
        password_digest = BCrypt::Password.create(password)
        db = connect_to_db("database")
        db.execute('INSERT INTO users (username, password) VALUES (?, ?)', username, password_digest)
        redirect("/")
    else
        "Passwords didn't match!"
    end
end


get('/login') do
    slim(:login)
end


post('/login-user') do
    username = params[:username]
    password = params[:password]

    db = connect_to_db("database")
    query = db.execute("SELECT * FROM users WHERE username = ?", username).first
    qPwd = query["password"]
    qId = query["id"]

    if BCrypt::Password.new(qPwd) == password
        session[:id] = qId
        redirect("/todos")
    else
        "Wrong Password!"
    end
end


post('/logout') do
    session.delete()
    redirect('/login')
end

=begin

get("/asdads") do
  results = session[:results]
  if results == nil
      results = []
      session[:results] = results
  end

  slim(:calculator, locals:{previous:results})
end


post("/reset") do
  session.destroy()
  redirect("/")
end


post("/calculate") do
  num1 = params[:num0].to_f
  num2 = params[:num1].to_f

  res = nil
  operator = params[:operator]

  case operator
      when "+"
          res="#{num1} + #{num2} = #{num1+num2}"
      when "-"
          res="#{num1} - #{num2} = #{num1-num2}"
      when "*"
          res="#{num1} * #{num2} = #{num1*num2}"
      when "/"
          if num2 == 0
              rest="Can't divide by 0!"
          else
              res="#{num1} / #{num2} = #{num1/num2}"
          end
  end

  if res != nil
      results = session[:results]
      if results == nil
          results = []
      end
      results.insert(0,res)
      session[:results] = results
  end
  
  redirect("/")
end
=end