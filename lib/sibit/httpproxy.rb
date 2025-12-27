# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'net/http'

# Sibit main class.
class Sibit
  # HTTP client with proxy.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
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
