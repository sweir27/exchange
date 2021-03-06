class Types::LineItemType < Types::BaseObject
  description 'A Line Item'
  graphql_name 'LineItem'

  field :id, ID, null: false
  field :price_cents, Integer, null: false
  field :artwork_id, String, null: false
  field :edition_set_id, String, null: true
  field :quantity, Integer, null: false
  field :created_at, Types::DateTimeType, null: false
  field :updated_at, Types::DateTimeType, null: false
  field :fulfillments, Types::FulfillmentType.connection_type, null: true
end
