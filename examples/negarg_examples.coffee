# examples of arguments with '-'  16.4.4.3
print = console.log
argparse = require('../lib/argcoffee')

parser = new argparse.ArgumentParser({prog:'PROG',debug:true})
parser.addArgument(['-x'], {dest:'x'})
parser.addArgument(['foo'], {nargs:'?'})
parser.printHelp()

# no negative number options, so -1 is a positional argument
print parser.parseArgs(['-x', '-1'])
print "python: Namespace(foo=None, x='-1')"

# no negative number options, so -1 and -5 are positional arguments
print parser.parseArgs(['-x', '-1', '-5'])
print "python: Namespace(foo='-5', x='-1')"
print "-----------------"
parser = new argparse.ArgumentParser({prog:'PROG',debug:true})
parser.addArgument(['-1'], {dest:'one'})
print ':',parser._hasNegativeNumberOptionals
print '_opt',parser._optionals._hasNegativeNumberOptionals
#print parser
parser.addArgument(['foo'], {nargs:'?'})
print 'par',parser._hasNegativeNumberOptionals
print '_opt',parser._optionals._hasNegativeNumberOptionals
print '_pos',parser._positionals._hasNegativeNumberOptionals
# true is preserved in _optionals
# but it isn't being copied to parser
# in python positional also gets true
# logic in action_container was fine; problem is in the agregating

# with [], and append(true), modifying parser._optionals._has... has the effect of modifying
# the value of parser and ._positional
# all point to the same array (same id in python)
print 'identical: ',parser._hasNegativeNumberOptionals == parser._optionals._hasNegativeNumberOptionals
# not identical with the true/false values, but yes with the [],[true] values
# _optionals, _positionals and subparsers are created as _ArgumentGroup
# its 'init' sets self._has... = container._has...; ie. a shared reference
# same for _registeries {}, _actions [], _option_string_actions [], _defaults {}
# all, if lists or dict, retain the shared ref as long as editing is done correctly

parser.printHelp()

# negative number options present, so -1 is an option
print parser.parseArgs(['-1', 'X'])
print "python: Namespace(foo=None, one='X')"

print '-- example'
print parser.parseArgs(['--', '-f'])
print "python: Namespace(foo='-f', one=None)"
print "---------------"

#print parser.parseArgs(['-1', 'X','-2'])
if 1
    print """python error msg: 
    \tusage: PROG [-h] [-1 ONE] [foo]
    \tPROG: error: no such option: -2
    """
    # negative number options present, so -2 is an option
    try
        print parser.parseArgs(['-2'])
    catch e
        print e
    # js is  producing { one: null, foo: '-2' } instead
print "---------------"
if 1
    print """python error msg:
\tusage: PROG [-h] [-1 ONE] [foo]
\tPROG: error: argument -1: expected one argument
"""
    # negative number options present, so both -1s are options
    try
        print parser.parseArgs(['-1', '-1'])
    catch error
        print error
