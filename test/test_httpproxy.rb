# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/httpproxy'
require_relative 'test__helper'

# Sibit::HttpProxy test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestHttpProxy < Minitest::Test
  def test_creates_http_client
    assert_kind_of(
      Net::HTTP,
      Sibit::HttpProxy.new('proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')),
      'client is not Net::HTTP'
    )
  end

  def test_enables_ssl
    assert_predicate(
      Sibit::HttpProxy.new('proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')),
      :use_ssl?, 'SSL is not enabled'
    )
  end

  def test_sets_read_timeout
    assert_equal(
      240,
      Sibit::HttpProxy.new('proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).read_timeout,
      'read timeout is not 240'
    )
  end

  def test_configures_proxy_address
    assert_equal(
      'proxy.example.com',
      Sibit::HttpProxy.new('proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_address,
      'proxy address is wrong'
    )
  end

  def test_configures_proxy_port
    assert_equal(
      8080,
      Sibit::HttpProxy.new('proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_port,
      'proxy port is wrong'
    )
  end

  def test_configures_proxy_user
    assert_equal(
      'jeff',
      Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_user,
      'proxy user is wrong'
    )
  end

  def test_configures_proxy_password
    assert_equal(
      'swordfish',
      Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_pass,
      'proxy password is wrong'
    )
  end

  def test_parses_address_with_auth
    assert_equal(
      'proxy.example.com',
      Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_address,
      'proxy address with auth is wrong'
    )
  end

  def test_parses_port_with_auth
    assert_equal(
      8080,
      Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
        .client(URI.parse('https://example.com/path')).proxy_port,
      'proxy port with auth is wrong'
    )
  end
end
