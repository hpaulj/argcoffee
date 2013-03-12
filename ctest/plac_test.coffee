assert = require('assert')
plac = require('../lib/plac')
print = console.log
header = (args...) -> print '\n===>', args

expect = (errpat, func, vargs...) ->
    try
        # func(vargs...)
        arg = func.call(vargs...)
        # having problems with binding the parser
        console.log arg
    catch error
        if (m = error.message.match(errpat))
          console.log "got expected error: '#{errpat}' with #{vargs}"
        else
          console.log error

expectc = (errpat, func, obj, args) ->
    try
        # func(vargs...)
        arg = func(obj, args, {debug:true})
        # having problems with binding the parser
        console.log arg
    catch error
        if (m = error.message.match(errpat))
          console.log "got expected error: '#{errpat}' with #{args}"
        else
          console.log 'UNEXPECTED ERROR'
          console.log error

None = null

parser_from = (f, kw, dflt) ->
    if kw?
      f.__annotations__ = kw
    if dflt?
      f.defaults = dflt
    return plac.parser_from(f, {debug:true})

p1 = parser_from(((delete1, vargs) -> null),
                 {delete1:['delete a file', 'option']})

print 'p1'
print p1.formatHelp()

test_p1 = () ->
    header 'test p1'
    arg = p1.parseArgs(['-d', 'foo', 'arg1', 'arg2'])
    console.log arg
    assert.equal(arg.delete1, 'foo')
    assert.deepEqual(arg.vargs, ['arg1', 'arg2'])

    arg = p1.parseArgs([])
    console.log arg
    assert.equal(arg.delete1, null)
    assert.deepEqual(arg.vargs, [])

p2 = parser_from(((arg1, delete1, vargs) -> null),
                 {delete1:['delete a file', 'option', 'd']})

test_p2 = () ->
    header 'test p2'
    arg = p2.parseArgs(['-d', 'foo', 'arg1', 'arg2'])
    assert arg.delete1 == 'foo', arg.delete1
    assert arg.arg1 == 'arg1', arg.arg1
    console.log arg
    assert.deepEqual arg.vargs, ['arg2'], arg.vargs

    arg = p2.parseArgs(['arg1'])
    console.log arg
    assert arg.delete1 is null, arg.delete1
    assert.deepEqual arg.vargs, [], arg.vargs
    assert arg, arg

    #console.log p2.parseArgs([])
    expect(/too few arguments/, p2.parseArgs, p2, [])

p3 = parser_from(((arg1, delete1) -> null),
                 {delete1:['delete a file', 'option', 'd']})

test_p3 = () ->
    header 'test p3'
    arg = p3.parseArgs(['arg1'])
    assert arg.delete1 is null, arg.delete1
    assert arg.arg1 == 'arg1', arg.arg

    expect(/unrecognized arguments: arg2/, p3.parseArgs, p3,['arg1', 'arg2'])
    expect(/too few arguments/, p3.parseArgs, p3,[])

fnc4 = (delete1, delete_all, color)-> None
# fnc4.defaults = ["black"] # equiv to Python setting default on last args

p4 = parser_from(fnc4,
                 {delete1:['delete a file', 'option', 'd'],
                 delete_all:['delete all files', 'flag', 'a'],
                 color:['color', 'option', 'c']},
                 ["black"])
                 # color default "black"
# p4.set_defaults({color: "black"}) # alt way of setting default
console.log p4.formatHelp()

test_p4=()->
    header 'test p4'
    arg = p4.parseArgs(['-a'])
    assert arg.delete_all is true, arg.delete_all

    arg = p4.parseArgs([])
    console.log arg
    arg = p4.parseArgs(['--color=black'])
    assert arg.color == 'black'

    arg = p4.parseArgs(['--color=red'])
    assert arg.color == 'red'

p5 = parser_from(((dry_run)-> None),
    {dry_run:['Dry run', 'flag', 'x']})
    # default is false
console.log p5.formatHelp()
test_p5 = ()->
    header 'test p5'
    arg = p5.parseArgs(['--dry-run'])
    assert arg.dry_run is true,  arg.dry_run

test_p6 = () ->
  header 'test p6'
  errpat = /Flag yes_or_no wants default false, got no/
  fnc6 = (yes_or_no) -> None
  # fnc6.defaults = ['no']
  try
    p6 = parser_from(fnc6,
      {yes_or_no: ['A yes/no flag', 'flag', 'f']},['no'])
  catch error
    if (m = error.message.match(errpat))
      console.log "got expected error: '#{errpat}'"
    else
      console.log error

assert_usage = (parser, expected) ->
    usage = parser.formatUsage()
    assert usage.match(expected)?, usage

