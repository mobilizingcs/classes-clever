require 'sinatra'
require 'clever-ruby'
require 'tilt/erb'
require 'jwt'
require 'openssl'
require 'json'

configure do
  # turn keycloak realm pub key into an actual openssl compat pub key.
  keycloak_config = JSON.parse(File.read('keycloak.json'))
  @s = "-----BEGIN PUBLIC KEY-----\n"
  @s += keycloak_config['realm-public-key'].scan(/.{1,64}/).join("\n")
  @s += "\n-----END PUBLIC KEY-----\n"
  @key = OpenSSL::PKey::RSA.new @s
  set :keycloak_pub_key, @key
  set :keycloak_client_id, keycloak_config['resource']
  set :keycloak_url, keycloak_config['auth-server-url'] + '/' + keycloak_config['realm'] + '/'

  # configure clever client. the clever-ruby gem uses a global to handle interactions.
  Clever.configure do |config|
   config.token = 'DEMO_TOKEN'
  end

  # set up the rest of sinatra config stuffz
  set :server, :puma
  set :environment, :production
end

helpers do
  def authorize!
    if env['HTTP_AUTHORIZATION']
      access_token = env['HTTP_AUTHORIZATION'].split(' ').last
    else
      halt 401
    end
    @decoded_token = JWT.decode access_token, settings.keycloak_pub_key, true, { :algorithm => 'RS256' }
    @email = @decoded_token[0]["email"]
    teacher_results = Clever::Teacher.find(nil, filters = {:where => "{\"email\":\"#{@email}\"}" })
    halt 401, "Your email address is not unique. Exploding into a million pieces!" if teacher_results.count != 1
    @teacher = teacher_results.first
  end
end


get '/' do
 File.read(File.join('public', 'index.html'))
end

get '/ohmage.js' do
  File.read(File.join('public', 'ohmage.js'))
end

get '/sections' do
  authorize! 
  erb :sections, :locals => {sections: @teacher.sections}
end

get '/section/:id/students' do
  authorize!
  content_type :json
  @section = @teacher.sections.find {|s| s.id == params["id"]}
  json_array = []
  @section.students.each {|x| json_array << x.to_h }
  json_array.to_json
end