# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'version'

# Fake API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Fake
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
    [
      {
        hash: '5de641d3867eb8fec3eb1a5ef2b44df39b54e0b3bb664ab520f2ae26a5b18ffc',
        index: 0,
        value: 100_000_000,
        confirmations: 6,
        script: '76a914c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc88ac'
      }
    ]
  end

  def push(_hex); end

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
