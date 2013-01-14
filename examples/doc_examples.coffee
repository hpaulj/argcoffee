# python 2.7 argparse doc examples
# coffeescript rendition
try
  argparse = require('../lib/argparse')
  console.log argparse
catch error
  argparse = require('argparse')  # from node_modules dir
  console.log  'via node_modules'

ArgumentParser = argparse.ArgumentParser

print = console.log
header = (arg) ->
    print '\n=== '+arg+' ==='
  
if not ArgumentParser.prototype.parse_args?
  header 'adding method aliases'
  ArgumentParser::add_argument =  (args..., options) ->
          # Python like arguments; 
          # options still needs to be specified, even if only {}
          @addArgument(args, options)
  ArgumentParser::parse_args = (args, namespace) ->
          @parseArgs(args, namespace)
  ArgumentParser::print_help = (args) ->
          @printHelp(args)
  ArgumentParser::add_subparsers = (args) ->
          @addSubparsers(args)
  ArgumentParser::parse_known_args = (args) ->
          @parseKnownArgs(args)


header 'intro with sum/max'
sum = (a,b) ->
    print 'sum stub'
max = (a,b) ->
    print 'max stub'

parser = new ArgumentParser({description:'Process some integers.'})
parser.add_argument('integers', {metavar:'N', type:'int', nargs:'+', \
                    help:'an integer for the accumulator'})
parser.add_argument('--sum', {dest:'accumulate', action:'storeConst', \
                    const:sum, defaultValue:max,
                    help:'sum the integers (default: find the max)'})
args = parser.parse_args(['--sum', '7', '-1', '42'])
print args
print args.accumulate(args)
parser.print_help()

header 'description'
parser = new ArgumentParser({description:'A foo that bars'})
parser.print_help()

header 'epilog'
parser = new ArgumentParser({
    description:'A foo that bars',
    epilog:"And that's how you'd foo a bar"})
parser.print_help()

header 'add help'
parser = new ArgumentParser()
parser.add_argument('--foo', {help:'foo help'})
args = parser.parse_args()

parser = new ArgumentParser({prog:'PROG', addHelp:false})
parser.add_argument('--foo', {help:'foo help'})
parser.print_help()


header 'prefix chars'
parser = new ArgumentParser({prog:'PROG', prefix_chars:'+/'})
parser.print_help()
#error '-h' must start with '+/'

parser = new ArgumentParser({prog:'PROG', prefix_chars:'-'})
parser.add_argument('-f',{})
parser.add_argument('--bar',{})
print parser.parse_args('-f X --bar Y'.split(' '))

parser = new ArgumentParser({prog:'PROG', prefix_chars:'-+'})
parser.add_argument('+f',{})
parser.add_argument('++bar',{})
#print parser.parse_args('+f X ++bar Y'.split(' '))

###
header 'fromfile prefix'
with open('args.txt', 'w') as fp:
   fp.write('-f\nbar')
parser = new ArgumentParser({fromfile_prefix_chars:'@'})
parser.add_argument('-f',{})
print parser.parse_args(['-f', 'foo', '@args.txt'])
###

header "argument default"
parser = new ArgumentParser({argument_default:argparse.SUPPRESS})
parser.add_argument('--foo',{})
parser.add_argument('bar', {nargs:'?'})
print parser.parse_args(['--foo', '1', 'BAR'])

print parser.parse_args([])

header 'parents'
parent_parser = new ArgumentParser({add_help:false})
parent_parser.add_argument('--parent', {type:'int'})

foo_parser = new ArgumentParser({parents:[parent_parser]})
foo_parser.add_argument('foo',{})
print foo_parser.parse_args(['--parent', '2', 'XXX'])


bar_parser = new ArgumentParser({parents:[parent_parser]})
bar_parser.add_argument('--bar',{})
print bar_parser.parse_args(['--bar', 'YYY'])

bar_parser.print_help()

