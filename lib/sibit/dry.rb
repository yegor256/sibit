# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'decoor'
require 'loog'

# Dry mode decorator for API classes.
#
# Wraps any API object and prevents push() from sending transactions.
# All other methods are delegated to the wrapped API unchanged.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit::Dry
  def initialize(api, log: Loog::NULL)
    @api = api
    @log = log
  end

  decoor(:api)

  def push(_hex)
    @log.info("Transaction not pushed, dry mode is ON (#{@api.class.name})")
    nil
  end
end
