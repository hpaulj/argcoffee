###
 * class ArgumentParser
 *
 * Object for parsing command line strings into js objects.
 *
 * Inherited from [[ActionContainer]]
 ###
DEBUG = console.log
DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

# other argparse
adir = './'
adir = '../node_modules/argparse/lib/'
$$ = require(adir+'const')
ActionContainer = require(adir+'action_container')
argumentaErrorHelper = require(adir+'argument/error')
HelpFormatter = require(adir+'help/formatter')
Namespace = require(adir+'namespace')

# redefine a couple of namespace methods
Namespace::isset = (key) ->
    this[key]?
Namespace::get = (key, defaultValue) ->
    this[key] ? defaultValue
    
# argparse separates these exports from definion of ArgumentParser
exports.Namespace = Namespace
exports.HelpFormatter = HelpFormatter
exports.Const = $$
exports.Action = require(adir+'action')


# cast ActionContainer into the Coffeescript 'class' form
class _ActionsContainer extends ActionContainer
util.inherits(_ActionsContainer, ActionContainer)

class ArgumentParser extends _ActionsContainer
    constructor: (options={}) ->
        @prog=options.prog ? process.argv[0] # basename    
        @usage=options.usage ? null    
        @epilog=options.epilog ? null
        @parents=options.parents ? []
        @formatter_class=options.formatter_class ? HelpFormatter
        @fromfile_prefix_chars = options.fromfile_prefix_chars ? null
        @add_help = options.add_help ? true
        @debug = options.debug ? false
    
        @description=options.description ? null
        @prefix_chars=options.prefix_chars ? '-'
        @argument_default=options.argument_default ? null
        @conflict_handler=options.conflict_handler ? 'error'
        acoptions = {
            description: @description,
            prefixChars: @prefix_chars,
            argumentDefault: @argument_default, # AC uses cammelcase
            conflictHandler: @conflict_handler}
        _ActionsContainer.call(this, acoptions)
        @_positionals = @addArgumentGroup({title: 'Positional arguments'})
        @_optionals = @addArgumentGroup({title: 'Optional arguments'})
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

        default_prefix = '-' # or from prefixChars
        if @add_help
            @.addArgument([default_prefix+'h', default_prefix+default_prefix+'help'],\
                {action:'help', 
                defaultValue:$$.SUPPRESS, # of default of the action already
                help:'Show this help message and exit'  # _()
            })
        # @version
        # can I test this now?
        for parent in @parents
            @_addContainerActions(parent)
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

        options.debug = @debug
        options.optionStrings = []
        options.parserClass = (options.parserClass || ArgumentParser)
        
        # add the parser class to the arguments if it's not present
        #?options.setdefault('parser_class', type(self))

        if options.title? or options.description?
            title = options.title ?  'subcommands'
            description = options.description ? null
            delete options.title
            delete options.description
            @_subparsers = @addArgumentGroup({title: title, description: description})
        else
            @_subparsers = @_positionals

        # prog defaults to the usage message of this parser, skipping
        # optional arguments and with no "usage:" prefix
        if not options.prog?
            formatter = @_getFormatter()
            positionals = @_get_positional_actions()
            groups = @_mutually_exclusive_groups
            formatter.addUsage(@usage, positionals, groups, '')
            options['prog'] = _.str.strip(formatter.formatHelp())

        # create the parsers action and add it to the positionals list
        ParsersClass = @_popActionClass(options, 'parsers')
        action = new ParsersClass(options)
        @_subparsers._addAction(action)

        # return the created parsers action
        return action

    _addAction: (action) ->   # use camel because AC does
        if action.isOptional() # option_strings
            DEBUG 'opt action:',action.dest
            this._optionals._addAction(action)
        else
            DEBUG 'pos action:',action.dest
            this._positionals._addAction(action)
        return action
    
    _get_optional_actions: () ->
        return (action for action in this._actions when action.isOptional())
        
    _get_positional_actions: () ->
        return (action for action in this._actions when not action.isOptional())
        
    # =====================================
    # Command line argument parsing methods
    # =====================================
    parse_args: (args=null, namespace=null) ->
        [args, argv] = @parse_known_args(args, namespace)
        if argv.length>0
            msg = "unrecognized arguments #{argv.join(' ')}"
            @error(msg)
        return args
        
    parse_known_args: (args=null, namespace=null) ->
        # args default to system args
        args = args || process.argv[2...]
            
        # default Namespace built from parser defaults
        namespace = namespace ? new Namespace()
        DEBUG 'namespace:', namespace
            
        # add any action defaults that aren't present
        for action in @_actions
            if action.dest in not $$.SUPPRESS
                if not namespace.isset(action.dest)
                    if action.default is not $$.SUPPRESS
                        _default = action.default
                        if _.isString(_default)
                            _default = @_get_value(action, _default)
                        namespace.set(action.dest, _default)
        
        # add any parse defaults that aren't present
        for dest of @_defaults
            if not namespace.isset(dest)
                namespace.set(dest, @_defaults[dest])
        
        # parse the arguments and exit if there are any errors
        if true  # try
            DEBUG 'initial args, namespace:', args, namespace
            [namespace, args] = @_parse_known_args(args, namespace)
            if namespace.isset($$._UNRECOGNIZED_ARGS_ATTR)
                args.push(namespace.get($$._UNRECOGNIZED_ARGS_ATTR))
                namespace.unset($$._UNRECOGNIZED_ARGS_ATTR, null)
            return [namespace, args]
                
        else  # catch error
            @error(''+error)
            
        argv = []
        return [args, argv]
        
    _parse_known_args: (arg_strings, namespace) ->
        # replace arg strings that are file references
        if @fromfile_prefix_chars?
            arg_strings = @_read_args_from_files(arg_strings) # stub
            
        # map all mutually exclusive arguments to the other arguments
        # they can't occur with
        action_conflicts = {}        
        ###
        for mutex_group in self._mutually_exclusive_groups:
            group_actions = mutex_group._group_actions
            for i, mutex_action in enumerate(mutex_group._group_actions):
                conflicts = action_conflicts.setdefault(mutex_action, [])
                conflicts.extend(group_actions[:i])
                conflicts.extend(group_actions[i + 1:])
        ###
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
        seen_actions = {} # set()
        seen_non_default_actions = {} #set()
        
        take_action = (action, argument_strings, option_string=null) =>
            seen_actions[action.dest] = true # .add(action)
            argument_values = @_get_values(action, argument_strings)

            # error if this argument is not allowed with other previously
            # seen arguments, assuming that actions that use the default
            # value don't really count as "present"
            if argument_values is not action.default
                seen_non_default_actions[action.dest] = true #.add(action)
                ### skip conflicts for now
                for conflict_action in action_conflicts.get(action, []):
                    if conflict_action in seen_non_default_actions:
                        msg = _('not allowed with argument %s')
                        action_name = _get_action_name(conflict_action)
                        raise ArgumentError(action, msg % action_name)
                ###
            # take the action if we didn't receive a SUPPRESS value
            # (e.g. from a default)
            if argument_values != $$.SUPPRESS
                action.call(@, namespace, argument_values, option_string)
                DEBUG 'takenaction:',action.dest,namespace, argument_values, option_string
                
        consume_optional = (start_index) =>
            # get the optional identified at this index
            option_tuple = option_string_indices[start_index]
            [action, option_string, explicit_arg] = option_tuple

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
                if explicit_arg is not null
                    arg_count = match_argument(action, 'A')

                    # if the action is a single-dash option and takes no
                    # arguments, try to parse more single-dash options out
                    # of the tail of the option string
                    chars = @prefix_chars
                    if arg_count == 0 and option_string[1] not in chars
                        action_tuples.push([action, [], option_string])
                        char = option_string[0]
                        option_string = char + explicit_arg[0]
                        new_explicit_arg = explicit_arg[1...] ? null 
                        optionals_map = @_option_string_actions
                        if optionals_map[option_string]?
                            action = optionals_map[option_string]
                            explicit_arg = new_explicit_arg
                        else
                            msg = "ignored explicit argument #{explicit_arg}"
                            @error(action, msg)

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
                        @error(action, msg)

                # if there is no explicit argument, try to match the
                # optional's string arguments with the following strings
                # if successful, exit the loop
                else
                    start = start_index + 1
                    selected_patterns = arg_string_pattern[start...]
                    arg_count = match_argument(action, selected_patterns)
                    stop = start + arg_count
                    args = arg_strings[start...stop]
                    action_tuples.push([action, args, option_string])
                    break

            # add the Optional to the list and return the index at which
            # the Optional's string args stopped
            # assert action_tuples
            for [action, args, option_string] in action_tuples
                take_action(action, args, option_string)
            return stop

        # the list of Positionals left to be parsed; this is modified
        # by consume_positionals()
        positionals = @_get_positional_actions()

        # function to convert arg_strings into positional actions
        consume_positionals = (start_index) =>
            # match as many Positionals as possible
            DEBUG '#positionals start:',positionals.length
            match_partial = @_match_arguments_partial 
            selected_pattern = arg_string_pattern[start_index...]
            DEBUG 'cp',selected_pattern
            arg_counts = match_partial(positionals, selected_pattern)

            # slice off the appropriate arg strings for each Positional
            # and add the Positional and its args to the list
            DEBUG 'positionals:',(a.dest for a in positionals)
            DEBUG 'arg count:',arg_counts
            #DEBUG _.zip(positionals, arg_counts)
            for [action, arg_count] in _.zip(positionals, arg_counts)
                DEBUG 'zip action:',action.dest
                DEBUG 'zip argcount:',arg_count
                args = arg_strings[start_index...start_index + arg_count]
                start_index += arg_count
                DEBUG 'take action:',action.dest,args
                take_action(action, args)

            # slice off the Positionals that we just parsed and return the
            # index at which the Positionals' string args stopped
            positionals[..] = positionals[arg_counts.length...]
            DEBUG '#positionals left:',positionals.length
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
        DEBUG 'index',option_string_indices, max_option_string_index
        while start_index <= max_option_string_index

            # consume any Positionals preceding the next option
            next_option_string_index = Math.min((index for index in index_keys when index >= start_index)...)
            if start_index != next_option_string_index
                DEBUG 'start index:',start_index
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
            start_index = consume_optional(start_index)

        # consume any positionals following the last Optional
        stop_index = consume_positionals(start_index)

        # if we didn't consume all the argument strings, there were extras
        extras.push(arg_strings[stop_index..]...)

        # if we didn't use all the Positional objects, there were too few
        # arg strings supplied.
        if positionals.length>0
            @error('too few arguments')

        # make sure all required actions were present
        for action in @_actions
            if action.required
                if action.dest not in _.keys(seen_actions)
                    name = _get_action_name(action)
                    @error("argument #{name} is required")
        ###
        # make sure all required groups had one option present
        for group in self._mutually_exclusive_groups:
            if group.required:
                for action in group._group_actions:
                    if action in seen_non_default_actions:
                        break

                # if no actions were used, report the error
                else:
                    names = [_get_action_name(action)
                             for action in group._group_actions
                             if action.help is not SUPPRESS]
                    msg = _('one of the arguments %s is required')
                    self.error(msg % ' '.join(names))
        ###

        DEBUG [namespace, extras]
        return [namespace, extras]
        
    # def _read_args_from_files(self, arg_strings):
    #    stub
    
    convert_arg_line_to_args: (arg_line) ->
        return [arg_line] # no split?
    
    _match_argument: (action, arg_strings_pattern) =>
        # match the pattern for this action to the arg strings
        nargs_pattern = @_get_nargs_pattern(action)
        # match = _re.match(nargs_pattern, arg_strings_pattern)
        matches = arg_strings_pattern.match(nargs_pattern)

        # raise an exception if we weren't able to find a match
        if not matches?
            args_errors = {null: 'expected one argument'}
            args_errors[$$.OPTIONAL] = 'expected at most one argument'
            args_errors[$$.ONE_OR_MORE] = 'expected at least one argument'
            msg = args_errors[action.nargs] ? "expected #{action.nargs} argument(s)"
            msg = "#{msg} for action #{action.dest}"
            @error(msg)

        # return the number of arguments matched
        return matches[1].length

    _match_arguments_partial: (actions, arg_strings_pattern) =>
        # progressively shorten the actions list by slicing off the
        # final actions until we find a match
        result = []
        #foo = get_nargs_pattern # @_get... not found
        # DEBUG 'foo',foo
        DEBUG 'actions:',(a.dest for a in actions)
        DEBUG 'arg strings pattern:',arg_strings_pattern
        foo = @_get_nargs_pattern 
        for i in [actions.length..0]
            actions_slice = actions[...i]
            pattern = (foo(action) for action in actions_slice).join('')
            m = arg_strings_pattern.match(pattern)
            DEBUG 'pattern:',pattern
            DEBUG 'matches:',m
            if m?
                m = m[1...]
                result.push((string.length for string in m)...)
                break
                # 
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
        if @_optionStringActions[arg_string]?
            action = @_optionStringActions[arg_string]
            return [action, arg_string, null]

        # if it's just a single character, it was meant to be positional
        if arg_string.length == 1
            return null

        # if the option string before the "=" is present, return the action
        if '=' in arg_string
            [option_string, explicit_arg] = arg_string.split('=')
            # may be a difference in 'split limit' between languages
            if @_optionStringActions[option_string]?
                action = @_optionStringActions[option_string]
                return [action, option_string, explicit_arg]

        # search through all possible prefixes of the option string
        # and all actions in the parser for possible interpretations
        option_tuples = @_get_option_tuples(arg_string)

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
        # if @_regexpNegativeNumber.match(arg_string)
        if arg_string.match(@_regexpNegativeNumber)
            if not _.any(@_has_negative_number_optionals)
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
            for option_string of @_option_string_actions
                if _.str.startsWith(option_string, option_prefix)
                    action = @_option_string_actions[option_string]
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

            for option_string of @_option_string_actions
                if option_string == short_option_prefix
                    action = @_option_string_actions[option_string]
                    tup = [action, option_string, short_explicit_arg]
                    result.push(tup)
                else if _.str.startsWith(option_string,option_prefix)
                    action = @_option_string_actions[option_string]
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
        if action.option_strings
            nargs_pattern = nargs_pattern.replace('-*', '')
            nargs_pattern = nargs_pattern.replace('-', '')

        # return the pattern
        DEBUG nargs, nargs_pattern
        return nargs_pattern
    
    # ========================
    # Value conversion methods
    # ========================
    _get_values: (action, arg_strings) ->
        # for everything but PARSER args, strip out '--'
        if action.nargs not in [$$.PARSER, $$.REMAINDER]
            arg_strings = (s for s in arg_strings when s != '--')

        # optional argument produces a default when not present
        if not arg_strings and action.nargs == $$.OPTIONAL
            if action.option_strings
                value = action.const
            else
                value = action.default
            if _.isString(value)
                value = @_get_value(action, value)
                @_check_value(action, value)

        # when nargs='*' on a positional, if there were no command-line
        # args, use the default if it is anything other than null
        else if (not arg_strings and action.nargs == $$.ZERO_OR_MORE and not action.option_strings)
            if action.default is not null
                value = action.default
            else
                value = arg_strings
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
            @error(action, msg)

        # convert the value to the appropriate type
        try
            result = type_func(arg_string)
        catch error
            @error(error)
        ###    
        # ArgumentTypeErrors indicate errors
        except ArgumentTypeError:
            name = getattr(action.type, '__name__', repr(action.type))
            msg = str(_sys.exc_info()[1])
            raise ArgumentError(action, msg)

        # TypeErrors or ValueErrors also indicate errors
        except (TypeError, ValueError):
            name = getattr(action.type, '__name__', repr(action.type))
            msg = _('invalid %s value: %r')
            raise ArgumentError(action, msg % (name, arg_string))
        ###
        # return the converted value
        return result

    _check_value: (action, value) ->
        # converted value must be one of the choices (if specified)
        if action.choices is not null and value not in action.choices
            # tup = value, ', '.join(map(repr, action.choices))
            msg = "invalid choice: #{value} (choose from #{action.choices})"
            @error(action, msg)
            
    # ===============
    # Help formatting methods
    # ===============
    # adapt from javascript version   
    
    format_usage: () ->
        formatter = @_getFormatter()
        formatter.addUsage(@usage, @_actions, [])
        return formatter.formatHelp()
    
    format_help: () ->
        formatter = @_getFormatter()
        # usage
        formatter.addUsage(@usage, @_actions, [])
        formatter.addText(@description)
        for actionGroup in @_actionGroups
            formatter.startSection(actionGroup.title)
            formatter.addText(actionGroup.description)
            formatter.addArguments(actionGroup._groupActions)
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
                throw err
            message = err.message
        else
            message = err
        msg = "#{@prog}: error: #{message}#{$$.EOL}"
        if @debug
            throw new Error(msg)
        @print_usage(process.stderr)
        return @exit(2,msg)
    
    exit: (status, message) ->
        if message?
            if status==0
                @_printMessage(message)
            else
                @_printMessage(message, process.stderr)
        process.exit(status)
        
    _printMessage: (message, stream=process.stdout) ->
        if message
            stream.write('' + message)
            
    # ===============
    # CamelCase Aliases
    # ===============
    parseArgs: (args) -> @parse_args(args)  
    parseKnownArgs: (args) -> @parse_known_args(args)
    add_argument: (args..., options) ->
        # Python like arguments; 
        # options still needs to be specified, even if only {}
        @addArgument(args, options)
        
