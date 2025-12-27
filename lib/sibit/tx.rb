# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require_relative 'base58'
require_relative 'bech32'
require_relative 'key'
require_relative 'script'

# Sibit main class.
class Sibit
  # Bitcoin Transaction structure.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
  class Tx
    SIGHASH_ALL = 0x01
    VERSION = 1
    SEQUENCE = 0xffffffff

    attr_reader :inputs, :outputs

    def initialize
      @inputs = []
      @outputs = []
    end

    def add_input(hash:, index:, script:, key:)
      @inputs << Input.new(hash, index, script, key)
    end

    def add_output(value, address)
      @outputs << Output.new(value, address)
    end

    def hash
      Digest::SHA256.hexdigest(Digest::SHA256.digest(payload)).reverse.scan(/../).join
    end

    def payload
      sign_inputs
      serialize
    end

    def hex
      payload.unpack1('H*')
    end

    def in
      @inputs
    end

    def out
      @outputs
    end

    # Transaction input.
    #
    # Author:: Yegor Bugayenko (yegor256@gmail.com)
    # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
    # License:: MIT
    class Input
      attr_reader :hash, :index, :prev_script, :key
      attr_accessor :script_sig

      def initialize(hash, index, script, key)
        @hash = hash
        @index = index
        @prev_script = script
        @key = key
        @script_sig = ''
      end

      def prev_out
        [@hash].pack('H*')
      end

      def prev_out_index
        @index
      end
    end

    # Transaction output.
    #
    # Author:: Yegor Bugayenko (yegor256@gmail.com)
    # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
    # License:: MIT
    class Output
      attr_reader :value

      def initialize(value, address)
        @value = value
        @address = address
      end

      def script
        return segwit_script if @address.downcase.start_with?('bc1')
        p2pkh_script
      end

      def script_hex
        script.unpack1('H*')
      end

      private

      def p2pkh_script
        decoded = Base58.new(@address).decode
        hash = decoded[2..41]
        [0x76, 0xa9, 0x14].pack('C*') + [hash].pack('H*') + [0x88, 0xac].pack('C*')
      end

      def segwit_script
        bech = Bech32.new(@address)
        witness = bech.witness
        len = witness.length / 2
        [0x00, len].pack('C*') + [witness].pack('H*')
      end
    end

    private

    def sign_inputs
      @inputs.each_with_index do |input, idx|
        sighash = signature_hash(idx)
        sig = sign(input.key, sighash)
        pubkey = [input.key.pub].pack('H*')
        input.script_sig = der_sig(sig) + pubkey_script(pubkey)
      end
    end

    def signature_hash(idx)
      tx_copy = serialize_for_signing(idx)
      hash_type = [SIGHASH_ALL].pack('V')
      Digest::SHA256.digest(Digest::SHA256.digest(tx_copy + hash_type))
    end

    def sign(key, hash)
      der = key.sign(hash)
      repack(der)
    end

    def repack(der)
      return der if low_s?(der)
      seq = OpenSSL::ASN1.decode(der)
      r = seq.value[0].value.to_i
      s = seq.value[1].value.to_i
      order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      s = order - s if s > order / 2
      OpenSSL::ASN1::Sequence.new(
        [OpenSSL::ASN1::Integer.new(r), OpenSSL::ASN1::Integer.new(s)]
      ).to_der
    end

    def low_s?(der)
      seq = OpenSSL::ASN1.decode(der)
      s = seq.value[1].value.to_i
      order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      s <= order / 2
    end

    def der_sig(sig)
      data = sig + [SIGHASH_ALL].pack('C')
      [data.length].pack('C') + data
    end

    def pubkey_script(pubkey)
      [pubkey.length].pack('C') + pubkey
    end

    def serialize
      result = [VERSION].pack('V')
      result += varint(@inputs.length)
      @inputs.each do |input|
        result += [input.hash].pack('H*').reverse
        result += [input.index].pack('V')
        result += varint(input.script_sig.length)
        result += input.script_sig
        result += [SEQUENCE].pack('V')
      end
      result += varint(@outputs.length)
      @outputs.each do |output|
        result += [output.value].pack('Q<')
        script = output.script
        result += varint(script.length)
        result += script
      end
      result += [0].pack('V')
      result
    end

    def serialize_for_signing(idx)
      result = [VERSION].pack('V')
      result += varint(@inputs.length)
      @inputs.each_with_index do |input, i|
        result += [input.hash].pack('H*').reverse
        result += [input.index].pack('V')
        if i == idx
          script = [input.prev_script].pack('H*')
          result += varint(script.length)
          result += script
        else
          result += varint(0)
        end
        result += [SEQUENCE].pack('V')
      end
      result += varint(@outputs.length)
      @outputs.each do |output|
        result += [output.value].pack('Q<')
        script = output.script
        result += varint(script.length)
        result += script
      end
      result += [0].pack('V')
      result
    end

    def varint(num)
      return [num].pack('C') if num < 0xfd
      return [0xfd, num].pack('Cv') if num <= 0xffff
      return [0xfe, num].pack('CV') if num <= 0xffffffff
      [0xff, num].pack('CQ<')
    end
  end
end
