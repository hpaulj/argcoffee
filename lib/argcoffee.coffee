###
 * class ArgumentParser
 *
 * Object for parsing command line strings into js objects.
 *
 * Inherited from [[ActionContainer]]
###
# TODO - add conflict handler from argparse
# integrate ArgumentError

util = require('util')

if not module.parent? and (!process.argv[2]? or process.argv[2]!='nodebug')
    DEBUG = (arg...) ->
      arg.unshift('==> ')
      console.log arg...

    #DEBUG = (arg...) -> util.debug(arg)
    # how is util.debug diff from console.log?
else
    DEBUG = () ->

assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

# Zip together multiple lists into a single array -- elements that share
# an index go together.
_.zipShortest = ->
  length =  _.min _.pluck arguments, 'length'
  results = new Array length
  for i in [0...length]
    results[i] = _.pluck arguments, String i
  results

$$ = require('./const')

_ActionsContainer = require('./argcontainer')._ActionsContainer

HelpFormatter = require('./helpformatter').HelpFormatter

{ArgumentError, ArgumentTypeError} = require('./error')
class Namespace
  isset: (key) -> @[key]?
  get: (key, defaultValue) -> @[key] ? defaultValue
  set: (key, value) -> @[key] = value
  repr: () -> 'Namespace'+ util.inspect(@)

if DEBUG and 0
  np = new Namespace()
  console.log np
  console.log np.repr()
  console.log np.isset('test')
  console.log np.get('test','default')
  np.set('test','something')
  np.set('foo', null)
  console.log np.isset('test')
  console.log np.get('test','default')
  console.log np.repr()

# argparse separates these exports from definion of ArgumentParser
exports.Namespace = Namespace
exports.HelpFormatter = HelpFormatter
exports.Const = $$
exports.Action = require('./action')
exports.ArgumentTypeError = ArgumentTypeError


