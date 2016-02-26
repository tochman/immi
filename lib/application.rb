
require 'sinatra/base'
require 'padrino-helpers'
require 'data_mapper'
if ENV['RACK_ENV'] != 'production'
  require 'pry'
  require 'dotenv'
end
require './lib/membership'
require './lib/user'
require './lib/delivery'
require './lib/student'
require './lib/csv_parse'
require './lib/certificate'

class WorkshopApp < Sinatra::Base
  if ENV['RACK_ENV'] != 'production'
    Dotenv.load
  end
  include CSVParse
  register Padrino::Helpers
  set :protect_from_csrf, true
  enable :sessions
  set :session_secret, '112233rlkgrOVNRWOuhsunvwoIE64875644556677' #`or whatever you fancy as a secret.

  env = ENV['RACK_ENV'] || 'development'
  #  DataMapper.setup(:default, ENV['DATABASE_URL'] || "postgres://localhost/workshop_#{env}")
  DataMapper.setup(:default, ENV['DATABASE_URL'] || "postgres://postgres:postgres@localhost/immi-certs_#{env}")
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.finalize
    DataMapper.auto_upgrade!

    before do
    @user = User.get(session[:user_id]) unless is_user?
  end

  register do
    def auth(type)
      condition do
        restrict_access = Proc.new { session[:flash] = 'Du har inte behörighet att visa denna sida'; redirect '/' }
        restrict_access.call unless send("is_#{type}?")
      end
    end
  end

  helpers do
    def is_user?
      @user != nil
    end

    def current_user
      @user
    end
  end

  get '/' do
    erb :index
  end

  get '/courses/index' do
    @courses = Membership.all
    erb :'courses/index'
   end

   get '/courses/create', auth: :user do
     erb :'courses/create'
   end

   post '/courses/create' do
     Membership.create(title: params[:course][:title],description: params[:course][:description])
    redirect 'courses/index'
   end

   get '/courses/:id/add_date', auth: :user do
     @course = Membership.get(params[:id])
     erb :'courses/add_date'
   end

  post '/courses/new_date', auth: :user do
    course = Membership.get(params[:course_id])
    course.deliveries.create(start_date: params[:start_date])
    redirect 'courses/index'
 end

get '/courses/deliveries/show/:id' do
  @delivery = Delivery.get(params[:id].to_i)
  erb :'courses/deliveries/show'
end

#test för ta bort medlemstyp
#get "/courses/:id/delete" do
#  @course = Course.get(params[:id])
#  erb :delete
#end
#test för ta bort medlemstyp
#delete "/courses/:id" do
#  n = @course = Course.get(params[:id])
#  n.destroy!
#  redirect "/courses/index"
#end


post '/courses/deliveries/file_upload' do
  @delivery = Delivery.get(params[:id].to_i)
  CSVParse.import(params[:file][:tempfile], Student, @delivery)
  redirect "/courses/deliveries/show/#{@delivery.id}"
end

get '/courses/generate/:id', auth: :user do
  @delivery = Delivery.get(params[:id])
  if !@delivery.certificates.find(delivery_id: @delivery.id).size.nil?
    session[:flash] = 'Intyg har redan skapats'
  else
    @delivery.students.each do |student|
      cert = student.certificates.create(created_at: DateTime.now, delivery: @delivery)
      keys = CertificateGenerator.generate(cert)
      cert.update(certificate_key: keys[:certificate_key], image_key: keys[:image_key])
    end
    session[:flash] = "Skapat #{@delivery.students.count} intyg"
  end
  redirect "/courses/deliveries/show/#{@delivery.id}"
end

   get '/users/register' do
    erb :'users/register'

   end


   post '/users/create' do
    begin
      User.create(name: params[:user][:name],
                  email: params[:user][:email],
                  password: params[:user][:password],
                  password_confirmation: params[:user][:password_confirmation])
      session[:flash] = "Ditt konto är skapat, #{params[:user][:name]}"
      redirect '/'
    rescue
      session[:flash] = 'Kunde inte registrera dig... Kolla vad du skrev.'
      redirect '/users/register'
    end
  end

  get '/users/login' do
   erb :'users/login'
   end

 get '/users/logout' do
       session[:user_id] = nil
       session[:flash] = 'Du är nu utloggad'
       redirect '/'
     end

   post '/users/session' do
     @user = User.authenticate(params[:email], params[:password])
     session[:user_id] = @user.id
     session[:flash] = "Inloggad som  #{@user.name}"
     redirect '/'
   end

  # Verification URI
  get '/verify/:hash' do
    @certificate = Certificate.first(identifier: params[:hash])
    if @certificate
      @image = "/img/usr/#{env}/" + [@certificate.student.full_name, @certificate.delivery.start_date].join('_').downcase.gsub!(/\s/, '_') + '.jpg'
      erb :'verify/valid'
    else
      erb :'verify/invalid'
    end
  end


  # start the server if ruby file executed directly
  run! if app_file == $0
end