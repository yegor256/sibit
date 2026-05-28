# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/http'
require_relative 'test__helper'

# Sibit::Http test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestHttp < Minitest::Test
  def test_creates_http_client
    assert_kind_of(
      Net::HTTP, Sibit::Http.new.client(URI.parse('https://example.com/path')),
      'client is not Net::HTTP'
    )
  end

  def test_enables_ssl
    assert_predicate(
      Sibit::Http.new.client(URI.parse('https://example.com/path')), :use_ssl?,
      'SSL is not enabled'
    )
  end

  def test_sets_read_timeout
    assert_equal(
      240, Sibit::Http.new.client(URI.parse('https://example.com/path')).read_timeout,
      'read timeout is not 240'
    )
  end
end
