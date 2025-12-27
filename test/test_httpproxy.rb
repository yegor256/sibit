# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/httpproxy'

# Sibit::HttpProxy test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestHttpProxy < Minitest::Test
  def test_creates_http_client
    proxy = Sibit::HttpProxy.new('proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_kind_of(Net::HTTP, client, 'client is not Net::HTTP')
  end

  def test_enables_ssl
    proxy = Sibit::HttpProxy.new('proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_predicate(client, :use_ssl?, 'SSL is not enabled')
  end

  def test_sets_read_timeout
    proxy = Sibit::HttpProxy.new('proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal(240, client.read_timeout, 'read timeout is not 240')
  end

  def test_configures_proxy_address
    proxy = Sibit::HttpProxy.new('proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal('proxy.example.com', client.proxy_address, 'proxy address is wrong')
  end

  def test_configures_proxy_port
    proxy = Sibit::HttpProxy.new('proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal(8080, client.proxy_port, 'proxy port is wrong')
  end

  def test_configures_proxy_user
    proxy = Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal('jeff', client.proxy_user, 'proxy user is wrong')
  end

  def test_configures_proxy_password
    proxy = Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal('swordfish', client.proxy_pass, 'proxy password is wrong')
  end

  def test_parses_address_with_auth
    proxy = Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal('proxy.example.com', client.proxy_address, 'proxy address with auth is wrong')
  end

  def test_parses_port_with_auth
    proxy = Sibit::HttpProxy.new('jeff:swordfish@proxy.example.com:8080')
    uri = URI.parse('https://example.com/path')
    client = proxy.client(uri)
    assert_equal(8080, client.proxy_port, 'proxy port with auth is wrong')
  end
end
