# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'uri'
require 'webmock/minitest'
require_relative '../lib/sibit/json'

# Sibit::Json test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestJson < Minitest::Test
  def test_loads_hash
    stub_request(:get, 'https://hello.com').to_return(body: '{"test":123}')
    json = Sibit::Json.new.get(URI('https://hello.com'))
    assert_equal(123, json['test'])
    json = Sibit::Json.new.get(URI('https://hello.com/'))
    assert_equal(123, json['test'])
  end

  def test_post_drops_empty_query
    captured = nil
    fake_http = Class.new do
      define_method(:client) do |_uri|
        client = Object.new
        client.define_singleton_method(:post) do |path, _body, _headers|
          captured = path
          Struct.new(:code, :body).new('200', '')
        end
        client
      end
    end.new
    Sibit::Json.new(http: fake_http).post(URI('https://hello.com/pushtx'), 'deadbeef')
    refute_match(/\?\z/, captured)
    assert_equal('/pushtx', captured)
  end

  def test_post_keeps_query
    stub = stub_request(:post, 'https://hello.com/pushtx?key=abc').to_return(body: '')
    Sibit::Json.new.post(URI('https://hello.com/pushtx?key=abc'), 'deadbeef')
    assert_requested(stub)
  end
end
