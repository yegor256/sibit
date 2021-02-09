# frozen_string_literal: true

# Copyright (c) 2019-2021 Yegor Bugayenko
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
require_relative '../lib/sibit/fake'
require_relative '../lib/sibit/firstof'

# Sibit::FirstOf test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2021 Yegor Bugayenko
# License:: MIT
class TestFirstOf < Minitest::Test
  def test_not_array
    sibit = Sibit::FirstOf.new(Sibit::Fake.new)
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_one_apis
    sibit = Sibit::FirstOf.new([Sibit::Fake.new])
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_two_apis
    sibit = Sibit::FirstOf.new([Sibit::Fake.new, Sibit::Fake.new])
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_all_fail
    api = Class.new do
      def latest
        raise Sibit::Error, 'intentionally'
      end
    end.new
    sibit = Sibit::FirstOf.new([api, api])
    assert_raises Sibit::Error do
      sibit.latest
    end
  end
end
