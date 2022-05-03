# create strings
str1 = "welcome"
str2 = "to"
str3 = "Edpresso"

# delete prefix
a = str1.delete_prefix!("wel")
b = str2.delete_prefix("o")
c = str3.delete_prefix("Ed")

# print results
puts a
puts b
puts c