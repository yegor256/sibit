[![EO principles respected here](http://www.elegantobjects.org/badge.svg)](http://www.elegantobjects.org)
[![Managed by Zerocracy](https://www.0crat.com/badge/C3RFVLU72.svg)](https://www.0crat.com/p/C3RFVLU72)
[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/sibit)](http://www.rultor.com/p/yegor256/sibit)
[![We recommend RubyMine](http://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![Build Status](https://travis-ci.org/yegor256/sibit.svg)](https://travis-ci.org/yegor256/sibit)
[![Build status](https://ci.appveyor.com/api/projects/status/orvfo2qgmd1d7a2i?svg=true)](https://ci.appveyor.com/project/yegor256/sibit)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/sibit)](http://www.0pdd.com/p?name=yegor256/sibit)
[![Gem Version](https://badge.fury.io/rb/sibit.svg)](http://badge.fury.io/rb/sibit)
[![Maintainability](https://api.codeclimate.com/v1/badges/a3fee65d42a9cf6397ea/maintainability)](https://codeclimate.com/github/yegor256/sibit/maintainability)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/sibit.svg)](https://codecov.io/github/yegor256/sibit?branch=master)

To understand how Bitcoin protocol works, I recommend you watching
this [short video](https://www.youtube.com/watch?v=IV9pRBq5A4g).

This is a simple Bitcoin client, to use from command line
or from your Ruby app. You don't need to run any Bitcoin software,
no need to install anything, etc. All you need is just a command line
and [Ruby](https://www.ruby-lang.org/en/) 2.3+.

Install it first:

```bash
$ gem install sibit
```

Run it and read its output:

```bash
$ sibit --help
```

First, you generate a [private key](https://en.bitcoin.it/wiki/Private_key):

```bash
$ sibit generate
E9873D79C6D87FC233AA332626A3A3FE
```

Then, yoo create a new [address](https://en.bitcoin.it/wiki/Address),
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
$ sibit pay KEY AMOUNT FEE FROM1,FROM2,... TO
1CC3X2gu58d6wXUWjslPuzN9JAfTUWu4Kg
```

Here,
`KEY` is the private key,
`AMOUNT` is the amount of [satoshi](https://en.bitcoin.it/wiki/Satoshi_%28unit%29) you are sending,
`FEE` is the [miner fee](https://en.bitcoin.it/wiki/Miner_fees) you are ready to spend to make this transaction delivered
(you can say `S`, `M`, `L`, or `XL` if you want it to be calculated automatically),
`FROM1,FROM2,...` is a comma-separated list of addresses you are sending your coins from,
`TO` is the address you are sending to.
The address retured will contain the residual coins after the transaction is made.

## Ruby SDK

You can do the same from your Ruby app:

```ruby
sibit = Sibit.new
pkey = sibit.generate
address = sibit.create(pkey)
balance = sibit.balance(address)
out = sibit.pay(pkey, 10_000_000, 'XL', address, target)
```

Should work.

## How to contribute

Read [these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure you build is green before you contribute
your pull request. You will need to have [Ruby](https://www.ruby-lang.org/en/) 2.3+ and
[Bundler](https://bundler.io/) installed. Then:

```
$ bundle update
$ rake
```

If it's clean and you don't see any error messages, submit your pull request.