header 'formater class'
parser = new ArgumentParser({
    prog:'PROG',
    description:'''this description
        was indented weird
            but that is okay''',
    epilog:'''
            likewise for this epilog whose whitespace will
        be cleaned up and whose words will be wrapped
        across a couple lines'''})
parser.print_help()

###
import textwrap
parser = new ArgumentParser({
    prog:'PROG',
    formatter_class:argparse.RawDescriptionHelpFormatter,
    description:textwrap.dedent('''\
        Please do not mess up this text!
        --------------------------------
            I have indented it
            exactly the way
            I want it
        '''}))
parser.print_help()
###
###
parser = new ArgumentParser({
    prog:'PROG',
    formatter_class:(new ArgumentDefaultsHelpFormatter)})
parser.add_argument('--foo', {type:'int', defaultValue:42, help:'FOO!'})
parser.add_argument('bar', {nargs:'*', defaultValue:[1, 2, 3], help:'BAR!'})
parser.print_help()
###

###
header 'conflict handler'
parser = new ArgumentParser({prog:'PROG', conflict_handler:'resolve'})
parser.add_argument('-f', '--foo', {help:'old foo help'})
parser.add_argument('--foo', {help:'new foo help'})
parser.print_help()
TypeError: argument "--foo": Conflicting option string(s): --foo
###

header 'prog'
parser = new ArgumentParser()
parser.add_argument('--foo', {help:'foo help'})
args = parser.parse_args()

parser = new ArgumentParser({prog:'myprogram'})
parser.print_help()

parser = new ArgumentParser({prog:'myprogram'})
parser.add_argument('--foo', {help:'foo of the %(prog)s program'})
parser.print_help()

parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('--foo', {nargs:'?', help:'foo help'})
parser.add_argument('bar', {nargs:'+', help:'bar help'})
parser.print_help()

header 'usage'
parser = new ArgumentParser({prog:'PROG', usage:'%(prog)s [options]'})
parser.add_argument('--foo', {nargs:'?', help:'foo help'})
parser.add_argument('bar', {nargs:'+', help:'bar help'})
parser.print_help()

header 'name or flags'
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('-f', '--foo',{})
parser.add_argument('bar',{})
print parser.parse_args(['BAR'])

print parser.parse_args(['BAR', '--foo', 'FOO'])
try
    print parser.parse_args(['--foo', 'FOO'])
catch error
    print error.message
    
header 'action'
parser = new ArgumentParser()
parser.add_argument('--foo',{})
print parser.parse_args('--foo 1'.split(' '))

parser = new ArgumentParser()
parser.add_argument('--foo', action:'storeConst', constant:42)
print parser.parse_args('--foo'.split(' '))

parser = new ArgumentParser()
parser.add_argument('--foo', {action:'storeTrue'})
parser.add_argument('--bar', {action:'storeFalse'})
print parser.parse_args('--foo --bar'.split(' '))

parser = new ArgumentParser()
parser.add_argument('--foo', {action:'append'})
print parser.parse_args('--foo 1 --foo 2'.split(' '))

parser = new ArgumentParser()
parser.add_argument('--str', {dest:'types', action:'appendConst', constant:'string'})
parser.add_argument('--int', {dest:'types', action:'appendConst', constant:'int'})
print parser.parse_args('--str --int'.split(' '))


parser = new ArgumentParser()
parser.add_argument('--verbose', '-v', {action:'count'})
print parser.parse_args('-v -v -v'.split(' '))
print parser.parse_args(['-vvv'])

###
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('--version', {action:'version', version:'%(prog)s 2.0'})
try
    print parser.parse_args(['--version'])
catch error
    print 'capture version exit'
# version exits; skip it until I can figure how to capture that  
###
###
class FooAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string:None):
        print('%r %r %r' % (namespace, values, option_string))
        setattr(namespace, self.dest, values)

