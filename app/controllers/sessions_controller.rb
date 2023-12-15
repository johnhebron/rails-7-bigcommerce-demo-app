class SessionsController < ApplicationController
  def new
    # OmniAuth magic
    auth = request.env['omniauth.auth']

    # If, for some reason, auth fails and isn't redirected,
    # we will catch it here
    unless auth && auth[:extra][:raw_info][:context]
      render json: "[install] Invalid credentials: #
                       {JSON.pretty_generate(auth[:extra])}"
    end

    # Set up our variables we will need to generate a User and a Store
    email = auth[:info][:email]
    name = auth[:info][:name]
    bc_id = auth[:uid]
    store_hash = auth[:extra][:context].split('/')[1]
    token = auth[:credentials][:token]
    scopes = auth[:extra][:scopes]

    # Look for existing store by store_hash
    store = Store.where(store_hash: store_hash).first

    if store
      logger.info "[install] Updating token for store '#{store_hash}'
               with scope '#{scopes}'"
      store.update(access_token: token,
                   scopes: scopes,
                   is_installed: true)
    else
      # Create store record
      logger.info "[install] Installing app for store '#{store_hash}'
               with admin '#{email}'"
      store = Store.create(store_hash: store_hash,
                           access_token: token,
                           scopes: scopes,
                           is_installed: true)
    end

    # Find or create user by email
    user = User.where(email: email).first_or_create do |user|
      user.bc_id = bc_id
      user.name = name
      user.save!
    end

    # Login and redirect to home page
    session[:store_id] = store.id
    session[:user_id] = user.id
    redirect_to '/'
  end

  def show
  end

  def destroy
  end

  def remove
  end

  def failure
  end
end
