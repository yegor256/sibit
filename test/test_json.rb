# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'webmock/minitest'
require 'uri'
require_relative '../lib/sibit/json'

# Sibit::Json test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestJson < Minitest::Test
  def test_loads_hash
    stub_request(:get, 'https://hello.com').to_return(body: '{"test":123}')
    json = Sibit::Json.new.get(URI('https://hello.com'))
    assert_equal(123, json['test'])
    json = Sibit::Json.new.get(URI('https://hello.com/'))
    assert_equal(123, json['test'])
  end
end