# =====================
# Options and Arguments
# =====================

_get_action_name = (argument) ->
    if argument is null
        return null
    else if argument.option_strings
        return  argument.option_strings.join('/')
    else if argument.metavar not in [null, $$.SUPPRESS]
        return argument.metavar
    else if argument.dest not in [null, $$.SUPPRESS]
        return argument.dest
    else
        return null

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
        - bufsize -- The file's desired buffer size. Accepts the same values as
            the builtin open() function.
    ###
    fs = require('fs') # nodejs
    constructor: (@mode='r') ->
        # py uses mode, nodejs uses flags
        # py uses a bufsize, nodejs does not
        # nodejs has nonsyn version of open, but that requires a callback
        # with nodejs emphasis on nonsyc operations, this class might not be that useful
        # requires a new; maybe make a factory fn

    call: (string) ->
        # the special argument "-" means sys.std{in,out}
        openfn = fs.openSync
        if string == '-'
            if 'r' in @mode
                return process.stdin
            else if 'w' in @mode
                return process.stdout
            else
                msg = "argument '-' with mode #{@mode}"
                raise ValueError(msg)

        # all other arguments are used as file names
        return openfn(string, @mode)

FileType = (mode) ->
    # callable fun that can be used by Action store
    ft = new FileClass(mode)
    fn = (string) ->
        ft.call(string)
    return fn