class ArgumentParser extends _ActionsContainer
    constructor: (options={}) ->
        @prog=options.prog ? path.basename(process.argv[1])
        @usage=options.usage ? null
        @epilog=options.epilog ? null
        @parents=options.parents ? []
        @formatter_class=options.formatter_class ? HelpFormatter
        @fromfile_prefix_chars = options.fromfile_prefix_chars ? null
        @add_help = options.addHelp ? options.add_help ? true
        @debug = options.debug ? false

        @description=options.description ? null
        @prefix_chars=options.prefixChars ? options.prefix_chars ? '-'
        @argument_default=options.argumentDefault ? options.argument_default ? null
        @conflict_handler=options.conflict_handler ? options.conflictHandler ? 'error'
        acoptions = {
            description: @description,
            prefixChars: @prefix_chars,
            argument_default: @argument_default,
            conflictHandler: @conflict_handler}
        _ActionsContainer.call(this, acoptions)
        @_positionals = @add_argument_group({title: 'Positional arguments'})
        @_optionals = @add_argument_group({title: 'Optional arguments'})
        @_subparsers = null

        # type can be any fn that takes string and returns a value, or throws an error
        # Python int, float, etc work
        # JS parseInt, parseFloat return NaN instead of an error
        # type can be user supplied, but these are a few convenience types

        # register types
        @register('type', null, (o)->o)  # identity
        @register('type', 'auto', (o)->o)
        @register('type', 'int', (x) ->
            result = parseInt(x, 10)
            if isNaN(result)
                throw new TypeError("#{x} is not a valid integer.")
            return result)
        @register('type', 'float', (x) ->
            result = parseFloat(x, 10)
            if isNaN(result)
                throw new TypeError("#{x} is not a valid float.")
            return result)
        @register('type', 'string', (x) ->
            return '' + x)

        # add help and version arguments if necessary
        # (using explicit default to override global argument_default)
        default_prefix = if '-' in @prefix_chars then '-' else @prefix_chars[0]
        if @add_help
            @addArgument([default_prefix+'h', default_prefix+default_prefix+'help'],\
                {action:'help',
                defaultValue:$$.SUPPRESS, # of default of the action already
                help:'Show this help message and exit'
            })

        if @version
            @addArgument([default_prefix+'v', default_prefix+default_prefix+'version'],\
                {action:'version', default:$$.SUPPRESS, \
                version:@version,\
                help:"show program's version number and exit"
            })

        for parent in @parents
            if @_addContainerActions?
              @_addContainerActions(parent)
            else
              @_add_container_actions(parent)
            if parent._defaults?
                for defaultKey of parent._defaults
                    if parent._defaults[defaultKey]? # has defaultKey # own?
                        @_defaults[defaultKey] = parent._defaults[defaultKey]
        @

    # =======================
    # Pretty __repr__ methods
    # =======================
    _get_kwargs: () ->
        names = [
            'prog',
            'usage',
            'description',
            'version',
            'formatter_class',
            'conflict_handler',
            'add_help',
        ]
        return ([name, this[name]] for name in names)
        # python uses getattr(self, name)
    # ==================================
    # Optional/Positional adding methods
    # ==================================

    add_subparsers: (options={}) ->
        if @_subparsers?
            @error('cannot have multiple subparser arguments')
        options.defaultValue = null
        options.debug = @debug
        options.option_strings = []
        options.parserClass = (options.parserClass || ArgumentParser)

        # add the parser class to the arguments if it's not present
        #?options.setdefault('parser_class', type(self))

        if options.title? or options.description?
            title = options.title ?  'subcommands'
            description = options.description ? null
            delete options.title
            delete options.description
            @_subparsers = @add_argument_group({title: title, description: description})
        else
            @_subparsers = @_positionals

        # prog defaults to the usage message of this parser, skipping
        # optional arguments and with no "usage:" prefix
        if not options.prog?
            formatter = @_getFormatter()
            positionals = @_get_positional_actions()
            groups = @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
            formatter.addUsage(@usage, positionals, groups, '')
            options['prog'] = _.str.strip(formatter.formatHelp())

        # create the parsers action and add it to the positionals list
        # ParsersClass = (@_popActionClass ? @_pop_action_class)(options, 'parsers')
        if @_popActionClass?
          ParsersClass = @_popActionClass(options, 'parsers')
        else
          ParsersClass = @_pop_action_class(options, 'parsers')

        action = new ParsersClass(options)
        DEBUG action.nargs
        DEBUG @_subparsers.__super__
        if @_subparsers._add_action?
          @_subparsers._add_action(action)
        else
          @_subparsers._add_action(action)

        # return the created parsers action
        return action

    _add_action: (action) ->
        if action.isOptional()
            assert(action.option_strings)
            this._optionals._add_action(action)
        else
            # DEBUG 'pos action:',action.dest
            this._positionals._add_action(action)
        return action

    _get_optional_actions: () ->
        return (action for action in this._actions when action.isOptional())

    _get_positional_actions: () ->
        return (action for action in this._actions when action.isPositional())

    # =====================================
    # Command line argument parsing methods
    # =====================================
    parse_args: (args=null, namespace=null) ->
        [args, argv] = @parse_known_args(args, namespace)
        if argv.length>0
            msg = "unrecognized arguments: #{argv.join(' ')}"
            @error(msg)
        return args

    parse_known_args: (args=null, namespace=null) ->
        # args default to system args
        args = args || process.argv[2...]

        # default Namespace built from parser defaults
        namespace = namespace ? new Namespace()
        DEBUG "parse_known_args: '#{@prog}'"
        DEBUG 'namespace:', namespace.repr()

        # add any action defaults that aren't present
        for action in @_actions
            DEBUG 'action default: ',action.dest,action.defaultValue
            if action.dest != $$.SUPPRESS
                if not namespace.isset(action.dest)
                    if action.defaultValue != $$.SUPPRESS
                        _default = action.defaultValue
                        #if _.isString(_default)
                        #    _default = @_get_value(action, _default)
                        # correction in python to prevent calling action
                        # on default if not needed
                        # rev/62b5667ef2f4
                        namespace.set(action.dest, _default)

        DEBUG 'with defaults:',namespace.repr()
        # add any parser defaults that aren't present
        for dest of @_defaults
            if not namespace.isset(dest)
                namespace.set(dest, @_defaults[dest])

        # parse the arguments and exit if there are any errors
        try # if true
            DEBUG 'initial args', args, namespace.repr()
            [namespace, args] = @_parse_known_args(args, namespace)
            if namespace.isset($$._UNRECOGNIZED_ARGS_ATTR)
                args.push(namespace.get($$._UNRECOGNIZED_ARGS_ATTR))
                namespace.unset($$._UNRECOGNIZED_ARGS_ATTR, null)
            return [namespace, args]

        catch error
            if error instanceof ArgumentError
                DEBUG 'pna: passing ArgumentError to @error'
                @error(error)
            else
                DEBUG 'pna: rethrowing error'
                throw error

        argv = []
        return [args, argv]

    _parse_known_args: (arg_strings, namespace) ->
        # replace arg strings that are file references
        if @fromfile_prefix_chars?
            arg_strings = @_read_args_from_files1(arg_strings)
            DEBUG 'from files', arg_strings

        # map all mutually exclusive arguments to the other arguments
        # they can't occur with
        actionConflicts = {}
        actionHash = (action) ->
            return action.getName()
        mxgroups = @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
        for mutex_group in mxgroups
            group_actions = mutex_group._groupActions ? mutex_group._group_actions
            for mutex_action, i in group_actions
                key =  actionHash(mutex_action)
                if not actionConflicts[key]?
                    actionConflicts[key] = []
                conflicts = actionConflicts[key]
                conflicts.push(group_actions[...i]...)
                conflicts.push(group_actions[i + 1..]...)

        # find all option indices, and determine the arg_string_pattern
        # which has an 'O' if there is an option at an index,
        # an 'A' if there is an argument, or a '-' if there is a '--'
        option_string_indices = {}
        arg_string_pattern_parts = []
        for arg_string, i in arg_strings
            # Py uses iter() to iter over the rest after --
            # all args after -- are non-options
            if arg_string == '--'
                arg_string_pattern_parts.push('-')
                # for arg_string in arg_strings_iter:
                for arg_string in arg_strings[(i+1)...]
                    # iterate over the rest of arg_strings
                    arg_string_pattern_parts.push('A')
                break
            # otherwise, add the arg to the arg strings
            # and note the index if it was an option
            else
                option_tuple = @_parse_optional(arg_string)
                if option_tuple is null
                    pattern = 'A'
                else
                    option_string_indices[i] = option_tuple
                    pattern = 'O'
                arg_string_pattern_parts.push(pattern)

        # join the pieces together to form the pattern
        arg_string_pattern = arg_string_pattern_parts.join('')
        DEBUG 'pattern:',arg_string_pattern, _.keys(option_string_indices)

        # converts arg strings to the appropriate and then takes the action
        seen_actions = []  # py uses set()
        seen_non_default_actions = []

        take_action = (action, argument_strings, option_string=null) =>
            seen_actions.push(action)
            argument_values = @_get_values(action, argument_strings)
            DEBUG 'take_action, _get values:', argument_strings, argument_values
            # error if this argument is not allowed with other previously
            # seen arguments, assuming that actions that use the default
            # value don't really count as "present"
            if argument_values != action.defaultValue
                seen_non_default_actions.push(action)
                key = actionHash(action)
                if actionConflicts[key]?
                    for actionConflict in actionConflicts[key]
                        if actionConflict in seen_non_default_actions
                            msg = "not allowed with argument #{actionConflict.getName()}"
                            # @error(action.getName() + ': ' + msg)
                            throw new ArgumentError(action, msg)

            # take the action if we didn't receive a SUPPRESS value
            # (e.g. from a default)
            if argument_values != $$.SUPPRESS
                action.call(@, namespace, argument_values, option_string)
                DEBUG 'taken_action:',action.dest,namespace.repr()
                DEBUG '    ', argument_values, option_string

        consume_optional = (start_index) =>
            # get the optional identified at this index
            option_tuple = option_string_indices[start_index]
            [action, option_string, explicit_arg] = option_tuple
            if action? then DEBUG 'option tuple:', [action.dest, option_string, explicit_arg]
            # identify additional optionals in the same arg string
            # (e.g. -xyz is the same as -x -y -z if no args are required)
            match_argument = @_match_argument
            action_tuples = []
            while true

                # if we found no optional action, skip it
                if action is null
                    extras.push(arg_strings[start_index])
                    return start_index + 1

                # if there is an explicit argument, try to match the
                # optional's string arguments to only this
                if explicit_arg?
                    arg_count = match_argument(action, 'A')

                    # if the action is a single-dash option and takes no
                    # arguments, try to parse more single-dash options out
                    # of the tail of the option string
                    chars = @prefix_chars
                    if arg_count == 0 and option_string[1] not in chars
                        DEBUG "explicit arg: '#{explicit_arg}', '#{option_string}'"
                        action_tuples.push([action, [], option_string])
                        char = option_string[0]
                        option_string = char + explicit_arg[0]
                        new_explicit_arg = explicit_arg[1...] || null
                        optionals_map = @_option_string_actions
                        if optionals_map[option_string]?
                            action = optionals_map[option_string]
                            explicit_arg = new_explicit_arg
                        else
                            msg = "ignored explicit argument #{explicit_arg}"
                            #@error(action.getName() + ': ' + msg)
                            throw new ArgumentError(action, msg)

                    # if the action expect exactly one argument, we've
                    # successfully matched the option; exit the loop
                    else if arg_count == 1
                        stop = start_index + 1
                        args = [explicit_arg]
                        action_tuples.push([action, args, option_string])
                        break

                    # error if a double-dash option did not use the
                    # explicit argument
                    else
                        msg = "ignored explicit argument #{explicit_arg}"
                        @error(action.getName() + ': ' + msg)

                # if there is no explicit argument, try to match the
                # optional's string arguments with the following strings
                # if successful, exit the loop
                else
                    DEBUG 'consume optional, push action tuple'
                    start = start_index + 1
                    selected_patterns = arg_string_pattern[start...]
                    DEBUG '    ', start, arg_string_pattern, action.dest
                    arg_count = match_argument(action, selected_patterns)
                    stop = start + arg_count
                    args = arg_strings[start...stop]
                    action_tuples.push([action, args, option_string])
                    break

            # add the Optional to the list and return the index at which
            # the Optional's string args stopped
            # assert action_tuples
            #for [action, args, option_string] in action_tuples
            #    take_action(action, args, option_string)
            take_action(tuple...) for tuple in action_tuples
            return stop

        # the list of Positionals left to be parsed; this is modified
        # by consume_positionals()
        positionals = @_get_positional_actions()

        # function to convert arg_strings into positional actions
        consume_positionals = (start_index) =>
            # match as many Positionals as possible
            match_partial = @_match_arguments_partial
            selected_pattern = arg_string_pattern[start_index...]
            DEBUG 'cp', selected_pattern
            arg_counts = match_partial(positionals, selected_pattern)

            # slice off the appropriate arg strings for each Positional
            # and add the Positional and its args to the list
            DEBUG 'arg count:',arg_counts
            # py zip stops w/ shortest. _ zip goes with the longest
            # in subparser case there is a subcommand name
            # js version tests for arg_count.length
            #if arg_counts.length
            for [action, arg_count] in _.zipShortest(positionals, arg_counts)
                args = arg_strings[start_index...start_index + arg_count]
                start_index += arg_count
                DEBUG 'take action:',action.dest, args
                DEBUG namespace.repr()
                take_action(action, args)

            # slice off the Positionals that we just parsed and return the
            # index at which the Positionals' string args stopped
            positionals[..] = positionals[arg_counts.length...]
            return start_index

        # consume Positionals and Optionals alternately, until we have
        # passed the last option string
        extras = []
        start_index = 0
        index_keys = (+x for x in _.keys(option_string_indices))
        if index_keys.length>0
            max_option_string_index = Math.max(index_keys...)
        else
            max_option_string_index = -1
        DEBUG 'index',_.keys(option_string_indices), max_option_string_index
        while start_index <= max_option_string_index

            # consume any Positionals preceding the next option
            next_option_string_index = Math.min((index for index in index_keys when index >= start_index)...)
            if start_index != next_option_string_index
                DEBUG 'lp consume positional:',start_index
                positionals_end_index = consume_positionals(start_index)

                # only try to parse the next optional if we didn't consume
                # the option string during the positionals parsing
                if positionals_end_index > start_index
                    start_index = positionals_end_index
                    continue
                else
                    start_index = positionals_end_index

            # if we consumed all the positionals we could and we're not
            # at the index of an option string, there were extra arguments
            if start_index not in index_keys
                strings = arg_strings[start_index...next_option_string_index]
                extras.push(strings...)
                start_index = next_option_string_index

            # consume the next optional and any arguments for it
            DEBUG 'consume optional',start_index
            start_index = consume_optional(start_index)

        # consume any positionals following the last Optional
        DEBUG 'consume positional',start_index
        stop_index = consume_positionals(start_index)

        # if we didn't consume all the argument strings, there were extras
        extras.push(arg_strings[stop_index..]...)

        # if we didn't use all the Positional objects, there were too few
        # arg strings supplied.
        if positionals.length>0
            @error('too few arguments')

        # make sure all required actions were present
        for action in @_actions
            ###
            if action.required
                if action not in seen_actions
                    @error("argument #{action.getName()} is required")
            ###
            if action not in seen_actions
                if action.required
                    @error("argument #{action.getName()} is required")
                    # modification in dev python that can show multiple missing actions
                else
                    # Convert action default now instead of doing it before
                    # parsing arguments to avoid calling convert functions
                    # twice (which may fail) if the argument was given, but
                    # only if it was defined already in the namespace
                    # http://hg.python.org/cpython/rev/62b5667ef2f4
                    # python checks defaultValue is not None
                    # but here the isString test takes care of that
                    if _.isString(action.defaultValue) and \
                            namespace[action.dest]? \
                            and action.defaultValue == namespace[action.dest]
                        namespace[action.dest] = @_get_value(action, action.defaultValue)

        # make sure all required groups had one option present
        action_used = false
        for group in @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
            if group.required
                DEBUG 'group required'
                gactions = group._groupActions ? group._group_actions
                for action in gactions
                    if action in seen_non_default_actions
                        action_used = true
                        break

                # if no actions were used, report the error
                if not action_used
                    DEBUG 'not action used'
                    names = (action.getName() for action in gactions \
                        when action.help != $$.SUPPRESS)
                        msg = "one of the arguments #{names.join(' ')} is required"
                        @error(msg)

        DEBUG 'known:',[namespace.repr(), extras]
        return [namespace, extras]

    _read_args_from_files: (arg_strings) ->
        # expand arguments referencing files
        fs = require('fs')
        new_arg_strings = []
        for arg_string in arg_strings
            # for regular arguments, just add them back into the list
            if arg_string[0] not in @fromfile_prefix_chars
                new_arg_strings.push(arg_string)
            # replace arguments referencing files with the file content
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  content = fs.readFileSync(filename, 'utf8')
                  content = content.trim().split('\n')
                  DEBUG filename, content
                  for arg_line in content
                    for arg in @convert_arg_line_to_args(arg_line)
                      argstrs.push(arg)
                    argstrs = @_read_args_from_files(argstrs)
                  new_arg_strings.push(argstrs...)
                catch error
                  console.log error.message
                  @error(error.message)
        return new_arg_strings

    _read_args_from_files1: (arg_strings) =>
        ### expand arguments referencing files
        adding ,@ context to forEach takes care of binding problems
        ###
        prefix_chars = @fromfile_prefix_chars
        convert_line = @convert_arg_line_to_args
        read_args = @_read_args_from_files
        #console.log prefix_chars, convert_line, read_args
        fs = require('fs')
        new_arg_strings = []
        arg_strings.forEach( (arg_string) ->
            ### for regular arguments, just add them back into the list ###
            if @fromfile_prefix_chars.indexOf(arg_string[0])<0
                new_arg_strings.push(arg_string)
                ### replace arguments referencing files with the file content ###
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  content = fs.readFileSync(filename, 'utf8')
                  content = content.trim().split('\n')
                  DEBUG filename, content
                  content.forEach((arg_line) ->
                    @convert_arg_line_to_args(arg_line).forEach( (arg) ->
                      argstrs.push(arg)
                    )
                    argstrs = @_read_args_from_files1(argstrs) # recursive call
                  , @)
                  new_arg_strings.push(argstrs...)
                catch error
                  console.log error.message
                  @error(error.message)
        , @)
        return new_arg_strings

    _read_args_from_files2: (arg_strings) =>
        ### expand arguments referencing files
        try to use the async form of readfile;
        it doesnt wait for the read to finish
        ###
        prefix_chars = @fromfile_prefix_chars
        convert_line = @convert_arg_line_to_args
        read_args = @_read_args_from_files
        #console.log prefix_chars, convert_line, read_args
        fs = require('fs')
        new_arg_strings = []
        arg_strings.forEach( (arg_string) =>
            ### for regular arguments, just add them back into the list ###
            if @fromfile_prefix_chars.indexOf(arg_string[0])<0
                new_arg_strings.push(arg_string)
                ### replace arguments referencing files with the file content ###
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  fs.readFile(filename, 'utf8', (err, data) ->
                    if err
                      throw err
                    data = data.trim().split('\n')
                    DEBUG filename, data
                    content.forEach((arg_line) ->
                      @convert_arg_line_to_args(arg_line).forEach( (arg) ->
                        argstrs.push(arg)
                      )
                      argstrs = @_read_args_from_files2(argstrs) # recursive call
                    )
                    new_arg_strings.push(argstrs...)
                  )
                  # shouldn't proceed until this read is done
                catch error
                  console.log error.message
                  @error(error.message)
        )
        return new_arg_strings

    convert_arg_line_to_args: (arg_line) ->
        return [arg_line]

    _match_argument: (action, arg_strings_pattern) =>
        # match the pattern for this action to the arg strings
        nargs_pattern = @_get_nargs_pattern(action)
        nargs_pattern = '^' + nargs_pattern
        # py looks for match from start
        matches = arg_strings_pattern.match(nargs_pattern)
        DEBUG 'match_argument', arg_strings_pattern, nargs_pattern, matches
        # raise an exception if we weren't able to find a match
        if not matches?
            args_errors = {null: 'expected one argument'}
            args_errors[$$.OPTIONAL] = 'expected at most one argument'
            args_errors[$$.ONE_OR_MORE] = 'expected at least one argument'
            msg = args_errors[action.nargs] ? "expected #{action.nargs} argument(s)"
            #msg = "#{msg} for action #{action.dest}"
            #@error(action.getName() + ': ' + msg)
            throw new ArgumentError(action, msg)

        # return the number of arguments matched
        return matches[1].length

    _match_arguments_partial: (actions, arg_strings_pattern) =>
        # progressively shorten the actions list by slicing off the
        # final actions until we find a match
        result = []
        #foo = get_nargs_pattern # @_get... not found
        DEBUG 'actions:',(a.dest for a in actions)
        DEBUG 'arg strings pattern:',arg_strings_pattern
        foo = @_get_nargs_pattern
        for i in [actions.length..0]
            actions_slice = actions[...i]
            pattern = (foo(action) for action in actions_slice).join('')
            m = arg_strings_pattern.match('^'+pattern)
            DEBUG 'pattern:',pattern
            DEBUG 'matches:',m
            if m?
                m = m[1...]
                result.push((string.length for string in m)...)
                break
        # return the list of arg string counts
        DEBUG 'match arguments partial:',result
        return result

    _parse_optional: (arg_string) ->
        # if it's an empty string, it was meant to be a positional
        assert(@prefix_chars?)
        DEBUG 'parse opt:',arg_string, @prefix_chars
        if not arg_string
            return null

        # if it doesn't start with a prefix, it was meant to be positional
        if not (arg_string[0] in @prefix_chars)
            return null

        # if the option string is present in the parser, return the action
        actions = @_option_string_actions
        if actions[arg_string]?
            action = actions[arg_string]
            return [action, arg_string, null]

        # if it's just a single character, it was meant to be positional
        if arg_string.length == 1
            return null

        # if the option string before the "=" is present, return the action
        if '=' in arg_string
            [option_string, explicit_arg] = arg_string.split('=')
            # may be a difference in 'split limit' between languages
            if actions[option_string]?
                action = actions[option_string]
                return [action, option_string, explicit_arg]

        # search through all possible prefixes of the option string
        # and all actions in the parser for possible interpretations
        option_tuples = @_get_option_tuples(arg_string)
        DEBUG 'get opt tuples',arg_string,option_tuples.length
        # if multiple actions match, the option string was ambiguous
        if option_tuples.length > 1
            options = (option_string for [action, option_string, explicit_arg] in option_tuples)
            options = options.join(', ')
            tup = [arg_string, options]
            @error("ambiguous option: #{arg_string} could match #{options}")

        # if exactly one action matched, this segmentation is good,
        # so return the parsed action
        else if option_tuples.length == 1
            option_tuple = option_tuples[0]
            return option_tuple

        # if it was not found as an option, but it looks like a negative
        # number, it was meant to be positional
        # unless there are negative-number-like options
        if arg_string.match(@_negative_number_matcher)
            if not _.any(@_hasNegativeNumberOptionals)
                return null

        # if it contains a space, it was meant to be a positional
        if ' ' in arg_string
            return null

        # it was meant to be an optional but there is no such option
        # in this parser (though it might be a valid option in a subparser)
        return [null, arg_string, null]

    _get_option_tuples: (option_string) ->
        result = []

        # option strings starting with two prefix characters are only
        # split at the '='
        chars = @prefix_chars
        if option_string[0] in chars and option_string[1] in chars
            if '=' in option_string
                [option_prefix, explicit_arg] = option_string.split('=') # ,)
            else
                option_prefix = option_string
                explicit_arg = null
            actions = @_option_string_actions
            for option_string of actions
                if _.str.startsWith(option_string, option_prefix)
                    action = actions[option_string]
                    tup = [action, option_string, explicit_arg]
                    result.push(tup)

        # single character options can be concatenated with their arguments
        # but multiple character options always have to have their argument
        # separate
        else if option_string[0] in chars and option_string[1] not in chars
            option_prefix = option_string
            explicit_arg = null
            short_option_prefix = option_string[...2]
            short_explicit_arg = option_string[2..]

            actions = @_option_string_actions
            for option_string of actions
                if option_string == short_option_prefix
                    action = actions[option_string]
                    tup = [action, option_string, short_explicit_arg]
                    result.push(tup)
                else if _.str.startsWith(option_string,option_prefix)
                    action = actions[option_string]
                    tup = [action, option_string, explicit_arg]
                    result.push(tup)

        # shouldn't ever get here
        else
            #throw new Error("unexpected option string: #{option_string}")
            @error("unexpected option string: #{option_string}")

        # return the collected option tuples
        return result

    _get_nargs_pattern: (action) ->
        # in all examples below, we have to allow for '--' args
        # which are represented as '-' in the pattern
        nargs = action.nargs

        # the default (null) is assumed to be a single argument
        if nargs is null
            nargs_pattern = '(-*A-*)'

        # allow zero or one arguments
        else if nargs == $$.OPTIONAL
            nargs_pattern = '(-*A?-*)'

        # allow zero or more arguments
        else if nargs == $$.ZERO_OR_MORE
            nargs_pattern = '(-*[A-]*)'

        # allow one or more arguments
        else if nargs == $$.ONE_OR_MORE
            nargs_pattern = '(-*A[A-]*)'

        # allow any number of options or arguments
        else if nargs == $$.REMAINDER
            nargs_pattern = '([-AO]*)'

        # allow one argument followed by any number of options or arguments
        else if nargs == $$.PARSER
            nargs_pattern = '(-*A[-AO]*)'

        # all others should be integers
        else
            # nargs_pattern = '(-*%s-*)' % '-*'.join('A' * nargs)
            nargs_pattern = "(-*#{('A' for i in [0...nargs]).join('')}-*)"
        # if this is an optional action, -- is not allowed
        if action.isOptional()
            nargs_pattern = nargs_pattern.replace(/-\*/g, '')
            nargs_pattern = nargs_pattern.replace(/-/g, '')

        # return the pattern
        DEBUG nargs, nargs_pattern
        return nargs_pattern

    # ========================
    # Value conversion methods
    # ========================
    _get_values: (action, arg_strings) ->
        # for everything but PARSER args, strip out '--'
        DEBUG '_get_values:'
        if action.nargs not in [$$.PARSER, $$.REMAINDER]
            arg_strings = (s for s in arg_strings when s != '--')

        DEBUG arg_strings.length, action.nargs, action.option_strings, action.defaultValue
        # optional argument produces a default when not present
        if arg_strings.length==0 and action.nargs == $$.OPTIONAL
            DEBUG 'doing ?'
            if action.isOptional()
                value = action.constant
            else
                value = action.defaultValue
            if _.isString(value)
                value = @_get_value(action, value)
                @_check_value(action, value)

        # when nargs='*' on a positional, if there were no command-line
        # args, use the default if it is anything other than null
        else if (arg_strings.length==0 and action.nargs == $$.ZERO_OR_MORE and action.isPositional())
            DEBUG 'doing *'
            if action.defaultValue?
                value = action.defaultValue
            else
                value = arg_strings
                DEBUG value
            @_check_value(action, value)

        # single argument or optional argument produces a single value
        else if arg_strings.length == 1 and action.nargs in [null, $$.OPTIONAL]
            arg_string = arg_strings[0]
            value = @_get_value(action, arg_string)
            @_check_value(action, value)

        # REMAINDER arguments convert all values, checking null
        else if action.nargs == $$.REMAINDER
            value = (@_get_value(action, v) for v in arg_strings)

        # PARSER arguments convert all values, but check only the first
        else if action.nargs == $$.PARSER
            value = (@_get_value(action, v) for v in arg_strings)
            DEBUG 'value from subparse', value
            @_check_value(action, value[0])

        # all other types of nargs produce a list
        else
            value = (@_get_value(action, v) for v in arg_strings)
            for v in value
                @_check_value(action, v)

        # return the converted value
        return value

    _get_value: (action, arg_string) ->
        type_func = @_registryGet('type', action.type, action.type)
        if not _.isFunction(type_func) # _callable(type_func):
            msg = "#{type_func} is not callable"
            @error(action.getName() + ': ' + msg)

        # convert the value to the appropriate type
        try
            result = type_func(arg_string)
        catch error
            if _.isString(action.type)
                name = action.type
            else
                name = action.type.name || action.type.displayName || '<function>'
            #msg = "Invalid #{name} value: #{arg_string}"
            #msg = action.getName() + ': ' + msg
            if error instanceof TypeError
              msg = "Invalid #{name} value: #{arg_string}"
              throw new ArgumentError(action, msg)
            else if error instanceof ArgumentTypeError
              #@error(msg + '\n' + error.message)
              throw new ArgumentError(action, error.message)
            else
              throw error
        return result

    _check_value: (action, value) ->
        # converted value must be one of the choices (if specified)
        # py test for 'value not in choices', which works for string, list, dict keys
        if action.choices?
          if _.isString(action.choices)
            choices = action.choices
            choices = choices.split(/\W+/) # 'white space' separators
            if choices.length==1
              choices = choices[0].split('') # individual letters
          else if _.isArray(action.choices)
            choices = action.choices
          else if _.isObject(action.choices)
            choices = _.keys(action.choices)
          if value not in choices
            msg = "invalid choice: #{value} (choose from #{choices})"
            # @error(action.getName() + ': ' + msg)
            throw new ArgumentError(action, msg)

    ###
    # argument_parser.js has more elaborate checkvalue
        ArgumentParser.prototype._checkValue = function (action, value) {
      // converted value must be one of the choices (if specified)
      var choices = action.choices;
      if (!!choices) {
        // choise for argument can by array or string
        if ((_.isString(choices) || _.isArray(choices)) &&
            choices.indexOf(value) !== -1) {
          return;
        }
        // choise for subparsers can by only hash
        if (_.isObject(choices) && !_.isArray(choices) && choices[value]) {
          return;
        }

        if (_.isString(choices)) {
          choices = choices.split('').join(', ');
        }
        else if (_.isArray(choices)) {
          choices =  choices.join(', ');
        }
        else {
          choices =  _.keys(choices).join(', ');
        }
        var message = _.str.sprintf(
          'Invalid choice: %(value)s (choose from [%(choices)s])',
          {value: value, choices: choices}
        );
        throw argumentError(action, message);
      }
    };
    ###

    # ===============
    # Help formatting methods
    # ===============
    # adapt from javascript version

    format_usage: () ->
        formatter = @_getFormatter()
        formatter.addUsage(@usage, @_actions, @_mutually_exclusive_groups)
        return formatter.formatHelp()
    formatUsage: () -> @format_usage()

    format_help: () ->
        formatter = @_getFormatter()
        # usage
        formatter.addUsage(@usage, @_actions, @_mutually_exclusive_groups)
        formatter.addText(@description)
        for actionGroup in (@_actionGroups ? @_action_groups)
            formatter.startSection(actionGroup.title)
            formatter.addText(actionGroup.description)
            formatter.addArguments(actionGroup._groupActions ? actionGroup._group_actions)
            formatter.endSection()
        formatter.addText(@epilog)
        return formatter.formatHelp()
    formatHelp: () -> @format_help()

    _getFormatter: () ->
        FormatterClass = @formatter_class
        formatter = new FormatterClass({prog: @prog})

    printUsage: () ->
        @_printMessage(@format_usage())
    print_usage: () -> @printUsage()
    printHelp: () ->
        @_printMessage(@format_help())
    print_help: () -> @printHelp()

    #_printMessage: (message, stream) ->
    #    stream = stream ? process.stdout
    #    stream.write('' + message)


    # ===============
    # Exiting methods
    # ===============
    error: (err) ->
        assert(@debug?,'@ error in @error')
        if (err instanceof Error)
            if @debug
                DEBUG '@error debug error'
                throw err
            message = err.message
        else
            message = err
        msg = "#{@prog}: error: #{message}#{$$.EOL}"
        if @debug
            DEBUG '@error debug message'
            throw new Error(msg)
        @print_usage(process.stderr)
        return @exit(2,msg)

    exit: (status, message) ->
        if message?
            if status==0
                @_printMessage(message)
            else
                @_printMessage(message, process.stderr)
        if @debug
            # capture exit, such as from action help
            throw new Error('Exit captured')
        else
            process.exit(status)

    _printMessage: (message, stream=process.stdout) ->
        if message
            stream.write('' + message)

    # ===============
    # CamelCase Aliases
    # ===============
    parseArgs: (args, namespace=null) -> @parse_args(args, namespace)
    parseKnownArgs: (args, namespace=null) -> @parse_known_args(args, namespace)
    addSubparsers: (args) -> @add_subparsers(args)
    if not @::add_argument?
      add_argument: (args..., options) ->
          # Python like arguments;
          # if last arg is a string, assume it is one of the 'args'
          # and options is an empty object
          if _.isString(options)
            # assume
            args.push(options)
            options = {}
          @addArgument(args, options)

