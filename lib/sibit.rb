# frozen_string_literal: true

# Copyright (c) 2019 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'bitcoin'
require 'typhoeus'
require 'json'

# Sibit main class.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class Sibit
  # Current version of the library.
  VERSION = '1.0.snapshot'

  # Generate new Bitcon private key.
  def generate
    key = Bitcoin::Key.generate
    key.priv
  end

  # Create Bitcon address using the private key.
  def create(pvt)
    key = Bitcoin::Key.new
    key.priv = pvt
    key.addr
  end

  # Get the balance of the address, in satoshi.
  def balance(address)
    request = Typhoeus::Request.new(
      "https://blockchain.info/rawaddr/#{address}",
      method: :get,
      headers: {}
    )
    request.run
    response = request.response
    json = JSON.parse(response.body)
    json['final_balance']
  end
end
