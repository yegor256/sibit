# frozen_string_literal: true

# Copyright (c) 2019-2022 Yegor Bugayenko
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
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit/fake'

# Sibit::Fake test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2022 Yegor Bugayenko
# License:: MIT
class TestFake < Minitest::Test
  def test_fake_object_works
    sibit = Sibit::Fake.new
    assert_equal(4_000, sibit.price)
    assert_equal(12, sibit.fees[:S])
    assert_equal(100_000_000, sibit.balance(''))
    assert_equal([], sibit.utxos(nil))
    assert_equal('00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71', sibit.latest)
  end

  def test_scan_works
    sibit = Sibit.new(api: Sibit::Fake.new)
    hash = '00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71'
    found = false
    tail = sibit.scan(hash) do |addr, tx, satoshi|
      assert_equal(1000, satoshi)
      assert_equal('1HqhZx8U18TYS5paraTM1MzUQWb7ZbcG9u', addr)
      assert_equal("#{hash}:0", tx)
      found = true
    end
    assert(found)
    assert_equal(hash, tail)
  end
end