# =====================
# Options and Arguments
# =====================



exports.ArgumentParser = ArgumentParser

# =============================
# Utility functions and classes
# =============================

###
used as base for Namespace; appears to do the same as JS object display
class _AttributeHolder(object):
    """Abstract base class that provides __repr__.

    The __repr__ method returns a string in the format::
        ClassName(attr=name, attr=name, ...)
    The attributes are determined either by a class-level attribute,
    '_kwarg_names', or by inspecting the instance __dict__.
    """

    def __repr__(self):
        type_name = type(self).__name__
        arg_strings = []
        for arg in self._get_args():
            arg_strings.append(repr(arg))
        for name, value in self._get_kwargs():
            arg_strings.append('%s=%r' % (name, value))
        return '%s(%s)' % (type_name, ', '.join(arg_strings))

    def _get_kwargs(self):
        return sorted(self.__dict__.items())

    def _get_args(self):
        return []
###

_ensure_value = (namespace, name, value) ->
    if getattr(namespace, name, null) is null
        setattr(namespace, name, value)
    return getattr(namespace, name)

# basic methods in Python, used to access Namespace
# with these do we need a special Namespace class?
getattr = (obj, key, defaultValue) ->
    obj[key] ? defaultValue
setattr = (obj, key, value) ->
    obj[key] = value
