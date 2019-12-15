# frozen_string_literal: true

# Copyright (c) 2019 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'json'
require 'uri'
require_relative 'version'
require_relative 'error'
require_relative 'http'

# Json SDK.
#
# It works through the Blockchain API:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class Sibit
  # JSON processing.
  class Json
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new)
      @http = http
      @log = log
    end

    # Send GET request to the HTTP and return JSON response.
    # This method will also log the process and will validate the
    # response for correctness.
    def get(uri)
      start = Time.now
      res = @http.client(uri).get(
        "#{uri.path}?#{uri.query}",
        'Accept' => 'text/plain',
        'User-Agent' => user_agent,
        'Accept-Encoding' => ''
      )
      unless res.code == '200'
        raise Sibit::Error, "Failed to retrieve #{uri} (#{res.code}): #{res.body}"
      end
      @log.info("GET #{uri}: #{res.code}/#{res.body.length}b in #{age(start)}")
      JSON.parse(res.body)
    end

    def post(uri, body)
      start = Time.now
      res = @http.client(uri).post(
        "#{uri.path}?#{uri.query}",
        "tx=#{CGI.escape(body)}",
        'Accept' => 'text/plain',
        'User-Agent' => user_agent,
        'Accept-Encoding' => '',
        'Content-Type' => 'application/x-www-form-urlencoded'
      )
      unless res.code == '200'
        raise Sibit::Error, "Failed to post tx to #{uri}: #{res.code}\n#{res.body}"
      end
      @log.info("POST #{uri}: #{res.code} in #{age(start)}")
    end

    private

    def age(start)
      "#{((Time.now - start) * 1000).round}ms"
    end

    def user_agent
      "Anonymous/#{Sibit::VERSION}"
    end
  end
end