parser = new ArgumentParser()
parser.add_argument('--foo', {action:FooAction})
parser.add_argument('bar', {action:FooAction})
print parser.parse_args('1 --foo 2'.split(' '))
###

header 'nargs'
parser = new ArgumentParser()
parser.add_argument('--foo', {nargs:2})
parser.add_argument('bar', {nargs:1})
print parser.parse_args('c --foo a b'.split(' '))


parser = new ArgumentParser()
parser.add_argument('--foo', {nargs:'?', constant:'c', defaultValue:'d'})
parser.add_argument('bar', {nargs:'?', defaultValue:'d'})
print parser.parse_args('XX --foo YY'.split(' '))

print parser.parse_args('XX --foo'.split(' '))

print parser.parse_args([])

if argparse.FileType?
    parser = new ArgumentParser()
    parser.add_argument('infile', {nargs:'?', type:argparse.FileType('r'),\
                    defaultValue:process.stdin})
    parser.add_argument('outfile', {nargs:'?', type:argparse.FileType('w'),\
                    defaultValue:process.stdout})
    #print parser.parse_args(['input.txt', 'output.txt'])
    print parser.parse_args([])


parser = new ArgumentParser()
parser.add_argument('--foo', {nargs:'*'})
parser.add_argument('--bar', {nargs:'*'})
parser.add_argument('baz', {nargs:'*'})
print parser.parse_args('a b --foo x y --bar 1 2'.split(' '))

parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('foo', {nargs:'+'})
print parser.parse_args('a b'.split(' '))

# print parser.parse_args([])

parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('--foo',{})
parser.add_argument('command',{})
parser.add_argument('args', {nargs:argparse.Const.REMAINDER})  # '...'
print(parser.parse_args('--foo B cmd --arg1 XX ZZ'.split(' ')))

header 'default'
parser = new ArgumentParser()
parser.add_argument('--foo', {defaultValue:42})
print parser.parse_args('--foo 2'.split(' '))

print parser.parse_args() #[])  [''] problematic

header 'type'
parser = new ArgumentParser()
parser.add_argument('--length', {defaultValue:'10', type:'int'})
parser.add_argument('--width', {defaultValue:10.5, type:'int'})
print parser.parse_args()

parser = new ArgumentParser()
parser.add_argument('foo', {nargs:'?', defaultValue:42})
print parser.parse_args('a'.split(' '))

print parser.parse_args()

parser = new ArgumentParser()
parser.add_argument('--foo', {defaultValue:argparse.Const.SUPPRESS})
print parser.parse_args([])

print parser.parse_args(['--foo', '1'])

###
parser = new ArgumentParser()
parser.add_argument('foo', {type:'int'})
parser.add_argument('bar', {type:open})
try
    print parser.parse_args('2 temp.txt'.split(' '))
catch error
    print 'temp.txt missing'
open not defined
###

if argparse.FileType?
    parser = new ArgumentParser()
    parser.add_argument('bar', {type:argparse.FileType('w')})
    print parser.parse_args(['out.txt'])
    # shows file handle, not file info

perfect_square = (string) ->
    value = parseInt(string)
    sqrt = Math.sqrt(value)
    if sqrt != Math.floor(sqrt)
        msg = "#{string} is not a perfect square"
        throw new TypeError(msg)
    return value

parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('foo', {type:perfect_square})
print parser.parse_args('9'.split(' '))
try
    print parser.parse_args('7'.split(' '))
catch error
    print error.message

header 'choices'
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('foo', {type:'int', choices:[5...10]})
print parser.parse_args('7'.split(' '))

try
    print parser.parse_args('11'.split(' '))
catch error
    print error.message
    
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('foo', {choices:'abc'})
print parser.parse_args('c'.split(' '))

try
    print parser.parse_args('X'.split(' '))
catch error
    print error.message

###
parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('foo', {type:complex, choices:[1, 1j]})
print parser.parse_args('1j'.split(' '))

