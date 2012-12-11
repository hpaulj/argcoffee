#!usr/bin/env coffee
print = console.log
try
  argparse = require('../lib/argcoffee')
catch error
  argparse = require('argcoffee')

parseArgs = (fun) ->
  # convenience for repeated testing of parsing
  try
    args = parser.parseArgs()  # note cammelcase
    fun(args)
  catch error
    print  error

getDefault = (parser, dest) ->
  # corrected version of ActionContainer.getDefault
  result = parser._defaults[dest] ? null
  parser._actions.forEach((action) ->
    if (action.dest==dest && action.defaultValue != null)
      result = action.defaultValue
      return
  )
  return result


print 'default values test'
parser = new argparse.ArgumentParser({debug: true}) 
parser.addArgument(["square"], {
  help:"the base",
  type:"int"
  defaultValue: 0,
  nargs:'?'
  })
parser.addArgument(["power"], {
  help:"the exponent",
  type:"int"
  defaultValue: 2,
  nargs:'?'
  })
parser.addArgument(["-v","--verbosity"], {
  help:"increase output verbosity",
  action: "count",
  defaultValue: 0   # otherwise default is null
  })
  
parser.setDefaults({help:'testing'}) # test this

parser.printHelp()
parseArgs((args)->
  print 'defaults using parser.getDefault'
  print ("#{action.dest}: #{parser.getDefault(action.dest)}" for action in parser._actions)
  print 'defaults using custom getDefault'
  print ("#{action.dest}: #{getDefault(parser, action.dest)}" for action in parser._actions)


  if args.square is undefined
    print 'DEFAULT error'
  if args.verbosity is null
    print 'DEFAULT error'
  answer = Math.pow(args.square,args.power)
  print "verbosity: #{args.verbosity}"
  # in contrast to Python, 'null' verbosity does not mess up the comparison
  if args.verbosity>=2
    print "the #{args.power} power of #{args.square} equals #{answer}"
  else if args.verbosity==1
    print "#{args.square}^#{args.power}=#{answer}"
  else
    print answer 
  )
     
# possible bug - count with defaultValue:0, actually gives 'null'
# other defaultValues work as expected  
# defaultValue for 'square', 0, is also faulty, giving 'undefined'
# I suspect !! test on defaultValue
# action_container.js:144:    if (action.dest === dest && !!action.defaultValue) {
# action_container.js:191:    if (!!this._defaults[dest]) {
# 144 is in getDefault fn which noone calls (but available for user?)
# 191 is in addArgument, and is the critical one

# could also test ArgumentParser option argumentDefault, though this not commonly used
###
>>> parser = argparse.ArgumentParser(argument_default=argparse.SUPPRESS)
>>> parser.add_argument('--foo')
>>> parser.add_argument('bar', nargs='?')
>>> parser.parse_args(['--foo', '1', 'BAR'])
Namespace(bar='BAR', foo='1')
>>> parser.parse_args([])
Namespace()

###

