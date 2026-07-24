# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit'
require_relative '../lib/sibit/bestof'
require_relative '../lib/sibit/fake'
require_relative 'test__helper'

# Sibit::BestOf test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
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
        raise(Sibit::Error, 'intentionally')
      end
    end.new
    sibit = Sibit::BestOf.new([api, api])
    assert_raises(Sibit::Error) do
      sibit.latest
    end
  end

  def test_raises_on_disagreement_without_majority
    low = Class.new do
      def balance(_address)
        0
      end
    end.new
    high = Class.new do
      def balance(_address)
        100_000_000
      end
    end.new
    assert_raises(Sibit::Error, 'a two-way balance disagreement cannot resolve silently') do
      Sibit::BestOf.new([low, high]).balance('1anyaddr')
    end
  end

  def test_returns_strict_majority
    high = Class.new do
      def balance(_address)
        100_000_000
      end
    end.new
    low = Class.new do
      def balance(_address)
        0
      end
    end.new
    assert_equal(
      100_000_000,
      Sibit::BestOf.new([high, high, low]).balance('1anyaddr'),
      'a strict majority balance does not win the vote'
    )
  end

  def test_push_stops_at_first_success
    touched = []
    second = Class.new do
      define_method(:push) { |_hex| touched << :second }
    end.new
    first = Class.new do
      def push(_hex); end
    end.new
    Sibit::BestOf.new([first, second]).push('deadbeef')
    assert_empty(touched, 'push cannot broadcast to a second API after the first accepts it')
  end
end
