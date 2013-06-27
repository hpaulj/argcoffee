# test for choices with nargs

argparse = require('argcoffee')
#argparse = require('argparse')
should = require('should')

parser = new argparse.ArgumentParser({debug: true})
choices = 'abc'
#choices = ['a','b','c']

try
  parser.addArgument(['foo'], {nargs: "*", choices: choices})
  #console.log parser.formatHelp()
  console.log (parser.parseArgs(['a'])).should.eql({foo: ['a']})
  console.log (parser.parseArgs(['a','b'])).should.eql({foo: ['a','b']})
  console.log (parser.parseArgs([])).should.eql({foo: []})
catch e
  console.log e.message

#(parser.parseArgs([])).should.eql({foo: []})

try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: ['a']})
  #console.log parser.formatHelp()
  console.log (parser.parseArgs([])).should.eql({foo: ['a']})
catch e
  console.log e.message


try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: 'a'})
  #console.log parser.formatHelp()
  console.log (parser.parseArgs([])).should.eql({foo: 'a'})
catch e
  console.log e.message


try
  parser = new argparse.ArgumentParser({debug: true})
  a = parser.addArgument(['foo'], {nargs: "*", defaultValue: 'a b c'})
  console.log (parser.parseArgs([])).should.eql({foo: a.defaultValue})
catch e
  console.log e.message


try
  parser = new argparse.ArgumentParser({debug: true})
  a = parser.addArgument(['foo'], {nargs: "*", type: 'int', defaultValue: 1})
  console.log (parser.parseArgs([])).should.eql({foo: a.defaultValue})
catch e
  console.log e.message



try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: ['abc']})
  #console.log parser.formatHelp()
  console.log (parser.parseArgs([])).should.eql({foo: ['abc']})
catch e
  console.log e.message


"""
try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: '["a"]'})
  console.log (parser.parseArgs([])).should.eql({foo: ['a']})
catch e
  console.log e.message
"""

try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: ['a','a']})
  console.log (parser.parseArgs([])).should.eql({foo: ['a','a']})
catch e
  console.log e.message

"""
try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "*", choices: choices, defaultValue: "['a','a']"})
  console.log (parser.parseArgs([])).should.eql({foo: ['a','a']})
catch e
  console.log e.message
"""

try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs:"?", choices: choices})
  console.log (parser.parseArgs([])).should.eql({foo: null})
catch e
  console.log e.message


try
  parser = new argparse.ArgumentParser({debug: true})
  parser.addArgument(['foo'], {nargs: "+", choices: choices})
  console.log (parser.parseArgs(['a'])).should.eql({foo: ['a']})
catch e
  console.log e.message


