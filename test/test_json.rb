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

  def test_post_passes_body_verbatim
    stub = stub_request(:post, 'https://hello.com/')
      .with(body: 'raw=payload&x=1')
      .to_return(body: 'ok')
    Sibit::Json.new.post(URI('https://hello.com/'), 'raw=payload&x=1')
    assert_requested(stub)
  end

  def test_post_honors_caller_content_type
    stub = stub_request(:post, 'https://hello.com/')
      .with(
        headers: { 'Content-Type' => 'application/json' },
        body: '{"k":"v"}'
      )
      .to_return(body: 'ok')
    Sibit::Json.new.post(
      URI('https://hello.com/'),
      '{"k":"v"}',
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_requested(stub)
  end
end
