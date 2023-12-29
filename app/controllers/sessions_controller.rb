class SessionsController < ApplicationController
  def new
    # OmniAuth magic
    auth = request.env['omniauth.auth']

    pp auth

    # If, for some reason, auth fails and isn't redirected,
    # we will catch it here
    unless auth && auth[:extra][:raw_info][:context]
      return render_error "[install] Invalid credentials:
                       #{JSON.pretty_generate(auth)}"
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

    # Other one-time installation provisioning goes here.

    # Login and redirect to home page
    session[:store_id] = store.id
    session[:user_id] = user.id
    redirect_to '/'
  end

  def show
    # Decode payload
    payload = parse_signed_payload
    return render_error('[load] Invalid payload signature!') unless payload

    email = payload[:user][:email]
    name = payload[:user][:name]
    bc_id = payload[:uid]
    store_hash = payload[:store_hash]

    # Lookup store
    store = Store.where(store_hash: store_hash).first
    return render_error("[load] Store not found!") unless store

    # Find/create user
    user = User.where(email: email).first_or_create do |user|
      user.bc_id = bc_id
      user.name = name
      user.save!
    end
    return render_error('[load] User not found!') unless user

    # Login and redirect to home page
    logger.info "[load] Loading app for user '#{email}' on store '#{store_hash}'"
    session[:store_id] = store.id
    session[:user_id] = user.id

    redirect_to '/'
  end

  def destroy
    # Decode payload
    payload = parse_signed_payload
    return render_error('[destroy] Invalid payload signature!') unless payload

    email = payload[:user][:email]
    name = payload[:user][:name]
    bc_id = payload[:uid]
    store_hash = payload[:store_hash]

    # Lookup store
    store = Store.where(store_hash: store_hash).first
    return render_error("[destroy] Store not found!") unless store

    # Find/create user
    user = User.where(email: email).first_or_create do |user|
      user.bc_id = bc_id
      user.name = name
      user.save!
    end
    return render_error('[destroy] User not found!') unless user

    logger.info "[destroy] Uninstalling app for store '#{store_hash}'"
    store.is_installed = false
    logger.info "[destroy] Removing access_token from store '#{store_hash}'"
    store.access_token = 'uninstalled'
    store.save!

    session.clear

    render json: "[destroy] App uninstalled from store '#{store_hash}'"
  end

  def remove
    render json: {}, status: :no_content
  end

  def failure
    render json: "Your authentication flow has failed with the error: #{params[:message]}"
  end

  def bigcommerce
    @user = User.create_from_provider_data(request.env['omniauth.auth'])
    if @user.persisted?
      sign_in_and_redirect @user
      set_flash_message(:notice, :success, kind: 'Github') if is_navigational_format?
    else
      flash[:error]='There was a problem signing you in through Github. Please register or try signing in later.'
      redirect_to new_user_registration_url
    end
  end

  private

  # Verify given signed_payload string and return the data if valid.
  def parse_signed_payload
    signed_payload = params[:signed_payload]
    message_parts = signed_payload.split('.')

    encoded_json_payload = message_parts[0]
    encoded_hmac_signature = message_parts[1]

    payload = Base64.decode64(encoded_json_payload)
    provided_signature = Base64.decode64(encoded_hmac_signature)

    expected_signature = sign_payload(ENV['BC_CLIENT_SECRET'], payload)

    if secure_compare(expected_signature, provided_signature)
      return JSON.parse(payload, symbolize_names: true)
    end

    nil
  end

  # Sign payload string using HMAC-SHA256 with given secret
  def sign_payload(secret, payload)
    OpenSSL::HMAC::hexdigest('sha256', secret, payload)
  end

  # Time consistent string comparison. Most library implementations
  # will fail fast allowing timing attacks.
  def secure_compare(a, b)
    return false if a.blank? || b.blank? || a.bytesize != b.bytesize
    l = a.unpack "C#{a.bytesize}"

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end

  def render_error(e)
    logger.warn "ERROR: #{e}"
    @error = e
    @again = "Please try reloading or reinstalling the app."
    render json: [@error, @again]
  end

  def logger
    Rails.logger
  end
end
