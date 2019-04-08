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

require 'minitest/autorun'
require_relative '../lib/sibit'

# Sibit.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class TestSibit < Minitest::Test
  def test_generate_key
    sibit = Sibit.new
    pkey = sibit.generate
    assert(!pkey.nil?)
    assert(/^[0-9a-f]{64}$/.match?(pkey))
  end

  def test_create_address
    sibit = Sibit.new
    pkey = sibit.generate
    address = sibit.create(pkey)
    assert(!address.nil?)
    assert(/^1[0-9a-zA-Z]+$/.match?(address))
  end

  def test_gets_balance
    sibit = Sibit.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert(balance.is_a?(Integer))
  end
end
