# frozen_string_literal: true

# Basic client contract. All other clients (blockchain.info, client with fallback)
# must implement this methods)
# @todo #36:30m Let's create some implementations of this class.
#  For now, this class doesn't have any implementation and
#  its main purpose is a contract that must be implemented
#  by clients with different APIs and functionality.
# @todo: #36:30m Needs to implement a mechanism for getting API by its core URL or name.
#  For example, the Clients class has a method client(name) that returns the proper client.
class Client
  # Current price of 1 BTC.
  def price(_cur = 'USD')
    raise NotImplementedError, 'Needs to implement this in child classes'
  end

  # Gets the balance of the address, in satoshi.
  def balance(_address)
    raise NotImplementedError, 'Needs to implement this in child classes'
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    raise NotImplementedError, 'Needs to implement this in child classes'
  end

  # Sends a payment and returns the transaction hash.
  #
  # If the payment can't be signed (the key is wrong, for example) or the
  # previous transaction is not found, or there is a network error, or
  # any other reason, you will get an exception. In this case, just try again.
  # It's safe to try as many times as you need. Don't worry about duplicating
  # your transaction, the Bitcoin network will filter duplicates out.
  #
  # If there are more than 1000 UTXOs in the address where you are trying
  # to send bitcoins from, this method won't be helpful.
  #
  # +_amount+: the amount either in satoshis or ending with 'BTC', like '0.7BTC'
  # +_fee+: the miners fee in satoshis (as integer) or S/M/X/XL as a string
  # +_sources+: the hashmap of bitcoin addresses where the coins are now, with
  # their addresses as keys and private keys as values
  # +_target+: the target address to send to
  # +_change+: the address where the change has to be sent to
  def pay(_amount, _fee, _sources, _target, _change)
    raise NotImplementedError, 'Needs to implement this in child classes'
  end

  # Gets the hash of the latest block.
  def latest
    raise NotImplementedError, 'Needs to implement this in child classes'
  end
end
