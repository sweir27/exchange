module OrderService
  def self.create!(user_id:, partner_id:, currency_code:, line_items: [])
    raise Errors::OrderError, 'Currency not supported' unless valid_currency_code?(currency_code)
    Order.transaction do
      abandon_pending_orders!(user_id) if pending_order?(user_id)
      order = Order.create!(user_id: user_id, partner_id: partner_id, currency_code: currency_code, state: Order::PENDING)
      line_items.each { |li| LineItemService.create!(order, li) }
      # queue a job for few days from now to abandon the order
      order
    end
  end

  # rubocop:disable Lint/UnusedMethodArgument
  def self.submit!(order, credit_card_id:, destination_account_id:)
    Order.transaction do
      # verify price change?
      order.credit_card_id = credit_card_id
      order.destination_account_id = destination_account_id
      order.submit!
      charge = PaymentService.authorize_charge(order, order.items_total_cents)
      TransactionService.create_success!(order, charge)
      order.save!
    end
    order
  rescue Errors::PaymentError => e
    TransactionService.create_failure!(order, e.body)
    raise e
  end

  # rubocop:enable Lint/UnusedMethodArgument

  def self.approve!(order)
    Order.transaction do
      order.approve!
      order.save!
      # TODO: process the charge by calling gravity with current credit_card_id and price
    end
    order
  end

  def self.finalize!(order)
    Order.transaction do
      order.finalize!
      order.save!
      # TODO: process the charge by calling gravity with current credit_card_id and price
    end
    order
  end

  def self.reject!(order)
    Order.transaction do
      order.reject!
      order.save!
      # TODO: release the charge
    end
    order
  end

  def self.abandon!(order)
    Order.transaction do
      order.abandon!
      order.save!
    end
  end

  def self.user_pending_artwork_order(user_id, artwork_id, edition_set_id = nil)
    Order.pending.joins(:line_items).find_by(user_id: user_id, line_items: { artwork_id: artwork_id, edition_set_id: edition_set_id })
  end

  def self.pending_order?(user_id)
    Order.pending.where(user_id: user_id).exists?
  end

  def self.abandon_pending_orders!(user_id)
    Order.pending.where(user_id: user_id).each do |o|
      abandon!(o)
    end
  end

  def self.valid_currency_code?(currency_code)
    currency_code == 'usd'
  end
end
