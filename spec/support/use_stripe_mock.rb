require 'stripe_mock'

RSpec.shared_context 'use stripe mock' do
  let(:stripe_helper) { StripeMock.create_test_helper }
  before { StripeMock.start }
  after { StripeMock.stop }
  let(:stripe_customer) do
    Stripe::Customer.create(
      email: 'someuser@email.com',
      source: stripe_helper.generate_card_token
    )
  end
  let(:uncaptured_charge) do
    Stripe::Charge.create(
      amount: 22_222,
      currency: 'usd',
      source: stripe_helper.generate_card_token,
      destination: 'ma-1',
      capture: false
    )
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'use stripe mock', include_shared: true
end
