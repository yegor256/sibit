# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'net/http'

# HTTP interface.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # This HTTP client will be used by default.
  class Http
    def client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 240
      http
    end
  end

  # This HTTP client with proxy.
  class HttpProxy
    def initialize(addr)
      @host, @port = addr.split(':')
    end

    def client(uri)
      http = Net::HTTP.new(uri.host, uri.port, @host, @port.to_i)
      http.use_ssl = true
      http.read_timeout = 240
      http
    end
  end
end
