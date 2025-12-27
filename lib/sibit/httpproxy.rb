# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'net/http'

# Sibit main class.
class Sibit
  # HTTP client with proxy.
  #
  # Accepts proxy address in format: host:port or user:password@host:port
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
  class HttpProxy
    def initialize(addr)
      @user, @password, @host, @port = parse(addr)
    end

    def client(uri)
      http = Net::HTTP.new(uri.host, uri.port, @host, @port.to_i, @user, @password)
      http.use_ssl = true
      http.read_timeout = 240
      http
    end

    private

    def parse(addr)
      if addr.include?('@')
        auth, hostport = addr.split('@')
        user, password = auth.split(':')
        host, port = hostport.split(':')
        [user, password, host, port]
      else
        host, port = addr.split(':')
        [nil, nil, host, port]
      end
    end
  end
end
