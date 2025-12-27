# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'key'
require_relative 'tx'

# Sibit main class.
class Sibit
  # Bitcoin Transaction Builder.
  #
  # Provides a similar interface to Bitcoin::Builder::TxBuilder for
  # building and signing Bitcoin transactions.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
  class TxBuilder
    def initialize
      @inputs = []
      @outputs = []
    end

    def input
      inp = Input.new
      yield inp
      @inputs << inp
    end

    def output(value, address)
      @outputs << { value: value, address: address }
    end

    def tx(input_value:, leave_fee:, extra_fee:, change_address:)
      txn = Tx.new
      @inputs.each do |inp|
        txn.add_input(
          hash: inp.prev_out_hash,
          index: inp.prev_out_idx,
          script: inp.script,
          key: inp.key
        )
      end
      total_out = @outputs.sum { |o| o[:value] }
      @outputs.each { |o| txn.add_output(o[:value], o[:address]) }
      if leave_fee
        change = input_value - total_out - extra_fee
        txn.add_output(change, change_address) if change.positive?
      end
      Built.new(txn, @inputs, @outputs)
    end

    # Input builder for collecting input parameters.
    #
    # Author:: Yegor Bugayenko (yegor256@gmail.com)
    # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
    # License:: MIT
    class Input
      attr_reader :prev_out_hash, :prev_out_idx, :script, :key

      def prev_out(hash)
        @prev_out_hash = hash
      end

      def prev_out_index(idx)
        @prev_out_idx = idx
      end

      def prev_out_script=(scr)
        @script = scr
      end

      def signature_key(key)
        @key = key
      end
    end

    # Wrapper for built transaction with convenience methods.
    #
    # Author:: Yegor Bugayenko (yegor256@gmail.com)
    # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
    # License:: MIT
    class Built
      def initialize(txn, inputs, outputs)
        @tx = txn
        @inputs = inputs
        @outputs = outputs
      end

      def hash
        @tx.hash
      end

      def in
        @tx.in
      end

      def out
        @tx.out
      end

      def inputs
        @tx.inputs
      end

      def outputs
        @tx.outputs
      end

      def to_payload
        Payload.new(@tx.payload)
      end

      # Wrapper for payload with hex conversion.
      #
      # Author:: Yegor Bugayenko (yegor256@gmail.com)
      # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
      # License:: MIT
      class Payload
        def initialize(bytes)
          @bytes = bytes
        end

        def bth
          @bytes.unpack1('H*')
        end
      end
    end
  end
end