hasattr = (obj, key) ->
    obj[key]?

# should I make None a syn of null?


# ==============
# Type classes
# ==============

class FileClass # Type
    ###Factory for creating file object types

    Instances of FileType are typically passed as type= arguments to the
    ArgumentParser add_argument() method.

    Keyword Arguments:
        - mode -- A string indicating how the file is to be opened. Accepts the
            same values as the builtin open() function.
        - bufsize -- The files desired buffer size. Accepts the same values as
            the builtin open() function.
    Python uses mode, nodejs uses 'flags'
    ###
    fs = require('fs') # nodejs
    constructor: (options) ->
        if _.isString(options)
          options = {flags:options}
        @options = options

    call: (filename) ->
        # the special argument "-" means sys.std{in,out}
        flags = @options.flags
        # console.log @options, flags
        if filename == '-'
            if 'r' in flags
                return process.stdin
            else if 'w' in flags
                return process.stdout
            else
                msg = "argument '-' with flags #{flags}"
                throw new TypeError(msg)
                # @error(msg) # raise ValueError(msg)
        if flags == 'r'
          createStream = fs.createReadStream
        else if flags == 'w'
          createStream = fs.createWriteStream
        else
          throw new TypeError('Unknown file flag')
          # don't try to handle more complicated flags like r+
        try
          # open file before creating stream
          # and capture any errors
          fd = fs.openSync(filename, flags)
          @options.fd = fd
          stream = createStream(filename, @options)
        catch error
          throw new ArgumentTypeError(error.message)
        return stream


