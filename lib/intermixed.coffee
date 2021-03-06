argparse = require('argcoffee')
{PARSER, REMAINDER, SUPPRESS} = argparse.Const
$$ = argparse.Const
{ArgumentParser} = argparse
{ArgumentError} = argparse
assert = require('assert')

_ = require('underscore')
warn = (msg) ->
    #console.log("WARNING", msg)

parse_intermixed_args = (args=null, namespace=null) ->
    [args, argv] = @parse_known_intermixed_args(args, namespace)
    if argv.length>0
        msg = "unrecognized arguments: #{argv.join(' ')}"
        @error(msg)
    return args

parse_known_intermixed_args = (args=null, namespace=null, _fallback=null)->
    # args, namespace - as used by parse_known_args
    # returns a namespace and list of extras

    # positional can be freely intermixed with optionals
    # optionals are first parsed with all positional arguments deactivated
    # the 'extras' are then parsed
    # positionals are 'deactivated' by setting nargs=0

    positionals = @_get_positional_actions()

    a =  (action for action in positionals when action.nargs in [$$.PARSER, $$.REMAINDER])
    if _.any(a)
        if _fallback?
            return _fallback(args, namespace)
        else
            a = a[0]
            err = new ArgumentError(a, "parse_intermixed_args: positional arg with nargs=#{a.nargs}")
            @error(err)

    a = (action.dest for action in group._group_actions when action in positionals \
            for group in @_mutually_exclusive_groups)
    a = _.flatten(a)
    if _.any(a)
        if _fallback?
            return _fallback(args, namespace)
        else
            @error('parse_intermixed_args: positional in mutuallyExclusiveGroup')

    save_usage = @usage
    try
        if @usage is null
            # capture the full usage for use in error messages
            @usage = @format_usage()[7..]

        for action in positionals
            action.save_nargs = action.nargs
            if true
                action.nargs = 0
            else
                # alt method of deactivating positionals
                action.nargs = $$.SUPPRESS
                action.save_default = action.defaultValue
                action.defaultValue = $$.SUPPRESS
        try
            args = @parse_known_args(args, namespace)
            namespace = args[0]
            remaining_args = args[1]
            for action in positionals
                if action.nargs == 0
                    delete namespace[action.dest] # remove [] values from namespace
                else
                    if namespace[action.dest]?
                        # don't expect such an element
                        warn("removing #{action.dest}=#{namespace[action.dest]}")
                        delete namespace[action.dest]
        finally
            for action in positionals
                action.nargs = action.save_nargs
                if true
                    action.defaultValue = action.save_default
        # parse positionals
        # optionals aren't normally required, but just in case, turn that off
        optionals = @_get_optional_actions()
        for action in optionals
            action.save_required = action.required
            action.required = false
        for group in @_mutually_exclusive_groups
            group.save_required = group.required
            group.required = false
        try
            [namespace, extras] = @parse_known_args(remaining_args, namespace)
        finally
            for action in optionals
                action.required = action.save_required
            for group in @_mutually_exclusive_groups
                group.required = group.save_required
    finally
        @usage = save_usage
    return [namespace, extras]

if not ArgumentParser:: parse_intermixed_args?
    ArgumentParser::parse_intermixed_args = parse_intermixed_args
    ArgumentParser::parse_known_intermixed_args = parse_known_intermixed_args

parse_fallback_args = (args=null, namespace=null) ->
    # use the fallback option
    fallback = (args...) =>
        warn('fallingback to parse_known_args')
        return @parse_known_args(args...)
    [args, argv] = @parse_known_intermixed_args(args, namespace, fallback)
    if argv.length>0
        msg = "unrecognized arguments: #{argv.join(' ')}"
        @error(msg)
    return args

parse_fallback_args = (args=null, namespace=null) ->
    # alternative, using error catching
    # this argparse has a debug option, so no need to define a different error method
    # just temporarily ensure that debug is set to true
    try
        save_debug = @debug
        @debug = true
        [args1, argv] = @parse_known_intermixed_args(args, namespace)
    catch error
        if error.message.search('parse_intermixed_args')>-1
            warn('fallbacking on parse_known_args')
            @debug = save_debug # assuming finally acts later
            [args1, argv] = @parse_known_args(args, namespace)
        else
            throw error
    finally
        @debug = save_debug
    if argv.length>0
        msg = "unrecognized arguments: #{argv.join(' ')}"
        @error(msg)
    return args1

parse_fallback_args = (args=null, namespace=null) ->
    # alternative, using error catching
    # this argparse has a debug option, so no need to define a different error method
    # just temporarily ensure that debug is set to true
    try
        [args1, argv] = @parse_known_intermixed_args(args, namespace)
    catch error
        if error instanceof TypeError
            warn('fallbacking on parse_known_args')
            [args1, argv] = @parse_known_args(args, namespace)
        else
            throw error
    if argv.length>0
        msg = "unrecognized arguments: #{argv.join(' ')}"
        @error(msg)
    return args1

