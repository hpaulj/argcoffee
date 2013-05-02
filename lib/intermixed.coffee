argparse = require('argcoffee')
{PARSER, REMAINDER} = argparse.Const
_ = require('underscore')
warn = (msg) ->
    console.log("WARNING", msg)

parse_intermixed_args = (self, args=null, namespace=null)->
    # self - argparse parser
    # args, namespace - as used by parse_known_args
    # returns a namespace and list of extras

    # positional can be freely intermixed with optionals
    # optionals are first parsed with all positional arguments deactivated
    # the 'extras' are then parsed
    # positionals 'deactivated' by setting nargs=0

    if self.usage is null
        # capture the full usage (could restore to null at end)
        self.usage = self.format_usage()[7..]
        console.log(self.usage)
    positionals = self._get_positional_actions()

    if _.any(action.nargs in [PARSER, REMAINDER] for action in positionals)
        self.error('PARSER or REMAINDER in positionals nargs; use parse_known_args')
        warn('PARSER or REMAINDER in positionals nargs; \n\tusing parse_known')
        # these nargs don't play nicely with intermixed
        # fall back on the default parsing
        return self.parse_known_args(args, namespace)

    if _.any((action.dest for action in group._group_actions when action in positionals) for group in self._mutually_exclusive_groups)
        self.error('positional in mutuallyExclusiveGroup; use parse_known_args')
        warn('positional in mutuallyExclusiveGroup; \n\tusing parse_known')
        # intermixed does not handle MXG with positionals well
        # fall back on the default parsing
        return self.parse_known_args(args, namespace)

    for action in positionals
        action.save_nargs = action.nargs
        action.nargs = 0
    try
        [namespace, remaining_args] = self.parse_known_args(args, namespace)
        for action in positionals
            if namespace[action.dest]?
                delete namespace[action.dest] # remove [] values from namespace
    catch error
        warn('error from 1st parse_known')
        throw error
    finally
        for action in positionals
            action.nargs = action.save_nargs
    warn("1st: #{""+namespace}, #{remaining_args}")
    # parse positionals
    # optionals aren't normally required, but just in case, turn that off
    optionals = self._get_optional_actions()
    for action in optionals
        action.save_required = action.required
        action.required = false
    for group in self._mutually_exclusive_groups
        group.save_required = group.required
        group.required = false
    try
        [namespace, extras] = self.parse_known_args(remaining_args, namespace)
    catch error
        throw error
    finally
        for action in optionals
            action.required = action.save_required
        for group in self._mutually_exclusive_groups
            group.required = group.save_required
    return [namespace, extras]

exports.parse_intermixed_args = parse_intermixed_args

#============================================
# Testing -
#============================================
TEST = not module.parent?
print = console.log
`function split(args) {
  // console.log(args)
  if (args.length===0) {return []};
  return args.split(' ');
}`
if TEST
  do() ->

    parserInt = argparse.newParser()
    parserInt.add_argument('--foo', {dest:'foo'})
    parserInt.add_argument('--bar', {dest:'bar'})
    parserInt.add_argument('cmd')
    parserInt.add_argument('rest', {nargs:'*'})

    trials = ['a b c d --foo x --bar 1',
              '--foo x a b c d --bar 1',
              '--foo x --bar 1 a b c d',
              'a b --foo x --bar 1 c d',
              'a --foo x b --bar 1 c d',
              'a --foo x b c --bar 1 d',
              'a --foo x b --bar 1 c --error d',
              'a --foo x b --error d --bar 1 c',
              'a b c',
              'a',
              '--foo 1', # error: the following arguments are required: cmd, rest
              '--foo',  # error: argument --foo: expected one argument
              '']
    for astr in trials then print(astr)

    print('')
    for astr in trials
        try
            [args, extras] = parse_intermixed_args(parserInt,split(astr))
            print args, extras
        catch error
            print('argv:', astr)
            print ""+error

    print('')
    print(parserInt.format_help())

    # =================
    print('behavior with REMAINDER') # TestNargsRemainder
    # REMAINDER acts after optionals have been processed
    # skip 2 step parse if there is a REMAINDER, so NS is same
    # alt is to raise error if there is a REMAINDER

    parserInt = argparse.newParser()
    parserInt.add_argument('-z')
    parserInt.add_argument('x')
    parserInt.add_argument('y', {nargs:'...'})

    try
        print(parse_intermixed_args(parserInt,split('X A B -z Z')))
    catch error
        print ""+error
        print(parserInt.parse_known_args(split('X A B -z Z')))

    # ================
    print('\nsubparsers case')
    # skip the 2 step
    p = argparse.newParser()
    sp = p.add_subparsers()
    spp = sp.add_parser('cmd')
    spp.add_argument('foo')
    print(p.format_help())
    try
        print(parse_intermixed_args(p,['cmd','1']))
    catch error
        print ""+error
        print(p.parse_known_args(['cmd','1']))

    # ====================
    print('\nrequired opts')
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
        print(parse_intermixed_args(p,[]))
        # warns only about -req_opt (in 1st parse step)
    catch error
        print ""+error

    # =================
    print '\nmutually exclusive case'
    parser = argparse.newParser()
    group = parser.add_mutually_exclusive_group({required:true})
    group.add_argument('--bar', {help:'bar help'})
    group.add_argument('--baz', {nargs:'?', constant:'Z', help:'baz help'})

    try
        print parse_intermixed_args(parser,split('--bar X'))
    catch error
        print ""+error
        print parser.parse_known_args(split('--bar X'))

    print('\nmutually exclusive case, both')
    # TestMutuallyExclusiveOptionalAndPositional
    parser = argparse.newParser()
    group = parser.add_mutually_exclusive_group({required:true})
    group.add_argument('--foo', {action:'storeTrue', help:'FOO'})
    group.add_argument('--spam', {help:'SPAM'})
    group.add_argument('badger', {nargs:'*', defaultValue:'X', help:'BADGER'})

    try
        print parse_intermixed_args(parser,[])
        # (Namespace(badger:'X', foo:False, spam:None), [])
        # switch to single parse_known to avoid this problem
    catch error
        print ""+error
    try
        print parser.parse_known_args([])
        # PROG: error: one of the arguments --foo --spam badger is required
    catch error
        print ""+error

    print parser.parse_known_args(split('--foo'))
    try
        print parse_intermixed_args(parser,split('--spam 1'))
    catch error
        print parser.parse_known_args(split('--spam 1'))
    # error: argument badger: not allowed with argument --foo
    # badger with nargs:0 matches 'nothing' in the 1st parse
    # switch to single parse_known to avoid this problem


"""
when parse_intermixed_args is used parse_args, test_argparse.py gives
errors in :
TestActionUserDefined

fail in:
TestMessageContentError
"""