FileType = (options={flags:'r'}) ->
    # callable function that can be used by Action store
    ft = new FileClass(options)
    fn = (string) ->
        ft.call(string)
    fn.displayName = 'FileType' # name to use in error messages
    return fn

# don't need a class; just return a function that takes the string argument
# and returns a file (here a stream) or throws an error
fileType = (options={flags:'r'}) ->
    # callable function that can be used by _get_value
    fs = require('fs')
    fn = (filename) ->
        # the special argument "-" means sys.std{in,out}
        flags = options.flags
        # console.log @options, flags
        if filename == '-'
            if 'r' in flags
                return process.stdin
            else if 'w' in flags
                return process.stdout
            else
                msg = "argument '-' with flags #{flags}"
                throw new Error(msg)
        if flags == 'r'
          createStream = fs.createReadStream
        else if flags == 'w'
          createStream = fs.createWriteStream
        else
          throw new TypeError('Unknown file flag')
          # don't try to handle more complicated flags like r+
        try
          # open file before creating stream
          # and capture any errors
          fd = fs.openSync(filename, flags)
          options.fd = fd
          stream = createStream(filename, options)
        catch error
          throw error
        return stream
    fn.displayName = 'FileType' # name to use in error messages
    return fn

fileType = (options={flags:'r'}) ->
    # callable function that can be used by _get_value
    # or a more compact form
    fs = require('fs')
    if _.isString(options)
      flags = options
    else
      {flags} = options
    if flags == 'r'
      [std, createStream] = [process.stdin, fs.createReadStream]
    else if flags == 'w'
      [std, createStream] = [process.stdout, fs.createWriteStream]
    else
      msg = "argument '-' with flag #{flags}"
      throw new TypeError(msg)
    fn = (filename) ->
      if filename == '-'
        stream = std
      else
        # open file before creating stream
        # and capture any errors
        try
          fd = fs.openSync(filename, flags)
          options.fd = fd
          stream = createStream(filename, options)
        catch err
          msg = "can't open #{filename}: #{err.message}"
          throw ArgumentTypeError(msg)
      return stream
    fn.displayName = 'FileType' # name to use in error messages
    return fn



