argparse = require('argcoffee')
ArgumentParser = argparse.ArgumentParser
Namespace = argparse.Namespace
NS = Namespace
assert = require('assert')

_ = require('underscore')
_.str = require('underscore.string')

camelize = (obj) ->
  # camelize the keys of an object (e.g. parser arguments)
  for key of obj
    obj[_.str.camelize(key)] = obj[key]
  obj

# class Sig
#    def __init__(self, *args, **kwargs):
#        self.args = args
#        self.kwargs = kwargs
# in effect object with a number of 'positional' args and then some keyword args
# in JS argparse this was implemented as fn with a list arg and obj arg, ([],{})


psplit = (astring) ->
  # split that is closer the python split()
  # psplit('') produces [], not ['']
  if astring.split?
    result = astring.split(' ')
    result = (r for r in result when r) # remove ''
    return result
  return astring # probably is a list already
  
###
class NS(object):

    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)

    def __repr__(self):
        sorted_items = sorted(self.__dict__.items())
        kwarg_str = ', '.join(['%s=%r' % tup for tup in sorted_items])
        return '%s(%s)' % (type(self).__name__, kwarg_str)

    __hash__ = None

    def __eq__(self, other):
        return vars(self) == vars(other)

    def __ne__(self, other):
        return not (self == other)
###

# NS - namespace, obj that can take keyword initial args
# has some sort of repr, and can test against others

# argument_signatures is list of 1 or more Sig(); these look like add_argument arguments

###
pycode = '''
class TestOptionalsShortLong(ParserTestCase):
    """Test a combination of single- and double-dash option strings"""

    argument_signatures = [
        Sig('-v', '--verbose', '-n', '--noisy', action='store_true'),
    ]
    failures = ['--x --verbose', '-N', 'a', '-v x']
    successes = [
        ('', NS(verbose=False)),
        ('-v', NS(verbose=True)),
        ('--verbose', NS(verbose=True)),
        ('-n', NS(verbose=True)),
        ('--noisy', NS(verbose=True)),
    ]
'''
console.log pycode
###
###
   argument_signatures = [
        Sig('-x', action='store_true'),
        Sig('-yyy', action='store_const', const=42),
        Sig('-z'),
    ]
    failures = ['a', '--foo', '-xa', '-x --foo', '-x -z', '-z -x',
                '-yx', '-yz a', '-yyyx', '-yyyza', '-xyza']
    successes = [
        ('', NS(x=False, yyy=None, z=None)),
        ('-x', NS(x=True, yyy=None, z=None)),
        ('-za', NS(x=False, yyy=None, z='a')),
        ('-z a', NS(x=False, yyy=None, z='a')),
        ('-xza', NS(x=True, yyy=None, z='a')),
        ('-xz a', NS(x=True, yyy=None, z='a')),
        ('-x -za', NS(x=True, yyy=None, z='a')),
        ('-x -z a', NS(x=True, yyy=None, z='a')),
        ('-y', NS(x=False, yyy=42, z=None)),
        ('-yyy', NS(x=False, yyy=42, z=None)),
        ('-x -yyy -za', NS(x=True, yyy=42, z='a')),
        ('-x -yyy -z a', NS(x=True, yyy=42, z='a')),
    ]

# 3 add_argument
# number of parse_args args that should produce failure
# number of parse_args args that produce success, and expected namespace

# so expected testing is:
# construct a parser with the 3 arguments
# loop over the failure cases, with a try or assert_throws 'guard'
# loop over the success cases, comparing result with the NS

# tasks: convert Sig() to JS ([],{})
# looping on failures list should be straight forward
# successes, list of tuples, each tuple is a parse_args string (to split)
# and NS; need to convert NS to JS obj
# current Namespace does not take an obj constructor; e.g.
# for now is just new Namespace(); not new Namespace({x:1, yyy:3})
# JS syntax does not allow for Namespace(x:1, yyy:3)


parser = new ArgumentParser({debug:true})
parser.add_argument('-v', '--verbose', '-n', '--noisy', {action:'storeTrue'})
# or parser.addArgument(['-v', '--verbose', '-n', '--noisy'], {action:'storeTrue'})
# deduced dest is 'verbose'

