# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/client'

class TestClient < Minitest::Test
  def self.client
    Client.new
  end

  def test_price
    error = assert_raises NotImplementedError do
      TestClient.client.price('_cur')
    end
    assert_equal('Needs to implement this in child classes', error.message)
  end

  def test_balance
    error = assert_raises NotImplementedError do
      TestClient.client.balance('_address')
    end
    assert_equal('Needs to implement this in child classes', error.message)
  end

  def test_fees
    error = assert_raises NotImplementedError do
      TestClient.client.fees
    end
    assert_equal('Needs to implement this in child classes', error.message)
  end

  def test_pay
    error = assert_raises NotImplementedError do
      TestClient.client.pay('amount', 'fee', 'sources', 'target', 'change')
    end
    assert_equal('Needs to implement this in child classes', error.message)
  end

  def test_latest
    error = assert_raises NotImplementedError do
      TestClient.client.latest
    end
    assert_equal('Needs to implement this in child classes', error.message)
  end
end
