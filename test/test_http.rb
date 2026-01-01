# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/http'

# Sibit::Http test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestHttp < Minitest::Test
  def test_creates_http_client
    http = Sibit::Http.new
    uri = URI.parse('https://example.com/path')
    client = http.client(uri)
    assert_kind_of(Net::HTTP, client, 'client is not Net::HTTP')
  end

  def test_enables_ssl
    http = Sibit::Http.new
    uri = URI.parse('https://example.com/path')
    client = http.client(uri)
    assert_predicate(client, :use_ssl?, 'SSL is not enabled')
  end

  def test_sets_read_timeout
    http = Sibit::Http.new
    uri = URI.parse('https://example.com/path')
    client = http.client(uri)
    assert_equal(240, client.read_timeout, 'read timeout is not 240')
  end
end