try
    print parser.parse_args('-- -4'.split(' '))
catch error
    print error.message
###

header 'required'
parser = new ArgumentParser({debug:true})
parser.add_argument('--foo', {required:true})
print parser.parse_args(['--foo', 'BAR'])

try
    print parser.parse_args([])
catch error
    print error.message
    
header 'help'
parser = new ArgumentParser({prog:'frobble',debug:true})
parser.add_argument('--foo', {action:'storeTrue',\
        help:'foo the bars before frobbling'})
parser.add_argument('bar', {nargs:'+',\
        help:'one of the bars to be frobbled'})
# parser.parse_args('-h'.split(' '))  # tries to exti
parser.print_help()

parser = new ArgumentParser({prog:'frobble'})
parser.add_argument('bar', {nargs:'?', type:'int', defaultValue:42,\
        help:'the bar to %(prog)s (default: %(defaultValue)s)'})
parser.print_help()


parser = new ArgumentParser({prog:'frobble'})
parser.add_argument('--foo', {help:argparse.SUPPRESS})
parser.print_help()

header 'metavar'
parser = new ArgumentParser()
parser.add_argument('--foo',{})
parser.add_argument('bar',{})
print parser.parse_args('X --foo Y'.split(' '))

parser.print_help()


parser = new ArgumentParser()
parser.add_argument('--foo', {metavar:'YYY'})
parser.add_argument('bar', {metavar:'XXX'})
print parser.parse_args('X --foo Y'.split(' '))

parser.print_help()

parser = new ArgumentParser({prog:'PROG'})
# parser.add_argument('-x', {nargs:2})
parser.add_argument('-x', {nargs:2})
parser.add_argument('--foo', {nargs:2, metavar:['bar', 'baz']})
parser.print_help()

#16.4.3.11. dest
header 'dest'
parser = new ArgumentParser()
parser.add_argument('bar',{})
print parser.parse_args('XXX'.split(' '))


parser = new ArgumentParser()
parser.add_argument('-f', '--foo-bar', '--foo',{})
parser.add_argument('-x', '-y',{})
print parser.parse_args('-f 1 -x 2'.split(' '))

print parser.parse_args('--foo 1 -y 2'.split(' '))

parser = new ArgumentParser()
parser.add_argument('--foo', {dest:'bar'})
print parser.parse_args('--foo XXX'.split(' '))

#16.4.4. The parse_args() method
header 'Option value syntax'

parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('-x',{})
parser.add_argument('--foo',{})
print parser.parse_args('-x X'.split(' '))

print parser.parse_args('--foo FOO'.split(' '))


#print parser.parse_args('--foo:FOO'.split(' '))
# py splits on the :, cs does not


# print parser.parse_args('-xX'.split(' '))
# py splits off the X; cs does not


parser = new ArgumentParser({prog:'PROG'})
parser.add_argument('-x', {action:'storeTrue'})
parser.add_argument('-y', {action:'storeTrue'})
parser.add_argument('-z',{})
print parser.parse_args('-xyzZ'.split(' '))

header 'Invalid arguments'

parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('--foo', {type:'int'})
parser.add_argument('bar', {nargs:'?'})

# invalid type
try
    print parser.parse_args(['--foo', 'spam'])
catch error
    print error.message
header 'invalid option'
try
    print parser.parse_args(['--bar'])
catch error
    print error.message
# wrong number of arguments
try
    print parser.parse_args(['spam', 'badger'])
catch error
    print error.message
        
header 'args with -'
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('-x',{})
parser.add_argument('foo', {nargs:'?'})

# no negative number options, so -1 is a positional argument
print parser.parse_args(['-x', '-1'])


# no negative number options, so -1 and -5 are positional arguments
print parser.parse_args(['-x', '-1', '-5'])


parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('-1', {dest:'one'})
parser.add_argument('foo', {nargs:'?'})