# use: parser.add_argument('--outfile',{type:ap.FileType('w')})
# args.outfile should then be a writable filehandle
exports.FileType = FileType
exports.fileType = fileType

exports.newParser = (options={}) ->
  # convenience function
  if not options.debug then options.debug = true
  new ArgumentParser(options)

#============================================
# Testing
#============================================
TEST = not module.parent?

testparse = (args) ->
  console.log args
  console.log (
    try
      parser.parseArgs(args)
    catch error
      error
  )

if TEST and 0
    parser = new ArgumentParser()
    #console.log 'obj:',util.inspect(parser,false,0)
    #console.log parser._action_groups[0]
    console.log parser.format_help()
    parser.add_subparsers({})
    console.log 'class:',
    console.log ArgumentParser
    console.log 'proto'
    console.log ArgumentParser.prototype
    console.log ArgumentParser.prototype.constructor.super_
    console.log ArgumentParser.prototype.constructor.__super__
    console.log '====================================='
    console.log parser.formatHelp()

if TEST and 0
    parentParser = new ArgumentParser({add_help: false, description: 'parent'})
    parentParser.addArgument(['--x'])
    parentParser._defaults = {x:true} # test the propagation to child

    childParser = new ArgumentParser({description:'child',parents:[parentParser]})
    childParser.addArgument(['--y'])
    childParser.addArgument(['xxx'])
    console.log childParser.formatHelp()
    if 0
        console.log 'parent:',util.inspect(parentParser,false,0)
        console.log 'child:',util.inspect(childParser,false,0)
        console.log 'child optional actions:\n',util.inspect((action.dest for action in     childParser._optionals._groupActions),false,1)
        console.log 'child positional actions:\n',util.inspect((action.dest for action in   childParser._positionals._groupActions),false,1)
        console.log '_get_kwargs',parentParser._get_kwargs()
        # _actions is shared among parser and groups
        # _groupActions are different
        # console.log (action.dest for action in childParser._get_optional_actions())
    console.log '====================================='

