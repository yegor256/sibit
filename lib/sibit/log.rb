# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

# The log.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Log.
  class Log
    # Constructor.
    #
    # You may provide the log you want to see the messages in. If you don't
    # provide anything, the console will be used. The object you provide
    # has to respond to the method +info+ or +puts+ in order to receive logging
    # messages.
    def initialize(log = $stdout)
      @log = log
    end

    def info(msg)
      if @log.respond_to?(:info)
        @log.info(msg)
      elsif @log.respond_to?(:puts)
        @log.puts(msg)
      end
    end
  end
end