# negative number options present, so -1 is an option
print parser.parse_args(['-1', 'X'])


# negative number options present, so -2 is an option
try
    print parser.parse_args(['-2'])
catch error
    print error.message


# negative number options present, so both -1s are options
try
    print parser.parse_args(['-1', '-1'])
catch error
    print error.message
    
print parser.parse_args(['--', '-f'])

header 'abreviations'
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('-bacon',{})
parser.add_argument('-badger',{})
#print parser.parse_args('-bac MMM'.split(' '))
#Error: PROG: error: unrecognized arguments -bac MMM

#print parser.parse_args('-bad WOOD'.split(' '))
#Error: PROG: error: unrecognized arguments -bad WOOD

try
    print parser.parse_args('-ba BA'.split(' '))
catch error
    print error.message


#16.4.4.5. Beyond sys.argv

parser = new ArgumentParser()
parser.add_argument(
    'integers', {metavar:'int', type:'int', choices:[0...10],\
    nargs:'+', help:'an integer in the range 0..9'})
parser.add_argument(\
    '--sum', {dest:'accumulate', action:'storeConst', constant:sum,\
    defaultValue:max, help:'sum the integers (default: find the max)'})
print parser.parse_args(['1', '2', '3', '4'])

print parser.parse_args('1 2 3 4 --sum'.split(' '))

header 'namespace obj'
parser = new ArgumentParser()
parser.add_argument('--foo',{})
args = parser.parse_args(['--foo', 'BAR'])
print args

c = new argparse.Namespace
parser = new ArgumentParser()
parser.add_argument('--foo',{})
print parser.parse_args(['--foo', 'BAR'], c)
c.foo

header 'subparsers'
# create the top-level parser
parser = new ArgumentParser({prog:'PROG',debug:true})
parser.add_argument('--foo', {action:'storeTrue', help:'foo help'})
subparsers = parser.add_subparsers({help:'sub-command help'})

# create the parser for the "a" command
parser_a = subparsers.addParser('a', {help:'a help'})
parser_a.add_argument('bar', {type:'int', help:'bar help'})

# create the parser for the "b" command
parser_b = subparsers.addParser('b', {help:'b help'})
parser_b.add_argument('--baz', {choices:'XYZ', help:'baz help'})

# parse some argument lists
# error not setting the subparser args
try
    print 'should be bar=12'
    print parser.parse_args(['a', '12'])
catch error
    print error.message

try
    print 'should be baz=Z, foo True'
    print parser.parse_args(['--foo', 'b', '--baz', 'Z'])
catch error
    print error.message
try
    #print parser.parse_args(['--help'])
    parser.print_help()
catch error
    print 'capture help exit'

"""
usage: PROG [-h] [--foo] {a,b} ...

positional arguments:
  {a,b}   sub-command help
    a     a help
    b     b help

optional arguments:
  -h, --help  show this help message and exit
  --foo   foo help
"""

    
parser_a.print_help()
# parser.parse_args(['a', '--help']) # equiv w/o the exit
parser_b.print_help()


parser = new ArgumentParser(description:'with subparsers')
subparsers = parser.add_subparsers({title:'subcommands',\
                                   description:'valid subcommands',\
                                   help:'additional help'})
subparsers.addParser('foo',{})
subparsers.addParser('bar',{})
parser.print_help()

header 'sub-command functions'
foo = (args) ->
    print "foo cmd: #{args.x}*#{args.y}=#{args.x * args.y}"
    'foo result'

bar = (args) ->
    print "var: ({args.z})"
    'bar return value'

# create the top-level parser
parser = new ArgumentParser({debug:true, description:'toplevel parser'})
subparsers = parser.add_subparsers()

# create the parser for the "foo" command
parser_foo = subparsers.addParser('foo')
parser_foo.add_argument('-x', {type:'int', defaultValue:1})
parser_foo.add_argument('y', {type:'float'})
parser_foo.set_defaults({func:foo})

