# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require_relative 'base58'
require_relative 'bech32'
require_relative 'error'
require_relative 'key'
require_relative 'script'

# Sibit main class.
class Sibit
  # Bitcoin Transaction structure.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
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

    def add_input(hash:, index:, script:, key:, value: 0)
      @inputs << Input.new(hash, index, script, key, value)
    end

    def add_output(value, address)
      @outputs << Output.new(value, address)
    end

    def hash
      sign_inputs
      Digest::SHA256.hexdigest(
        Digest::SHA256.digest(serialize(witness: false))
      ).scan(/../).reverse.join
    end

    def payload
      return @payload if @payload
      sign_inputs
      @payload = serialize
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
    # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
    # License:: MIT
    class Input
      attr_reader :hash, :index, :prev_script, :key, :value
      attr_accessor :script_sig, :witness

      def initialize(hash, index, script, key, value)
        @hash = hash
        @index = index
        @prev_script = script
        @key = key
        @value = value
        @script_sig = ''
        @witness = []
      end

      def prev_out
        [@hash].pack('H*')
      end

      def prev_out_index
        @index
      end

      def segwit?
        bytes = [@prev_script].pack('H*').bytes
        bytes.length == 22 && bytes[0].zero? && bytes[1] == 20
      end
    end

    # Transaction output.
    #
    # Author:: Yegor Bugayenko (yegor256@gmail.com)
    # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
    # License:: MIT
    class Output
      attr_reader :value

      def initialize(value, address)
        @value = value
        @address = address
      end

      def script
        return segwit_script if segwit?
        return p2pkh_script if %w[00 6f].include?(version)
        return p2sh_script if %w[05 c4].include?(version)
        raise(Sibit::Error, "Address '#{@address}' has an unsupported version byte 0x#{version}")
      end

      def segwit?
        @address.downcase.start_with?('bc1', 'tb1', 'bcrt1')
      end

      def script_hex
        script.unpack1('H*')
      end

      private

      def decoded
        return @decoded if @decoded
        hex = Base58.new(@address).decode
        unless hex.length == 50
          raise(Sibit::Error, "Address '#{@address}' does not decode to 25 bytes")
        end
        unless hex[-8..] == Base58.new(hex[0..-9]).check
          raise(Sibit::Error, "Address '#{@address}' fails its Base58 checksum")
        end
        @decoded = hex
      end

      def version
        decoded[0, 2]
      end

      def hash160
        [decoded[2, 40]].pack('H*')
      end

      def p2pkh_script
        [0x76, 0xa9, 0x14].pack('C*') + hash160 + [0x88, 0xac].pack('C*')
      end

      def p2sh_script
        [0xa9, 0x14].pack('C*') + hash160 + [0x87].pack('C*')
      end

      def segwit_script
        bech = Bech32.new(@address)
        program = bech.witness
        [opcode(bech.version), program.length / 2].pack('C*') + [program].pack('H*')
      end

      def opcode(version)
        version.zero? ? 0x00 : 0x50 + version
      end
    end

    private

    def witness?
      @inputs.any?(&:segwit?)
    end

    def sign_inputs
      return if @signed
      @inputs.each_with_index do |input, idx|
        sig = sign(input.key, (input.segwit? ? segwit_sighash(idx) : legacy_sighash(idx)))
        pubkey = [input.key.pub].pack('H*')
        if input.segwit?
          input.witness = [(sig + [SIGHASH_ALL].pack('C')).bytes, pubkey.bytes]
        else
          input.script_sig = der_sig(sig) + pubkey_script(pubkey)
        end
      end
      @signed = true
    end

    def legacy_sighash(idx)
      Digest::SHA256.digest(
        Digest::SHA256.digest(serialize_for_signing(idx) + [SIGHASH_ALL].pack('V'))
      )
    end

    def segwit_sighash(idx)
      input = @inputs[idx]
      preimage = [VERSION].pack('V')
      preimage += hash_prevouts
      preimage += hash_sequence
      preimage += [input.hash].pack('H*').reverse
      preimage += [input.index].pack('V')
      preimage += script_code(input)
      preimage += [input.value].pack('Q<')
      preimage += [SEQUENCE].pack('V')
      preimage += hash_outputs
      preimage += [0].pack('V')
      preimage += [SIGHASH_ALL].pack('V')
      Digest::SHA256.digest(Digest::SHA256.digest(preimage))
    end

    def hash_prevouts
      Digest::SHA256.digest(
        Digest::SHA256.digest(
          @inputs.map do |i|
            [i.hash].pack('H*').reverse + [i.index].pack('V')
          end.join
        )
      )
    end

    def hash_sequence
      Digest::SHA256.digest(Digest::SHA256.digest(@inputs.map { [SEQUENCE].pack('V') }.join))
    end

    def hash_outputs
      Digest::SHA256.digest(
        Digest::SHA256.digest(
          @outputs.map do |o|
            [o.value].pack('Q<') + varint(o.script.length) + o.script
          end.join
        )
      )
    end

    def script_code(input)
      code = [
        0x76, 0xa9,
        0x14
      ].pack('C*') + [input.prev_script[4..]].pack('H*') + [0x88, 0xac].pack('C*')
      varint(code.length) + code
    end

    def sign(key, hash)
      repack(key.sign(hash))
    end

    def repack(der)
      return der if low_s?(der)
      seq = OpenSSL::ASN1.decode(der)
      s = Integer(seq.value[1].value)
      order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      s = order - s if s > order / 2
      OpenSSL::ASN1::Sequence.new(
        [OpenSSL::ASN1::Integer.new(Integer(seq.value[0].value)), OpenSSL::ASN1::Integer.new(s)]
      ).to_der
    end

    def low_s?(der)
      Integer(OpenSSL::ASN1.decode(der).value[1].value) <=
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 / 2
    end

    def der_sig(sig)
      data = sig + [SIGHASH_ALL].pack('C')
      [data.length].pack('C') + data
    end

    def pubkey_script(pubkey)
      [pubkey.length].pack('C') + pubkey
    end

    def serialize(witness: witness?)
      result = [VERSION].pack('V')
      result += [0x00, 0x01].pack('CC') if witness
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
      result += serialize_witness if witness
      result += [0].pack('V')
      result
    end

    def serialize_witness
      result = ''.b
      @inputs.each do |input|
        if input.segwit?
          result += varint(input.witness.length)
          input.witness.each do |item|
            result += varint(item.length)
            result += item.pack('C*')
          end
        else
          result += varint(0)
        end
      end
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