if TEST and 0
    int1 = (arg) ->
        result = parseInt(arg,10)
        if (isNaN(result))
            throw new TypeError("#{arg} is not a valid integer")
        return result

    parser = new ArgumentParser() #{debug:true})
    #parser.addArgument(['pos'],{nargs:'+',type:'float'})
    #parser.addArgument(['pos'],{type:'float',defaultValue:0.0})
    parser.add_argument('foo', {nargs:'*', defaultValue:42})
    parser.addArgument(['-x','--xxx'],{action:'storeTrue'})
    parser.addArgument(['-y'],{dest:'yyy', nargs:1})
    parser.add_argument('-z','--zzz',{action:'storeFalse'})
    parser.add_argument('-d',{defaultValue:'DEFAULT'})

    if process.argv.length==2
        argv = ['123.5']
        argv = ['-xz','123']
    else
        argv = null
    #console.log parser
    console.log parser.parse_known_args(argv)

    args = parser.parseArgs(argv)
    console.log args
    # test python like namespace fns
    console.log getattr(args,'pos')
    console.log getattr(args,'foo','missing'), hasattr(args,'foo')
    setattr(args,'foo','found')
    console.log getattr(args,'foo'), args
    console.log '====================================='
if TEST and 1
    parser = new ArgumentParser({debug: true});
    #parser.add_argument('-x', {action:'storeTrue'})
    #parser.add_argument('foobar')
    subparsers = parser.addSubparsers({
        title: 'subcommands',
        dest: 'subcommand_name'
    });
    c1 = subparsers.addParser('c1', {aliases: ['co']});
    c1.addArgument([ '-f', '--foo' ], {});
    c1.addArgument([ '-b', '--bar' ], {});
    c2 = subparsers.addParser('c2', {});
    c2.addArgument([ '--baz' ], {});
    try
      Nsp = new Namespace()
      Nsp.set('dummy','foobar')
      args = parser.parse_args('c1 --foo 5'.split(' '), Nsp)
      args = parser.parseArgs('c1 --foo 5'.split(' '), Nsp);
      # args = parser.parseArgs('-x c2'.split(' '))
      console.log args
    catch error

    parser.printHelp()
    try
      parser.parseArgs(['-h'])
    catch error
    try
      parser.parseArgs(['c1','-h'])
    catch error
      DEBUG error
    try
      parser.parseArgs(['c2','-h'])
    catch error
    console.log '====================================='
if TEST and 0
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-1'], {dest: 'one'});
    parser.addArgument(['foo'], {nargs: '?'});
    # negative number options present, so -1 is an option
    parser.parseArgs(['-h'])
    args = parser.parseArgs(['-1', 'X']);
    # Namespace(foo=None, one='X')
    assert.equal(args.one, 'X');
    # negative number options present, so -2 is an option
    testparse(['FOO'])
    testparse(['-z'])
    testparse(['-2'])

    console.log '====================================='
if TEST and 0
  parser = new ArgumentParser({debug: true});
  parser.addArgument(['-x'],{type:'float'});
  parser.addArgument(['-3'],{type:'float', dest:'y'})
  parser.addArgument(['z'],{nargs:'*'})
  args = parser.parse_args(['-2'])
  console.log args

# TODO args from files


