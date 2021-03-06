require 'rails_helper'

describe Api::GraphqlController, type: :request do
  describe 'order query' do
    include_context 'GraphQL Client'
    let(:partner_id) { jwt_partner_ids.first }
    let(:second_partner_id) { 'partner-2' }
    let(:user_id) { jwt_user_id }
    let(:second_user) { 'user2' }
    let(:state) { 'PENDING' }
    let!(:user1_order1) { Fabricate(:order, partner_id: partner_id, user_id: user_id, updated_at: 1.day.ago, shipping_total_cents: 100_00, commission_fee_cents: 50_00) }
    let!(:user2_order1) { Fabricate(:order, partner_id: second_partner_id, user_id: second_user) }

    let(:query) do
      <<-GRAPHQL
        query($id: ID!) {
          order(id: $id) {
            id
            userId
            partnerId
            state
            currencyCode
            itemsTotalCents
            shippingTotalCents
            sellerTotalCents
            buyerTotalCents
            lineItems{
              edges{
                node{
                  priceCents
                }
              }
            }
          }
        }
      GRAPHQL
    end

    context 'user accessing their order' do
      it 'returns permission error when query for orders by user not in jwt' do
        expect do
          client.execute(query, id: user2_order1.id)
        end.to raise_error(Graphlient::Errors::ExecutionError, 'order: Not permitted')
      end

      it 'returns order when accessing correct order' do
        result = client.execute(query, id: user1_order1.id)
        expect(result.data.order.user_id).to eq user_id
        expect(result.data.order.partner_id).to eq partner_id
        expect(result.data.order.currency_code).to eq 'usd'
        expect(result.data.order.state).to eq 'PENDING'
        expect(result.data.order.items_total_cents).to eq 0
        expect(result.data.order.seller_total_cents).to eq 50_00
        expect(result.data.order.buyer_total_cents).to eq 100_00
      end

      Order::STATES.each do |state|
        # https://github.com/artsy/exchange/issues/88
        it 'returns proper state' do
          user1_order1.update!(state: state)
          result = client.execute(query, id: user1_order1.id)
          expect(result.data.order.state).to eq state.upcase
        end
      end
    end

    context 'trusted user rules' do
      let(:jwt_user_id) { 'rando' }

      context 'trusted account accessing another account\'s order' do
        let(:jwt_roles) { 'trusted' }

        it 'allows action' do
          expect do
            client.execute(query, id: user2_order1.id)
          end.to_not raise_error
        end

        it 'returns expected payload' do
          result = client.execute(query, id: user2_order1.id)
          expect(result.data.order.user_id).to eq user2_order1.user_id
          expect(result.data.order.partner_id).to eq user2_order1.partner_id
          expect(result.data.order.currency_code).to eq 'usd'
          expect(result.data.order.state).to eq 'PENDING'
          expect(result.data.order.items_total_cents).to eq 0
        end

        it 'cannot access seller_only fields' do
          # TODO: we may want to change this logic later but for now not allowing
          # those fields for trusted apps
          result = client.execute(query, id: user2_order1.id)
          expect(result.data.order.seller_total_cents).to be_nil
        end
      end

      context 'untrusted account accessing another account\'s order' do
        let(:jwt_roles) { 'foobar' }

        it 'raises error' do
          expect do
            client.execute(query, id: user2_order1.id)
          end.to raise_error(Graphlient::Errors::ExecutionError, 'order: Not permitted')
        end
      end
    end

    context 'partner accessing order' do
      it 'returns order when accessing correct order' do
        another_user_order = Fabricate(:order, partner_id: partner_id, user_id: 'someone-else-id')
        result = client.execute(query, id: another_user_order.id)
        expect(result.data.order.user_id).to eq 'someone-else-id'
        expect(result.data.order.partner_id).to eq partner_id
        expect(result.data.order.currency_code).to eq 'usd'
        expect(result.data.order.state).to eq 'PENDING'
        expect(result.data.order.items_total_cents).to eq 0
      end
    end
  end
end
