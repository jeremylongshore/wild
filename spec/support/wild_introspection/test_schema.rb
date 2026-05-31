# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :accounts, force: true do |t|
    t.string :name, null: false
    t.string :slug, null: false
    t.string :plan
    t.string :stripe_customer_id
    t.string :tax_id
    t.string :ssn
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.references :account, foreign_key: true
    t.string :email, null: false
    t.string :name, null: false
    t.string :status, default: "active"
    t.string :password_digest
    t.string :otp_secret
    t.string :credit_card_number
    t.timestamps
  end

  create_table :feature_flags, force: true do |t|
    t.string :key, null: false
    t.boolean :enabled, default: false
    t.string :description
    t.timestamps
  end

  create_table :credit_cards, force: true do |t|
    t.references :user, foreign_key: true
    t.string :number
    t.string :cvv
    t.string :expiry
    t.timestamps
  end

  create_table :api_keys, force: true do |t|
    t.references :account, foreign_key: true
    t.string :token
    t.string :name
    t.timestamps
  end
end