ArgumentParser::parse_fallback_args = parse_fallback_args
exports.ArgumentParser = ArgumentParser

#============================================
# Testing -
#============================================
TEST = not module.parent?

print = console.log
split = require('underscore.string').words
header = (args...) -> console.log(args...);console.log('=============')

if TEST
  do() ->
    warn = (msg...) ->
        console.log("WARNING", msg...)

    parser = argparse.newParser()
    parser.add_argument('--foo', {dest:'foo', required:true})
    parser.add_argument('--bar', {dest:'bar'})
    parser.add_argument('cmd')
    parser.add_argument('rest', {nargs:'*', type:'int'})

    trials = ['cmd1 1 2 3 --foo x --bar y',
              '--foo x cmd1 1 2 3 --bar y',
              '--foo x --bar y cmd1 1 2 3',
              'cmd1 1 --foo x --bar y 2 3',
              'cmd1 --foo x 1 --bar y 2 3',
              'cmd1 --foo x 1 2 --bar y 3',
              'cmd1 --foo x 1 --bar y 2 --error 3',
              'cmd1 --foo x 1 --error 2 --bar y 3',
              'cmd1 1 2', #  the following argument(s) are required: --foo
              'cmd1',
              '--foo 1', # error: the following arguments are required: cmd, rest
              '--foo',  # error: argument --foo: expected one argument
              '']
    for astr in trials then print(astr)

    print('')
    for astr in trials
        print('')
        try
            args = parser.parse_fallback_args(split(astr))
            print args
            assert.deepEqual(args, { foo: 'x', bar: 'y', cmd: 'cmd1', rest: [ 1, 2, 3 ] })
        catch error
            print("argv: '#{astr}'")
            print ""+error
            print parser.format_usage()
            if (""+error).search('unrecognized')>-1
                print parser.parse_known_intermixed_args(split(astr))

    print('')
    print(parser.format_help())

    # =================
    header('behavior with REMAINDER') # TestNargsRemainder
    # REMAINDER acts after optionals have been processed
    # skip 2 step parse if there is a REMAINDER, so NS is same
    # alt is to raise error if there is a REMAINDER

    parser = argparse.newParser()
    parser.add_argument('-z')
    parser.add_argument('x')
    parser.add_argument('y', {nargs:'...'})

    argv = split('X A B -z Z'); print argv
    print parser.parse_known_args(argv)
    print parser.parse_fallback_args(argv)

    # ================
    header('\nsubparsers case')
    # skip the 2 step
    p = argparse.newParser();
    sp = p.add_subparsers()
    spp = sp.add_parser('cmd')
    spp.add_argument('foo')
    print(p.format_help())
    print(p.parse_fallback_args(['cmd','1']))

    # ====================
    header('\nrequired opts')
    # TestMessageContentError
    p = argparse.newParser()
    p.add_argument('req_pos')
    p.add_argument('-req_opt', {type: 'int', required:true})
    try
        print(p.parse_known_args([]))
        # warns about req_pos and -req_opt
    catch error
        print ""+error
    try
        print(p.parse_intermixed_args([]))
        # warns only about -req_opt (in 1st parse step)
    catch error
        print ""+error
    try
        print(p.parse_fallback_args([]))
    catch error
        print ""+error

    # =================
    header '\nmutually exclusive case'
    parser = argparse.newParser()
    group = parser.add_mutually_exclusive_group({required:true})
    group.add_argument('--bar', {help:'bar help'})
    group.add_argument('--baz', {nargs:'?', constant:'Z', help:'baz help'})

    print parser.parse_args(split('--bar X'))
    print parser.parse_intermixed_args(split('--bar X'))
    print parser.parse_fallback_args(split('--bar X'))

    header('\nmutually exclusive case, both')
    # TestMutuallyExclusiveOptionalAndPositional
    parser = argparse.newParser()
    group = parser.add_mutually_exclusive_group({required:true})
    group.add_argument('--foo', {action:'storeTrue', help:'FOO'})
    group.add_argument('--spam', {help:'SPAM'})
    group.add_argument('badger', {nargs:'*', defaultValue:'X', help:'BADGER'})

    try
        print parser.parse_intermixed_args([])
        # error: parse_intermixed_args: positional in mutuallyExclusiveGroup
    catch error
        print ""+error
    try
        print parser.parse_known_args([])
        # PROG: error: one of the arguments --foo --spam badger is required
    catch error
        print ""+error
    print parser.parse_fallback_args(split('--spam 1'))

