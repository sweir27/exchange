require 'rails_helper'

describe OrderService, type: :services do
  let(:order) { Fabricate(:order) }
  let(:credit_card_id) { 'cc-1' }
  let(:destination_account_id) { 'destination_account' }
  let(:charge_success) { { id: 'ch-1' } }
  let(:charge_failure) { { failure_message: 'some_error' } }

  describe '#submit!' do
    context 'with a successful transaction' do
      before do
        allow(PaymentService).to receive(:authorize_charge).with(order, order.items_total_cents).and_return(charge_success)
        allow(TransactionService).to receive(:create_success!).with(order, charge_success)
      end

      it 'authorizes a charge for the full amount of the order' do
        OrderService.submit!(order, credit_card_id: credit_card_id, destination_account_id: destination_account_id)
        expect(PaymentService).to have_received(:authorize_charge).with(order, order.items_total_cents)
      end

      it 'creates a record of the transaction' do
        OrderService.submit!(order, credit_card_id: credit_card_id, destination_account_id: destination_account_id)
        expect(TransactionService).to have_received(:create_success!).with(order, charge_success)
      end
    end

    context 'with an unsuccessful transaction' do
      it 'creates a record of the transaction' do
        allow(PaymentService).to receive(:authorize_charge).with(order, order.items_total_cents).and_raise(Errors::PaymentError.new('some_error', charge_failure))
        allow(TransactionService).to receive(:create_failure!).with(order, charge_failure)
        expect { OrderService.submit!(order, credit_card_id: credit_card_id, destination_account_id: destination_account_id) }.to raise_error(Errors::PaymentError)
        expect(TransactionService).to have_received(:create_failure!).with(order, charge_failure)
      end
    end
  end
end
