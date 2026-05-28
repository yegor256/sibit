# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require 'openssl'
require_relative 'base58'
require_relative 'bech32'
require_relative 'error'

# Sibit main class.
class Sibit
  # Bitcoin ECDSA key using secp256k1 curve.
  #
  # Supports OpenSSL 3.0+ by constructing keys via DER encoding instead
  # of using deprecated mutable key APIs.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Key
    MIN_PRIV = 0x01
    MAX_PRIV = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140

    SECP256K1_N = OpenSSL::BN.new(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', 16
    )

    attr_reader :network

    def self.generate(network: :mainnet)
      key = OpenSSL::PKey::EC.generate('secp256k1')
      pvt = key.private_key
      raise(Sibit::Error, 'Invalid private key: zero') if pvt.zero?
      raise(Sibit::Error, 'Invalid private key: out of range') if pvt >= SECP256K1_N
      raise(Sibit::Error, 'Invalid public key: not on curve') unless key.public_key.on_curve?
      hex = key.private_key.to_s(16).rjust(64, '0').downcase
      raise(Sibit::Error, 'Invalid private key encoding') unless hex.match?(/\A[0-9a-f]{64}\z/)
      unless OpenSSL::BN.new(hex, 16) == pvt
        raise(Sibit::Error, 'Private key serialization is lossy')
      end
      new(hex, network: network)
    end

    def initialize(privkey, network: nil)
      @override = network
      @network = :mainnet
      @compressed = true
      @privkey = decode(privkey)
      @key = build(@privkey)
    end

    def priv
      @privkey
    end

    def pub
      @key.public_key.to_octet_string(@compressed ? :compressed : :uncompressed).unpack1('H*')
    end

    def bech32
      hrp = { mainnet: 'bc', testnet: 'tb', regtest: 'bcrt' }[@network]
      hex = pub
      raise(Error, 'Invalid public key: not on curve') unless @key.public_key.on_curve?
      raise(Error, 'Invalid public key format') unless hex.match?(/\A0[23][0-9a-f]{64}\z/)
      addr = Bech32.encode(hrp, 0, hash160(hex))
      unless addr.match?(/\A#{hrp}1q[a-z0-9]{38,58}\z/)
        raise(Error, "Invalid bech32 address: #{addr}")
      end
      addr
    end

    def base58
      hex = pub
      raise(Error, 'Invalid public key: not on curve') unless @key.public_key.on_curve?
      raise(Error, 'Invalid public key format') unless hex.match?(/\A0[23][0-9a-f]{64}\z/)
      versioned = "#{@network == :mainnet ? '00' : '6f'}#{hash160(hex)}"
      addr = Base58.new(versioned + Base58.new(versioned).check).encode
      mainnet = /\A1[1-9A-HJ-NP-Za-km-z]{25,34}\z/
      testnet = /\A[mn][1-9A-HJ-NP-Za-km-z]{25,34}\z/
      unless addr.match?(@network == :mainnet ? mainnet : testnet)
        raise(Error, "Invalid base58 address: #{addr}")
      end
      addr
    end

    def sign(data)
      sig = @key.dsa_sign_asn1(data)
      raise(Error, 'Signature verification failed') unless verify(data, sig)
      sig
    end

    def verify(data, sig)
      @key.dsa_verify_asn1(data, sig)
    rescue OpenSSL::PKey::PKeyError
      false
    end

    private

    def build(privkey)
      raise(Error, 'Private key is not on curve') unless privkey.to_i(16).between?(
        MIN_PRIV,
        MAX_PRIV
      )
      bn = OpenSSL::BN.new(privkey, 16)
      OpenSSL::PKey::EC.new(
        OpenSSL::ASN1::Sequence(
          [
            OpenSSL::ASN1::Integer.new(1),
            OpenSSL::ASN1::OctetString(bn.to_s(2)),
            OpenSSL::ASN1::ObjectId('secp256k1', 0, :EXPLICIT),
            OpenSSL::ASN1::BitString(
              OpenSSL::PKey::EC::Group.new('secp256k1').generator.mul(bn)
                .to_octet_string(:uncompressed),
              1, :EXPLICIT
            )
          ]
        ).to_der
      )
    end

    def hash160(hex)
      Digest::RMD160.hexdigest(Digest::SHA256.digest([hex].pack('H*')))
    end

    def decode(key)
      if key.length == 64 && key.match?(/\A[0-9a-f]+\z/i)
        @network = @override || :mainnet
        return key.downcase
      end
      raw = Base58.new(key).decode
      raise(Error, 'Invalid WIF checksum') unless raw[-8..] == Base58.new(raw[0..-9]).check
      version = raw[0, 2]
      raise(Error, "Invalid WIF version: #{version}") unless %w[80 ef].include?(version)
      detected = version == '80' ? :mainnet : :testnet
      @network = @override || detected
      body = raw[2..-9]
      @compressed = body.length == 66 && body.end_with?('01')
      @compressed ? body[0, 64] : body
    end
  end
end
