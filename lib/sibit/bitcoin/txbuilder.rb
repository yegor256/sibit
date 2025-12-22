# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'tx'
require_relative 'key'

class Sibit
  module Bitcoin
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
        inp = InputBuilder.new
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
        BuiltTx.new(txn, @inputs, @outputs)
      end
    end

    # Input builder for collecting input parameters.
    class InputBuilder
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
    class BuiltTx
      def initialize(tx, inputs, outputs)
        @tx = tx
        @inputs_data = inputs
        @outputs_data = outputs
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
        PayloadWrapper.new(@tx.payload)
      end
    end

    # Wrapper for payload with hex conversion.
    class PayloadWrapper
      def initialize(bytes)
        @bytes = bytes
      end

      def bth
        @bytes.unpack1('H*')
      end
    end
  end
end
