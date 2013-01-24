assert = require('assert')
plac = require('../lib/plac')
print = console.log

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

None = null

parser_from = (f, kw, dflt) ->
    if kw?
      f.__annotations__ = kw
    if dflt?
      f.defaults = dflt
    return plac.parser_from(f, {debug:true})
    
p1 = parser_from(((delete_, vargs) -> None),
                 {delete_:['delete a file', 'option']})
                 
console.log p1.format_help()

test_p1 = () ->
    console.log 'test p1'
    arg = p1.parse_args(['-d', 'foo', 'arg1', 'arg2'])
    console.log arg
    assert.equal(arg.delete_, 'foo')
    assert.deepEqual(arg.vargs, ['arg1', 'arg2'])

    arg = p1.parse_args([])
    console.log arg
    assert.equal(arg.delete, null)
    assert.deepEqual(arg.vargs, [])

p2 = parser_from(((arg1, delete_, vargs) -> null),
                 {delete_:['delete a file', 'option', 'd']})

test_p2 = () ->
    console.log 'test p2'
    arg = p2.parse_args(['-d', 'foo', 'arg1', 'arg2'])
    assert arg.delete_ == 'foo', arg.delete_
    assert arg.arg1 == 'arg1', arg.arg1
    console.log arg
    assert.deepEqual arg.vargs, ['arg2'], arg.vargs

    arg = p2.parse_args(['arg1'])
    console.log arg
    assert arg.delete_ is null, arg.delete_
    assert.deepEqual arg.vargs, [], arg.vargs
    assert arg, arg
    
    #console.log p2.parse_args([])
    expect(/too few arguments/, p2.parse_args, p2, [])

p3 = parser_from(((arg1, delete_) -> null),
                 {delete_:['delete a file', 'option', 'd']})

test_p3 = () ->
    console.log 'test p3'
    arg = p3.parse_args(['arg1'])
    assert arg.delete_ is null, arg.delete_
    assert arg.arg1 == 'arg1', arg.arg

    expect(/unrecognized arguments: arg2/, p3.parse_args, p3,['arg1', 'arg2'])
    expect(/too few arguments/, p3.parse_args, p3,[])

fnc4 = (delete_, delete_all, color)-> None
# fnc4.defaults = ["black"] # equiv to Python setting default on last args

p4 = parser_from(fnc4,
                 {delete_:['delete a file', 'option', 'd'],
                 delete_all:['delete all files', 'flag', 'a'],
                 color:['color', 'option', 'c']},
                 ["black"])
                 # color default "black"
# p4.set_defaults({color: "black"}) # alt way of setting default
console.log p4.format_help()

test_p4=()->
    console.log 'test p4'
    arg = p4.parse_args(['-a'])
    assert arg.delete_all is true, arg.delete_all

    arg = p4.parse_args([])
    console.log arg
    arg = p4.parse_args(['--color=black'])
    assert arg.color == 'black'

    arg = p4.parse_args(['--color=red'])
    assert arg.color == 'red'

p5 = parser_from(((dry_run)-> None), 
    {dry_run:['Dry run', 'flag', 'x']})
    # default is false
console.log p5.format_help()
test_p5 = ()->
    console.log 'test p5'
    arg = p5.parse_args(['--dry-run'])
    assert arg.dry_run is true,  arg.dry_run

test_p6 = () ->
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
    usage = parser.format_usage()
    assert usage.match(expected)?, usage

test_metavar_no_defaults=()->
    console.log 'test metavar no defaults'
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
    console.log 'test metavar with defaults'
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
    print 'test kwargs'
    main=(opt, arg1, vargs, varkw)->
        console.log 'main: ',[opt, arg1]
        return [vargs, varkw]
    main.__annotations__ = {opt:['Option', 'option']}
    p = parser_from(main)
    print p.format_help()
    print p.print_actions()
    #print (a.repr() for a in p._actions).join('\n')
    #print p.argspec
    print p.parse_known_args(['arg1', 'arg2', 'a=1', 'b=2'])
    argskw = plac.call(main, ['arg1', 'arg2', 'a=1', 'b=2'])
    assert.deepEqual(argskw, [['arg2'], {'a': '1', 'b': '2'}], argskw)
    print argskw
    
    argskw = plac.call(main, ['arg1', 'arg2', 'a=1', '-o', '2'])
    assert.deepEqual(argskw, [['arg2'], {'a': '1'}], argskw)
    print argskw

    p = parser_from(main)
    expect(/colliding keyword arguments/, p.consume, p, ['arg1', 'arg2', 'a=1', 'opt=2'] )
    
for test in [test_p1, test_p2, test_p3, test_p4, test_p5, test_p6, \
      test_metavar_no_defaults,test_metavar_with_defaults, test_kwargs]
  test()