# use: parser.add_argument('--outfile',{type:ap.FileType('w')})
# args.outfile should then be a writable filehandle
exports.FileType = FileType
        



TEST = if not module.parent? then true else false
if TEST and 0       
    parser = new ArgumentParser()
    console.log 'obj:',util.inspect(parser,false,0)
    parser.format_help()
    parser.add_subparsers({})
    console.log 'class:', 
    console.log ArgumentParser
    console.log 'proto'
    console.log ArgumentParser.prototype
    console.log ArgumentParser.prototype.constructor.super_

    #console.log parser.formatHelp()

if TEST and 0
    parentParser = new ArgumentParser({add_help: false, description: 'parent'})
    parentParser.addArgument(['--x'])
    parentParser._defaults = {x:true} # test the propagation to child
    
    childParser = new ArgumentParser({description:'child',parents:[parentParser]})
    childParser.addArgument(['--y'])
    childParser.addArgument(['xxx'])
    #console.log childParser.formatHelp()
    if 0
        console.log 'parent:',util.inspect(parentParser,false,0)
        console.log 'child:',util.inspect(childParser,false,0)
        console.log 'child optional actions:\n',util.inspect((action.dest for action in     childParser._optionals._groupActions),false,1)
        console.log 'child positional actions:\n',util.inspect((action.dest for action in   childParser._positionals._groupActions),false,1)
        console.log '_get_kwargs',parentParser._get_kwargs()
        # _actions is shared among parser and groups
        # _groupActions are different
        # console.log (action.dest for action in childParser._get_optional_actions())

