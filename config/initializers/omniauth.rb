Rails.application.config.middleware.use OmniAuth::Builder do
  provider :bigcommerce, ENV['BC_CLIENT_ID'], ENV['BC_CLIENT_SECRET'],
           {
             token_params: {
               client_id: ENV['BC_CLIENT_ID'],
               client_secret: ENV['BC_CLIENT_SECRET']
             }
           }
  OmniAuth.config.full_host = ENV['APP_URL'] || nil
end