test_metavar_no_defaults=()->
    header 'test metavar no defaults'
    # positional
    p = parser_from(((x)->None),
                   {x:['first argument', 'positional', null, 'int', [], 'METAVAR']})

    assert_usage(p, /\[-h\] METAVAR/)
    # assert_usage(p, 'usage: test_plac.py [-h] METAVAR\n')

    # option
    p = parser_from(((y)->None),
                    {y:['first argument', 'option', null, null, [], 'METAVAR']})
    assert_usage(p, /\[-h\] \[-y METAVAR\]/)
    #assert_usage(p, 'usage: test_plac.py [-h] [-y METAVAR]\n')

    # have to chg the fn so registry doesn't find the old
    #

test_metavar_with_defaults = () ->
    header 'test metavar with defaults'
    # positional
    p = parser_from(((x)->None),
                   {x:['first argument', 'positional', null, 'string', [], 'METAVAR']},
                   ['a'])
    #console.log p._actions
    #console.log p.obj
    assert_usage(p, /usage: .* \[-h\] \[METAVAR\]/)
    # assert_usage(p, 'usage: test_plac.py [-h] [METAVAR]\n')

    # option
    p = parser_from(((x)->None),
                   {x:['first argument', 'option', null, 'string', [], 'METAVAR']},['a'])
    assert_usage(p, /usage: .* \[-h\] \[-x METAVAR\]/)
    # assert_usage(p, 'usage: test_plac.py [-h] [-x METAVAR]\n')

    p = parser_from(((x)->None),
                   {x:['first argument', 'option', null, null, [], null]},['a'])
    console.log p.parseArgs([])
    # plac sets metavar to defaultValue
    assert_usage(p, /usage: .* \[-h\] \[-x a\]/)
    #assert_usage(p, 'usage: test_plac.py [-h] [-x a]\n')

test_kwargs=()->
    header 'test kwargs'
    main=(opt, arg1, vargs, varkw)->
        console.log 'main: ',[opt, arg1]
        return [vargs, varkw]
    main.__annotations__ = {opt:['Option', 'option']}
    p = parser_from(main)
    print p.formatHelp()
    try
      print p.print_actions()
      # depends on an add actions method
    #print (a.repr() for a in p._actions).join('\n')
    #print p.argspec
    print p.parseKnownArgs(['arg1', 'arg2', 'a=1', 'b=2'])
    argskw = plac.call(main, ['arg1', 'arg2', 'a=1', 'b=2'])
    assert.deepEqual(argskw, [['arg2'], {'a': '1', 'b': '2'}], argskw)
    print argskw

    argskw = plac.call(main, ['arg1', 'arg2', 'a=1', '-o', '2'])
    assert.deepEqual(argskw, [['arg2'], {'a': '1'}], argskw)
    print argskw

    expectc(/colliding keyword arguments/, plac.call, main, ['arg1', 'arg2', 'a=1', 'opt=2'] )

cmds = {
    add_help: false
    commands: ['help', 'commit']
    help: (name) ->
        ### help command ###
        return ['help:', name]
    commit: () ->
        ### commit command ###
        return 'commit'
    }

test_cmds = () ->
    header 'test cmds'
    assert 'commit' == plac.call(cmds, ['commit'],{debug:true})
    assert.deepEqual(['help:', 'foo'], plac.call(cmds, ['help', 'foo']))
    expectc(/too few arguments/, plac.call, cmds, [])

test_cmd_abbrevs=() ->
    header 'test cmd abbrevs'
    assert 'commit' == plac.call(cmds, ['comm'])
    assert.deepEqual(['help:', 'foo'], plac.call(cmds, ['h', 'foo']))
    expectc(/No command foo/, plac.call, cmds, ['foo'])

test_sub_help=()->
    header 'test sub help'
    c = cmds
    c.add_help = true
    expectc(/Exit captured/, plac.call, c, ['commit', '-h'])

log_cmds=()->
  parser = parser_from(cmds, {'name': ['commit name help','positional']})
  console.log(parser.formatHelp());
  console.log parser.subparsers._name_parser_map['help'].formatHelp()
  console.log 'help foo:', parser.consume(['help','foo'])
  console.log plac.call(cmds, ['help','foo'])
  console.log 'commit:', parser.consume(['commit'])

# other tests in test_plac.py are not applicable
# yield, script, batch etc

# is there a way of this module to get this list of test_ fns?

for test in [test_p1, test_p2, test_p3, test_p4, test_p5, test_p6, \
      test_metavar_no_defaults,test_metavar_with_defaults, test_kwargs, \
      test_cmds,test_sub_help,test_cmd_abbrevs]
  try
    test()
  catch error
    print "TODO test error"
    print error