failures = ['--x --verbose', '-N', 'a', '-v x']
console.log 'failures', failures
for testcase in failures
  
  try
    args = parser.parse_args(testcase.split(' '))
  catch error
    console.log "[#{testcase}]", error.message
    
  assert.throws(
    () -> 
      args = parser.parse_args(psplit(testcase))
    ,/unrecognized arguments/i)

successes = [
        ['', {verbose:false}],
        ['-v', {verbose:true}],
        ['--verbose', {verbose:true}],
        ['-n', {verbose:true}],
        ['--noisy', {verbose:true}],
    ]
console.log 'successes', successes
for testcase in successes
  [argv, ns] = testcase
  argv = psplit(argv)
  args = parser.parse_args(argv)
  console.log 'expect:',ns,'got',args
  assert.deepEqual(ns,args)

in python

p=ArgumentParser()
p.add_argument(*argument_signatures[0].args,**argument_signatures[0].kwargs)
args=p.parse_args(successes[1][0].split(' '))
successes[1][1]==args
py does not like ''.split(' ')=[''] any more than js
for argv, ns in successes[1:]:
    print ns==p.parse_args(argv.split(' '))
    
###

#fromPy = '{"successes": [["", {"x": false, "z": null, "yyy": null}], ["-x", {"x": true, "z": null, "yyy": null}], ["-za", {"x": false, "z": "a", "yyy": null}], ["-z a", {"x": false, "z": "a", "yyy": null}], ["-xza", {"x": true, "z": "a", "yyy": null}], ["-xz a", {"x": true, "z": "a", "yyy": null}], ["-x -za", {"x": true, "z": "a", "yyy": null}], ["-x -z a", {"x": true, "z": "a", "yyy": null}], ["-y", {"x": false, "z": null, "yyy": 42}], ["-yyy", {"x": false, "z": null, "yyy": 42}], ["-x -yyy -za", {"x": true, "z": "a", "yyy": 42}], ["-x -yyy -z a", {"x": true, "z": "a", "yyy": 42}]], "doc": "Test an Optional with a single-dash option string", "argument_signatures": [[["-x"], {"action": "store_true"}], [["-yyy"], {"action": "store_const", "const": 42}], [["-z"], {}]], "name": "TestOptionalsSingleDashCombined", "failures": ["a", "--foo", "-xa", "-x --foo", "-x -z", "-z -x", "-yx", "-yz a", "-yyyx", "-yyyza", "-xyza"]}
#console.log fromPy
#obj = JSON.parse(fromPy)
objlist = require('./testpy') # if written to file
console.log objlist.length, 'test cases'
#console.log objlist

casecnt = 0
for obj in objlist
  # each of these should be separate test
  casecnt += 1
  console.log '\n', casecnt, "====================="
  console.log obj.name
  if obj.parser_signature?
    options = obj.parser_signature[1]
    options = camelize(options)
    console.log 'camelized:', options
  else
    options = {}
  options.debug = true
  options.prog = obj.name
  options.description = obj.doc
  parser = new ArgumentParser(options)
  for sig in obj.argument_signatures
    parser.addArgument(sig[0], sig[1])
  
  cnt = 0
  for testcase in obj.successes
    [argv, ns] = testcase
    argv = psplit(argv)
    args = parser.parse_args(argv)
    console.log 'expected:',ns,'got',args
    try
      assert.deepEqual(ns,args)
    catch error
      console.log error
    cnt += 1
  console.log "success tests: #{cnt} of #{obj.successes.length}"
  cnt = 0
  for testcase in obj.failures
    try
      args = parser.parse_args(psplit(testcase))
      console.log 'OOPS, no error', testcase
      cnt -= 1
    catch error
      console.log "[#{testcase}]", error.message
    ###
    assert.throws(
      () -> 
        args = parser.parse_args(psplit(testcase))
    ) # expected error not specified in py orginal
    ###
    cnt += 1
  console.log "failure tests: #{cnt} of #{obj.failures.length}"

# I added synms to container registry for storeTrue etc.