# create the parser for the "bar" command
parser_bar = subparsers.addParser('bar')
parser_bar.add_argument('z',{})
parser_bar.set_defaults({func:bar})

try
    parser.print_help()
catch error
    print 'help error,',error
    
# parse the args and call whatever function was selected

  print 'should be foo func with y=1, x=2'
  print 'args: foo 1 -x 2'
  args = parser.parse_args('foo 1 -x 2'.split(' '))
  print args  # error: args is {}
  args.func(args)

try
    # parse the args and call whatever function was selected
    print 'should be bar func with arg z'
    args = parser.parse_args('bar XYZYX'.split(' '))
    print args
    args.func(args)
catch error
    print error.message
    
header 'subparser with dest'
parser = new ArgumentParser({debug:true})
subparsers = parser.add_subparsers({dest:'subparser_name'})
subparser1 = subparsers.addParser('1')
subparser1.add_argument('-x',{})
subparser2 = subparsers.addParser('2')
subparser2.add_argument('y',{})
try
    print 'should be subparser with dest with arg y'
    print parser.parse_args(['2', 'frobble'])
catch error
    print error.message
    
if argparse.FileType?
    print 'FileType objects'

    parser = new ArgumentParser()
    parser.add_argument('--output', type:argparse.FileType('w', 0))
    print parser.parse_args(['--output', 'out'])

    parser = new ArgumentParser()
    parser.add_argument('infile', {type:argparse.FileType('r')})
    print parser.parse_args(['-'])

header 'argument group'
parser = new ArgumentParser({prog:'PROG', addHelp:false})
group = parser.addArgumentGroup({title:'group'})
group.addArgument(['--foo'], {help:'foo help'})
group.addArgument(['bar'], {help:'bar help'})
parser.print_help()
# addArgGroup needs options obj


parser = new ArgumentParser({prog:'PROG', addHelp:false})
group1 = parser.addArgumentGroup({title:'group1', description:'group1 description'})
group1.addArgument(['foo'], {help:'foo help'})
group2 = parser.addArgumentGroup({title:'group2', description:'group2 description'})
group2.addArgument(['--bar'], {help:'bar help'})
parser.print_help()

if parser.addMutuallyExclusiveGroup?
  header 'mutual exclusion'
  parser = new ArgumentParser({prog:'PROG', debug: true})
  group = parser.addMutuallyExclusiveGroup()
  group.addArgument(['--foo'], {action:'storeTrue'})
  group.addArgument(['--bar'], {action:'storeFalse'})
  print parser.parseArgs(['--foo'])
  
  print parser.parseArgs(['--bar'])
  
  try
      print parser.parseArgs(['--foo', '--bar'])
  catch error
      print error
      print 'no allow both'
  
  parser = new ArgumentParser({prog:'PROG', debug: true})
  group = parser.addMutuallyExclusiveGroup({required:true})
  group.addArgument(['--foo'], {action:'storeTrue'})
  group.addArgument(['--bar'], {action:'storeFalse'})
  try
      print parser.parseArgs([])
  catch error
      print error
      print  'require one'
  

header 'parser defaults'
parser = new ArgumentParser()
parser.add_argument('foo', {type:'int'})
parser.set_defaults(bar:42, {baz:'badger'})
print parser.parse_args(['736'])

parser = new ArgumentParser()
parser.add_argument('--foo', {defaultValue:'bar'})
parser.set_defaults({foo:'spam'})
print parser.parse_args([])


parser = new ArgumentParser()
parser.add_argument('--foo', {defaultValue:'badger'})
parser.getDefault('foo')

header 'partial parsing'
parser = new ArgumentParser()
parser.add_argument('--foo', {action:'storeTrue'})
parser.add_argument('bar',{})
parser.parse_known_args(['--foo', '--badger', 'BAR', 'spam'])

header 'DONE'
