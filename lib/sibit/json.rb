# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'cgi'
require 'elapsed'
require 'json'
require 'loog'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'version'

# Json SDK.
#
# It works through the Blockchain API:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit::Json
  # Constructor.
  def initialize(log: Loog::NULL, http: Sibit::Http.new)
    @http = http
    @log = log
  end

  # Send GET request to the HTTP and return JSON response.
  # This method will also log the process and will validate the
  # response for correctness.
  def get(address, headers: {}, accept: [200])
    ret = nil
    elapsed(@log) do
      uri = URI(address.to_s)
      res = @http.client(uri).get(
        "#{uri.path.empty? ? '/' : uri.path}#{"?#{uri.query}" if uri.query}",
        {
          'Accept' => 'application/json',
          'User-Agent' => user_agent,
          'Accept-Charset' => 'UTF-8',
          'Accept-Encoding' => ''
        }.merge(headers)
      )
      unless accept.include?(res.code.to_i)
        raise Sibit::Error, "Failed to retrieve #{uri} (#{res.code}): #{res.body}"
      end
      ret =
        begin
          JSON.parse(res.body)
        rescue JSON::ParserError => e
          raise Sibit::Error, "Can't parse JSON: #{e.message}"
        end
      throw :"GET #{uri}: #{res.code}/#{length(res.body.length)}"
    end
    ret
  end

  def post(address, body, headers: {})
    uri = URI(address.to_s)
    elapsed(@log) do
      res = @http.client(uri).post(
        "#{uri.path}?#{uri.query}",
        "tx=#{CGI.escape(body)}",
        {
          'Accept' => 'text/plain',
          'User-Agent' => user_agent,
          'Accept-Charset' => 'UTF-8',
          'Accept-Encoding' => '',
          'Content-Type' => 'application/x-www-form-urlencoded'
        }.merge(headers)
      )
      unless res.code == '200'
        raise Sibit::Error, "Failed to post tx to #{uri}: #{res.code}\n#{res.body}"
      end
      throw :"POST #{uri}: #{res.code}"
    end
  end

  private

  def length(bytes)
    if bytes > 1024 * 1024
      "#{bytes / (1024 * 1024)}mb"
    elsif bytes > 1024
      "#{bytes / 1024}kb"
    else
      "#{bytes}b"
    end
  end

  def user_agent
    "Anonymous/#{Sibit::VERSION}"
  end
end
