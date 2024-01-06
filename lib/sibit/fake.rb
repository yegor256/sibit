# frozen_string_literal: true

# Copyright (c) 2019-2024 Yegor Bugayenko
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

require_relative 'version'

# Fake API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2024 Yegor Bugayenko
# License:: MIT
class Sibit
  # Fake API
  class Fake
    def price(_cur = 'USD')
      4_000
    end

    def next_of(_hash)
      nil
    end

    def height(_hash)
      1
    end

    def fees
      { S: 12, M: 45, L: 100, XL: 200 }
    end

    def balance(_address)
      100_000_000
    end

    def utxos(_sources)
      []
    end

    def push(hex)
      # Nothing to do here
    end

    def latest
      '00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71'
    end

    def block(hash)
      {
        provider: self.class.name,
        hash: hash,
        orphan: false,
        next: hash,
        previous: hash,
        txns: [
          {
            hash: hash,
            outputs: [
              {
                address: '1HqhZx8U18TYS5paraTM1MzUQWb7ZbcG9u',
                value: 1000
              }
            ]
          }
        ]
      }
    end
  end
end
