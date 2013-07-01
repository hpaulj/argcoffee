argparse = require('argcoffee')
_ = require('underscore')
assert = require('should')

if process.argv[2]=='p'
    argparse = require('argparse')
    process.argv.splice(2,)
    console.log(process.argv)

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

foo = (options, shoulds) ->
    parser = newParser({prog:"PROG"})
    a=parser.addArgument(['foo'], options)
    print("\n", options)
    print(parser.format_usage())
    try
        if shoulds?
            print(parser.parseArgs([]).should.eql({foo:shoulds[0]}))
        else
            print(parser.parseArgs([]))
    catch e
        print(e+"")
    try
        args = a.defaultValue
        if _.isArray(args)
            #
        else
            args = [""+args] # array of strings
        if shoulds? and shoulds[1]?
            print(parser.parseArgs(args).should.eql({foo:shoulds[1]}))
        else
            print(parser.parseArgs(args))
    catch e
        print(e+"")
    return parser

foo({nargs:"?"},[null])                                          # None
foo({nargs:"?", defaultValue:['a','b']},[['a','b']])                  # ['a','b'], err
foo({nargs:"?", defaultValue:'["a"]'})                    # '["a"]'
foo({nargs:"?", type:'int', defaultValue:[]})             # []
foo({nargs:"?", type:'int', defaultValue:'3'},[3,3])            # 3
foo({nargs:"?", type:'int', defaultValue:[1,2,3]},[[1,2,3]])        # [1,2,3], err

foo({nargs:"?", choices:'abc'})                           # None, err
foo({nargs:"?", choices:'abc',defaultValue:'a'})          # 'a'
foo({nargs:"?", choices:'abc',defaultValue:['a','a']})    # ['a','a'], err

foo({nargs:"*"})                                          # [], [None]
foo({nargs:"*", defaultValue:['a','b']})                  # ['a','b']
foo({nargs:"*", defaultValue:'["a"]'})                    # '["a"]', ['["a"]']
foo({nargs:"*", type:'int', defaultValue:[]})             # []
foo({nargs:"*", type:'int', defaultValue:'3'})            # '3', [3]
foo({nargs:"*", type:'int', defaultValue:['3','4']},[['3', '4'],[3, 4]])      # ['3', '4'],[3, 4]

foo({nargs:"*", choices:'abc'})                           # [], err
# err in _check_value (in string}), with list or None
foo({nargs:"*", choices:'abc', defaultValue:['a','a']})   # (err),['a','a']
foo({nargs:"*", choices:'abc', defaultValue:'c'})         # 'c', ['c']
foo({nargs:"*", choices:'abc', defaultValue:[]})          # []
foo({nargs:"*", choices:'abc', defaultValue:false})       # [], (err)
bool = (x) ->
    return if x in ['true','yes','1'] then true else false
foo({nargs:"*", type:bool, choices:[true, false], defaultValue: false})       # false, [false]
foo({nargs:"*", type:bool, choices:[true, false], defaultValue:[false]})     # [false], [false]
p = foo({nargs:"*", type:'int', choices:[0...10], defaultValue:0},[0,[0]])       # 0, [0]
print(p.parse_args('6 7 8 9'.split(' ')))
try
    print(p.parse_args('18'.split(' ')))
catch e
    print(e+"")
foo({nargs:"*", type:'int', choices:[0...10], defaultValue:[0]}, [[0]])       # [0], [0]

p=foo({nargs:"*", type:'int', choices:[0...10], defaultValue:[0], metavar:'range(0,10)'})       # [0], [0]
print(p.parse_args('6 7 8 9'.split(' ')))

try
    print(p.parse_args('18'.split(' ')))
catch e
    print(e+"")

should

"""
msg191932 - (view)  Author: paul j3 (paul.j3) * Date: 2013-06-26 23:33
I've added 2 more tests,

one with default='c', which worked before.

one with default=['a','b'], which only works with this change.

http://bugs.python.org/issue16878 is useful reference, since it documents
the differences between nargs="?" and nargs="*", and their handling of
their defaults.
"""