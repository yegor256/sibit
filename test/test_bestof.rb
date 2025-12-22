# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit'
require_relative '../lib/sibit/fake'
require_relative '../lib/sibit/bestof'

# Sibit::BestOf test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestBestOf < Minitest::Test
  def test_not_array
    sibit = Sibit::BestOf.new(Sibit::Fake.new)
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_one_apis
    sibit = Sibit::BestOf.new([Sibit::Fake.new])
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_two_apis
    sibit = Sibit::BestOf.new([Sibit::Fake.new, Sibit::Fake.new])
    assert_equal(64, sibit.latest.length)
    assert_equal(12, sibit.fees[:S])
  end

  def test_all_fail
    api = Class.new do
      def latest
        raise Sibit::Error, 'intentionally'
      end
    end.new
    sibit = Sibit::BestOf.new([api, api])
    assert_raises Sibit::Error do
      sibit.latest
    end
  end
end
