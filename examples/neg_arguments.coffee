#!/usr/bin/env coffee
print = console.log;
assert = require('assert')
"""
In the Python original, negative arguments are accepted
except when there is an option flag that looks like a negative number
e.g. '-1'
"""
test_attributes = (parser) ->
    print 'expect the 3 group attributes to be same'
    print 'parser:',parser._hasNegativeNumberOptionals
    print 'p._opt:',parser._optionals._hasNegativeNumberOptionals
    print 'p._pos:',parser._positionals._hasNegativeNumberOptionals
    assert.equal(parser._hasNegativeNumberOptionals,parser._optionals._hasNegativeNumberOptionals)
try
  ArgumentParser = require('./argcoffee').ArgumentParser
catch error
  ArgumentParser = require('../lib/argcoffee').ArgumentParser
parser = new ArgumentParser({
    debug: true,  # give error traceback
    description: 'Argparse example: negative arguments'
    })
parser.addArgument(['-x','--xxx'], {nargs: 1, help: '1 string argument'})
parser.addArgument(['-y','--yyy'], {nargs: 1, type: 'int', help: '1 integer argument'})
parser.addArgument(['int'], {nargs: '*', type: 'int', help: 'any number of integer arguments'})
parser.printHelp()
test_attributes(parser)
print  '-----------'

print  'no arguments'
print  parser.parseArgs([])
print ('-----------');
print  "xxx arg: #{argv = '-x 1'}"
print  parser.parseKnownArgs(argv.split(' '))
print ('-----------');
print  "xxx neg arg: #{argv = '-x -1'}"
print  parser.parseKnownArgs(argv.split(' '))
print ('-----------');
print  "xxx and yyy arg: #{argv = '-x 1 -y -1'}"
print  parser.parseKnownArgs(argv.split(' '))
print ('-----------');
print  "xxx and yyy arg: #{argv = '-x -1 -y -1 -1'}"
print  parser.parseKnownArgs(argv.split(' '))
print  'args: ', parser.parseArgs(argv.split(' '))
print  '-----------'

# test case when a neg number functions as an option
# should disable the potentially conflicting use of negative arguments
parser.description = "Add numeric option"
parser.addArgument(['-1','--one'], 
    {nargs: 0,  action:'storeConst', constant: true, defaultValue: false, \
        help: 'option that looks like negative argument'}) 
        
test_attributes(parser)
        
parser.printHelp()
print  '-----------'
print  "xxx arg: #{argv = '-x 1'}"
print  'knownArgs', parser.parseKnownArgs(argv.split(' '))
print ('-----------');
print  "xxx neg arg: #{argv = '-1 -2'}"
print  'knownArgs', parser.parseKnownArgs(argv.split(' '))  # returns extra arg
try
    print 'Expect: error: Unrecognized arguments: -2.'
    print  parser.parseArgs(argv.split(' '))  # should give error  
catch error
    print  error
    
# using the [] and [true] and _.any() version, parser and _positional values are set
# _positional is 'undefined' before the '-1' option is added, but that is ok
# so seems the [] is needed to pass values to other groups.  why?
# is that true of python as well?

