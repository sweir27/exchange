class Mutations::SubmitOrder < Mutations::BaseMutation
  null true

  argument :id, ID, required: true

  field :order, Types::OrderType, null: true
  field :errors, [String], null: false

  def resolve(id:)
    order = Order.find(id)
    validate_request!(order)
    {
      order: OrderSubmitService.submit!(order, by: context[:current_user]['id']),
      errors: []
    }
  rescue Errors::ApplicationError, Errors::PaymentError => e
    { order: nil, errors: [e.message] }
  end

  def validate_request!(order)
    raise Errors::AuthError, 'Not permitted' unless context[:current_user]['id'] == order.user_id
  end
end
