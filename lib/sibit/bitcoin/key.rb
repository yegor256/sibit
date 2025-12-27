# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require 'openssl'
require_relative 'base58'

module Sibit::Bitcoin
  # Bitcoin ECDSA key using secp256k1 curve.
  #
  # Supports OpenSSL 3.0+ by constructing keys via DER encoding instead
  # of using deprecated mutable key APIs.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
  class Key
    MIN_PRIV = 0x01
    MAX_PRIV = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140

    def self.generate
      key = OpenSSL::PKey::EC.generate('secp256k1')
      pvt = key.private_key.to_s(16).rjust(64, '0').downcase
      new(pvt)
    end

    def initialize(privkey)
      @privkey = privkey
      @compressed = true
      @key = build(privkey)
    end

    def priv
      @privkey
    end

    def pub
      point = @key.public_key
      point.to_octet_string(@compressed ? :compressed : :uncompressed).unpack1('H*')
    end

    def addr
      hash = hash160(pub)
      versioned = "00#{hash}"
      checksum = Base58.check(versioned)
      Base58.encode(versioned + checksum)
    end

    def sign(data)
      @key.sign('SHA256', data)
    end

    def verify(data, sig)
      @key.verify('SHA256', sig, data)
    rescue OpenSSL::PKey::PKeyError
      false
    end

    private

    def build(privkey)
      value = privkey.to_i(16)
      raise 'private key is not on curve' unless value.between?(MIN_PRIV, MAX_PRIV)
      group = OpenSSL::PKey::EC::Group.new('secp256k1')
      bn = OpenSSL::BN.new(privkey, 16)
      pubkey = group.generator.mul(bn)
      asn1 = OpenSSL::ASN1::Sequence(
        [
          OpenSSL::ASN1::Integer.new(1),
          OpenSSL::ASN1::OctetString(bn.to_s(2)),
          OpenSSL::ASN1::ObjectId('secp256k1', 0, :EXPLICIT),
          OpenSSL::ASN1::BitString(pubkey.to_octet_string(:uncompressed), 1, :EXPLICIT)
        ]
      )
      OpenSSL::PKey::EC.new(asn1.to_der)
    end

    def hash160(hex)
      bytes = [hex].pack('H*')
      Digest::RMD160.hexdigest(Digest::SHA256.digest(bytes))
    end
  end
end
