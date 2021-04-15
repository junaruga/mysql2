# ruby spec/mysql2/error_debug.rb
$LOAD_PATH << 'lib'

require 'mysql2'
client = Mysql2::Client.new(:host => "127.0.0.1", :port => '13306', :username => "root")
str = ["e5c67d1f"].pack('H*')
invalid_utf8 = str.force_encoding(Encoding::UTF_8)
begin
  client.query(invalid_utf8)
rescue Mysql2::Error => bad_err
  p bad_err.message
end
