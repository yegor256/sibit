<img src="/logo.png" width="64px"/>

[![EO principles respected here](http://www.elegantobjects.org/badge.svg)](http://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/C3RFVLU72.svg)](https://www.0crat.com/p/C3RFVLU72)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/sibit)](http://www.rultor.com/p/yegor256/sibit)
[![We recommend RubyMine](http://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/yegor256/sibit.svg)](https://travis-ci.org/yegor256/sibit)
[![Build status](https://ci.appveyor.com/api/projects/status/tbeaa0d4dk38xdb5?svg=true)](https://ci.appveyor.com/project/yegor256/sibit)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/sibit)](http://www.0pdd.com/p?name=yegor256/sibit)
[![Gem Version](https://badge.fury.io/rb/sibit.svg)](http://badge.fury.io/rb/sibit)
[![Maintainability](https://api.codeclimate.com/v1/badges/74c909f06d4afa0d8001/maintainability)](https://codeclimate.com/github/yegor256/sibit/maintainability)

[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/sibit.svg)](https://codecov.io/github/yegor256/sibit?branch=master)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/sibit)](https://hitsofcode.com/view/github/yegor256/sibit)

To understand how Bitcoin protocol works, I recommend you watching
this [short video](https://www.youtube.com/watch?v=IV9pRBq5A4g).

This is a simple Bitcoin client, to use from the command line
or from your Ruby app. You don't need to run any Bitcoin software,
no need to install anything, and so on. All you need is just a command line
and [Ruby](https://www.ruby-lang.org/en/) 2.3+. The purpose of this
client is to simplify most typical operations with Bitcoin. If you need
something more complex, I would recommend using
[bitcoin-ruby](https://github.com/lian/bitcoin-ruby) for Ruby and
[Electrum](https://electrum.org/) as a GUI client.

You may want to discuss this tool at [Bitcointalk](https://bitcointalk.org/index.php?topic=5130324)
and give this thread a few merits.

This is a Ruby gem, install it first (if doesn't work, there are
some hints at the bottom of this page):

```bash
$ gem install sibit
```

Then, you generate a [private key](https://en.bitcoin.it/wiki/Private_key):

```bash
$ sibit generate
E9873D79C6D87FC233AA332626A3A3FE
```

Next, you create a new [address](https://en.bitcoin.it/wiki/Address),
using your private key:

```
$ sibit create E9873D79C6D87FC233AA332626A3A3FE
1CC3X2gu58d6wXUWMffpuzN9JAfTUWu4Kj
```

To check the balance at the address (the result is in
[satoshi](https://en.bitcoin.it/wiki/Satoshi_%28unit%29)):

```
$ sibit balance 1CC3X2gu58d6wXUWMffpuzN9JAfTUWu4Kj
80988977
```

To send a payment from a few addresses to a new address:

```
$ sibit pay AMOUNT FEE A1:P1,A2:P2,... TARGET CHANGE
e87f138c9ebf5986151667719825c28458a28cc66f69fed4f1032a93b399fdf8
```

Here,
`AMOUNT` is the amount of [satoshi](https://en.bitcoin.it/wiki/Satoshi_%28unit%29) you are sending,
`FEE` is the [miner fee](https://en.bitcoin.it/wiki/Miner_fees) you are ready to spend to make this transaction delivered
(you can say `S`, `M`, `L`, or `XL` if you want it to be calculated automatically),
`A1:P1,A2:P2,...` is a comma-separated list of addresses `A` and private keys `P` you are sending your coins from,
`TARGET` is the address you are sending to,
`CHANGE` is the address where the change will be sent to.
The transaction hash will be returned.
Not all [UTXOs](https://en.wikipedia.org/wiki/Unspent_transaction_output)
will be used, but only the necessary amount of them.

All operations are performed through the
[Blockchain API](https://www.blockchain.com/api/blockchain_api).
Transactions are pushed to the Bitcoin network via
[this relay](https://www.blockchain.com/btc/pushtx).

## Ruby SDK

You can do the same from your Ruby app:

```ruby
require 'sibit'
sibit = Sibit.new
pkey = sibit.generate
address = sibit.create(pkey)
balance = sibit.balance(address)
target = sibit.create(pkey) # where to send coins to
change = sibit.create(pkey) # where the change will sent to
tx = sibit.pay(10_000_000, 'XL', { address => pkey }, target, change)
```

Should work.

## How to install

To install on a fresh Ubuntu 18:

```
$ sudo apt-get update
$ sudo apt-get install -y ruby ruby-dev autoconf automake build-essential
$ sudo gem update --system
$ gem install rake --no-document
$ gem install sibit
```

Should work. If it doesn't, submit an issue, I will try to help.

## How to contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have [Ruby](https://www.ruby-lang.org/en/) 2.3+ and
[Bundler](https://bundler.io/) installed. Then:

```
$ bundle update
$ bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.
