class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  after_action :set_header_for_iframe

  private

  def set_header_for_iframe
    response.headers.delete "X-Frame-Options"
  end
end