if TEST and 1
    int1 = (arg) ->
        result = parseInt(arg,10)
        if (isNaN(result))
            throw new TypeError("#{arg} is not a valid integer")
        return result

    parser = new ArgumentParser() #{debug:true})
    parser.addArgument(['pos'],{nargs:'+',type:'float'})
    parser.addArgument(['-x','--xxx'],{action:'storeTrue'})
    parser.addArgument(['-y'],{dest:'yyy', nargs:1})
    parser.add_argument('-z','--zzz',{action:'storeTrue'})

    if process.argv.length==2
        argv = ['123.5']
    else 
        argv = null
    console.log parser.parse_known_args(argv)
    args = parser.parseArgs(argv)
    console.log args
    # test python like namespace fns
    console.log getattr(args,'pos')
    console.log getattr(args,'foo','missing'), hasattr(args,'foo')
    setattr(args,'foo','found')
    console.log getattr(args,'foo'), args

# args from files

# py parse_args takes an optional Namespace arg; it can be a simple object
# so why can't it be a JS object?  Do we need the 'set' and 'isset' methods?
# Class Namespace; constructor takes an obj; fn: set, get, isset, unset
# the action subclasses use: namespace.set(this.dest, values)
# c = new Namespace({foo:null,pos:[]})
# parser.parse_args([], c) 
# will set values in c; 
# namespace.set(this.dest, values)
# could change to namespace[this.dest]=values
# (with added ability to set from object, and use 'null' to delete
# get() - getattr with default
# why not equivalents to py setattr,getattr,hasattr,delattr
# also _ensure_value(namespace, self.dest, [])
# var(namespace).setdefault()

# I keep calling parser=ap.ArgumentParser(); omitting the new

# bugs from the doc_examples
# cannot deduce dest from '-x'
# try/catch does not capture parse_args('-h')
# how to print_help for subparser?
# problems with defaults

