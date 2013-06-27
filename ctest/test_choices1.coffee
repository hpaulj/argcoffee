argparse = require('argcoffee')
_ = require('underscore')
if process.argv[1]=='p'
    argparse = require('argparse')

"""
issue 16878
* and ? use default, + does not
? - default value is None, return None
* - default value is None, return []  (empty list of arg_strings)
default is string - evaluate and convert with type
default is other - return as is (no evaluate)

how does this intersect with choices?

"""
print = console.log
if argparse.newParser?
   newParser = argparse.newParser
else
    newParser = ()->
        new argparse.ArgumentParser({debug:true})

foo = (options) ->
    parser = newParser()
    a=parser.addArgument(['foo'], options)
    print("\n", options)
    try
        print(parser.parseArgs())
    catch e
        print(e+"")
    try
        args = a.defaultValue
        if _.isArray(args)
            #
        else
            args = [args]
        print(parser.parseArgs(args))
    catch e
        print(e+"")

foo({nargs:"?"})                                          # None
foo({nargs:"?", defaultValue:['a','b']})                  # ['a','b'], err
foo({nargs:"?", defaultValue:'["a"]'})                    # '["a"]'
foo({nargs:"?", type:'int', defaultValue:[]})             # []
foo({nargs:"?", type:'int', defaultValue:'3'})            # 3
foo({nargs:"?", type:'int', defaultValue:[1,2,3]})        # [1,2,3], err

foo({nargs:"?", choices:'abc'})                           # None, err
foo({nargs:"?", choices:'abc',defaultValue:'a'})          # 'a'
foo({nargs:"?", choices:'abc',defaultValue:['a','a']})    # ['a','a'], err

foo({nargs:"*"})                                          # [], [None]
foo({nargs:"*", defaultValue:['a','b']})                  # ['a','b']
foo({nargs:"*", defaultValue:'["a"]'})                    # '["a"]', ['["a"]']
foo({nargs:"*", type:'int', defaultValue:[]})             # []
foo({nargs:"*", type:'int', defaultValue:'3'})            # '3', [3]
foo({nargs:"*", type:'int', defaultValue:['3','4']})      # ['3', '4'],[3, 4]

foo({nargs:"*", choices:'abc'})                           # [], err
# err in _check_value (in string}), with list or None
foo({nargs:"*", choices:'abc', defaultValue:['a','a']})   # (err),['a','a']
foo({nargs:"*", choices:'abc', defaultValue:'c'})         # 'c', ['c']
foo({nargs:"*", choices:'abc', defaultValue:[]})          # []
foo({nargs:"*", choices:'abc', defaultValue:false})       # [], (err)
foo({nargs:"*", choices:[true, false], defaultValue:false})       # false, [false]
foo({nargs:"*", choices:[true, false], defaultValue:[false]})     # [false], [false]
foo({nargs:"*", choices:[0...10], defaultValue:0})       # 0, [0]
foo({nargs:"*", choices:[0...10], defaultValue:[0]})       # [0], [0]
"""
msg191932 - (view)  Author: paul j3 (paul.j3) * Date: 2013-06-26 23:33
I've added 2 more tests,

one with default='c', which worked before.

one with default=['a','b'], which only works with this change.

http://bugs.python.org/issue16878 is useful reference, since it documents
the differences between nargs="?" and nargs="*", and their handling of
their defaults.
"""