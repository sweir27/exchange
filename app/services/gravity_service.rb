module GravityService
  def self.fetch_partner(partner_id)
    Rails.cache.fetch("gravity_partner_#{partner_id}", expire_in: Rails.application.config_for(:gravity)['partner_cache_in_seconds']) do
      Adapters::GravityV1.request("/partner/#{partner_id}/all")
    end
  end

  def self.get_merchant_account(partner_id)
    merchant_account = Adapters::GravityV1.request("/merchant_accounts?partner_id=#{partner_id}").first
    raise Errors::OrderError, 'Partner does not have merchant account' if merchant_account.nil?
    merchant_account
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Unable to find partner or merchant account'
  rescue Adapters::GravityError => e
    raise Errors::OrderError, e.message
  end

  def self.get_credit_card(credit_card_id)
    Adapters::GravityV1.request("/credit_card/#{credit_card_id}")
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Credit card not found'
  rescue Adapters::GravityError => e
    raise Errors::OrderError, e.message
  end
end
