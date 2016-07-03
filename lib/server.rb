require 'sinatra'
require 'octokit'
require 'json'
require './lib/api'
require './lib/ping_checker'
require './lib/signature_verifier'

class AerynApp < Sinatra::Base

  attr_accessor :signature_verifier
  attr_accessor :ping_checker
  attr_accessor :api

  def initialize(
      signature_verifier = Sinatra::WebHookProcessor.new,
      ping_checker = PingChecker.new,
      api = API.new
    )
    @signature_verifier = signature_verifier
    @ping_checker = ping_checker
    @api = api
  end

  post ENV['WEBHOOK_ENDPOINT'] do
    logger.info 'Received push.'

    request.body.rewind
    payload_body = request.body.read
    push = JSON.parse(payload_body)
    logger.info 'Parsed JSON payload.'

    is_ping = @ping_checker.is_ping?(push)
    is_valid_sig = @signature_verifier.verify_signature(payload_body, request)

    if is_ping
      logger.info 'Received ping.'
      status 200
    elsif is_valid_sig
      logger.info 'Received PR action.'
      result = api.handle_push(push)
      body result.to_json
      logger.info "Processed PR action: #{result}"

      if result['error']
        status 400
      else
        status 200
      end
    else
      logger.info "Received Unauthorized request: #{request}"
      halt 403, "Unauthorized."
    end
  end
end
