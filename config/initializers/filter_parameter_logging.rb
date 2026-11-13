# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :goods_receipt, :idempotency_key, :delivery_reference, :purchase_order, :supplier, :purchase_request, :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :national_id, :bank_account, :salary, :reason, :notes, :artifact, :payload, :body, :signature, :signing_secret, :note
]
