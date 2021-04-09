# ruby spec/mysql2/error_debug.rb
$LOAD_PATH << 'lib'
require 'mysql2'
require 'yaml'

DatabaseCredentials = YAML.load_file('spec/configuration.yml')
client = Mysql2::Client.new(DatabaseCredentials['root'])

invalid_utf8 = ["e5c67d1f"].pack('H*').force_encoding(Encoding::UTF_8)
begin
  client.query(invalid_utf8)
rescue Mysql2::Error => bad_err
  p "[DEBUG] include? #{bad_err.message.include?("??}\u001F")}"
  p "[DEBUG] bad_err.message: #{bad_err.message}"
end
