# Seeds are idempotent - safe to run repeatedly.

admin_users = [
  { email: "jeremy@blueridgeruby.com", first_name: "Jeremy", last_name: "Smith" }
]

admin_users.each do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |u|
    u.first_name = attrs[:first_name]
    u.last_name  = attrs[:last_name]
    u.role       = :admin
  end
end
