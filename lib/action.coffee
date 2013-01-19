
if not module.parent?
    DEBUG = (arg...) ->
      arg.unshift('A===> ')
      console.log arg...
else
    DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

adir = './'
# adir = '../node_modules/argparse/lib/'

# Constants
$$ = require(adir+'const');


# ==============
# Action classes
# ==============

class Action
    # py uses an _AttributeHolder to provide a format
    ###Information about how to convert command line strings to Python objects.

    Action objects are used by an ArgumentParser to represent the information
    needed to parse a single argument from one or more strings from the
    command line. The keyword arguments to the Action constructor are also
    all attributes of Action instances.

    Keyword Arguments:

        - option_strings -- A list of command-line option strings which
            should be associated with this action.

        - dest -- The name of the attribute to hold the created object(s)

        - nargs -- The number of command-line arguments that should be
            consumed. By default, one argument will be consumed and a single
            value will be produced.  Other values include:
                - N (an integer) consumes N arguments (and produces a list)
                - '?' consumes zero or one arguments
                - '*' consumes zero or more arguments (and produces a list)
                - '+' consumes one or more arguments (and produces a list)
            Note that the difference between the default and nargs=1 is that
            with the default, a single value will be produced, while with
            nargs=1, a list containing a single value will be produced.

        - constant -- The value to be produced if the option is specified and the
            option uses an action that takes no values.

        - defaultValue -- The value to be produced if the option is not specified.

        - type -- The type which the command-line arguments should be converted
            to, should be one of 'string', 'int', 'float', 'complex' or a
            callable object that accepts a single string argument. If null,
            'string' is assumed.

        - choices -- A container of values that should be allowed. If not null,
            after a command-line argument has been converted to the appropriate
            type, an exception will be raised if it is not a member of this
            collection.

        - required -- True if the action must always be specified at the
            command line. This is only meaningful for optional command-line
            arguments.

        - help -- The help string describing the argument.

        - metavar -- The name to be used for the options argument with the
            help string. If null, the 'dest' value will be used as the name.
    ###

    constructor: (options) ->
        @optionStrings = options.option_strings ? options.optionStrings ? []
        @dest = options.dest ? ''
        @nargs = options.nargs ? null
        @constant = options.constant ? null
        @defaultValue = options. defaultValue ? null
        @type = options.type ? null
        @choices = options.choices ? null
        @required = options.required ? false
        @help = options.help ? null
        @metavar = options.metavar ? null

    ###
    def _get_kwargs(self):
        names = [
            'option_strings',
            'dest',
            'nargs',
            'constant',
            'defaultValue',
            'type',
            'choices',
            'help',
            'metavar',
        ]
        return [(name, getattr(self, name)) for name in names]
    ###
    __call__: (parser, namespace, values, option_string=null) ->
        throw new Error(_('.__call__() not defined'))
    call: (parser, namespace, values, option_string=null) ->
        @__call__(parser, namespace, values, option_string=null)

    getName: () ->
        # not in py, but used by the JS version that this was built on
        # is this unique enough to use as hash key?
        if @optionStrings.length>0
            @.optionStrings.join('/')
        else if @metavar ? @.metavar != $$.SUPPRESS
            @.metavar
        else if @dest ? @dest != $$.SUPPRESS
            @.dest
            
    isOptional: () ->
        # convenience used by argparse
        not @isPositional()
        
    isPositional: () ->
        @optionStrings.length == 0

class _StoreAction extends Action

    constructor: (options) ->
        if options.nargs == 0
            throw new Error('nargs for store actions must be > 0; if you ' +\
                             'have nothing to store, actions such as store ' +\
                             'true or store constant may be more appropriate')
        if options.constant? and options.nargs != $$.OPTIONAL
            throw new Error("nargs must be #{$$.OPTIONAL} to supply constant")
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        namespace.set(@dest, values)

class _StoreConstAction extends Action

    constructor: (options) ->
        options.nargs = 0
        options.constant ?= options.const
        # const is a JS keyword
        if not options.constant?
            throw new Error('StoreConstAction needs a constant parameter')
        # type, choices ignored (error if given?)
        super(options)
        
    __call__: (parser, namespace, values, option_string=null) ->
        namespace.set(@dest, @constant)

class _StoreTrueAction extends _StoreConstAction

    constructor: (options) ->
        options.constant = true
        options.defaultValue ?= false
        super(options)

class _StoreFalseAction extends _StoreConstAction

    constructor: (options) ->
        options.constant = false
        options.defaultValue ?= true
        super(options)

class _AppendAction extends Action

    constructor: (options) ->
        if options.nargs == 0
            throw new Error('nargs for append actions must be > 0; if arg ' + \
                             'strings are not supplying the value to append, ' + \
                             'the append constant action may be more appropriate')
        if options.constant? and options.nargs != $$.OPTIONAL
            throw new Error("nargs must be #{$$.OPTIONAL} to supply constant")
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        DEBUG namespace
        DEBUG _ensure_value(namespace, @dest, [])
        items = _.clone(_ensure_value(namespace, @dest, []))
        items.push(values)
        namespace.set(@dest, items)
        

class _AppendConstAction extends Action

    constructor: (options) ->
        options.nargs = 0
        options.constant ?= options.const
        if options.constant?
            super(options)
        else
            throw new Error('constant required for AppendConstAction')

    __call__: (parser, namespace, values, option_string=null) ->
        items = _.clone(_ensure_value(namespace, @dest, []))
        items.push(@constant)
        namespace.set(@dest, items)


class _CountAction extends Action

    constructor: (options) ->
        # nargs ignored
        options.nargs = 0
        # constant, type, choices ignmored
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        new_count = _ensure_value(namespace, @dest, 0) + 1
        namespace.set(@dest, new_count)


class _HelpAction extends Action

    constructor: (options) ->
        options.dest ?= $$.SUPPRESS
        options.defaultValue ?= $$.SUPPRESS
        options.nargs = 0
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        parser.print_help()
        if parser.debug
            console.log 'Help pseudo exit'
            parser.exit()
        else
            parser.exit()


class _VersionAction extends Action

    constructor: (options) ->
        options.version ?=null
        options.dest ?= $$.SUPPRESS
        options.defaultValue ?= $$.SUPPRESS
        options.help ?="show program's version number and exit"
        super(options)
        @version = options.version

    __call__: (parser, namespace, values, option_string=null) ->
        version = @version
        version ?= parser.version
        formatter = parser._get_formatter()
        formatter.add_text(version)
        parser.exit(formatter.format_help())


class _SubParsersAction extends Action

    class _ChoicesPseudoAction extends Action

        constructor: (name, aliases, help) -> 
            metavar = dest = name
            if aliases.length>0
              metavar += " (#{aliases.join(', ')})"
            options = {option_strings:[], dest:name, help:help, metavar:metavar}
            super(options)
    
    constructor: (options) ->
        @_prog_prefix = options.prog
        @_parser_class = options.parser_class ? options.parserClass
        @_name_parser_map = {} # _collections.OrderedDict()
        @_choices_actions = []

        options.dest = options.dest ? $$.SUPPRESS
        options.nargs = $$.PARSER
        options.choices = @_name_parser_map
        super(options)
        @debug = options.debug

    add_parser: (name, options) ->
        # set prog from the existing prefix
        options ?= {}
        options.prog ?= "#{@_prog_prefix} #{name}"
        if options.aliases?
            aliases = options.aliases
            delete options.aliases
        else
            aliases = []
        options.debug ?= @debug # passed via group
        
        # create a pseudo-action to hold the choice help
        if options.help?
            help = options.help
            delete options.help
            choice_action = new _ChoicesPseudoAction(name, aliases, help)
            @_choices_actions.push(choice_action)

        # create the parser and add it to the map
        parser = new @_parser_class(options)
        @_name_parser_map[name] = parser
        
        # make parser available under aliases also
        for alias in aliases
            @._name_parser_map[alias] = parser
            
        return parser
    addParser: (name, options) -> @add_parser(name, options)

    _get_subactions: () =>
        @_choices_actions  # a list
    _getSubactions: () => @_get_subactions() # for formatter.js

    __call__: (parser, namespace, values, option_string=null) ->
        parser_name = values[0]
        arg_strings = values[1..]

        # set the parser name if requested
        if @dest != $$.SUPPRESS
            namespace.set(@dest, parser_name)

        # select the parser
        parser = @_name_parser_map[parser_name] ? null
        if parser == null
            choices = _.keys(@.name_parser.map).join(', ')
            msg = "unknown parser #{parse_name} (choices: #{choices})"
            throw new Error(msg)

        # parse all the remaining options into the namespace
        # store any unrecognized options on the object, so that the top
        # level parser can decide what to do with them
        [namespace, arg_strings] = parser.parse_known_args(arg_strings, namespace)
        if arg_strings.length>0
            if not namespace[$$._UNRECOGNIZED_ARGS_ATTR]?
              namespace[$$._UNRECOGNIZED_ARGS_ATTR] = []
            for astring in arg_strings
              namespace[$$._UNRECOGNIZED_ARGS_ATTR].push(astring)

_ensure_value = (namespace, name, value) ->
    if getattr(namespace, name, null) is null
        setattr(namespace, name, value)
    return getattr(namespace, name)
    
exports.ActionHelp = _HelpAction
exports.ActionAppend = _AppendAction
exports.ActionAppendConstant = _AppendConstAction
exports.ActionCount = _CountAction
exports.ActionStore = _StoreAction
exports.ActionStoreConstant = _StoreConstAction
exports.ActionStoreTrue = _StoreTrueAction
exports.ActionStoreFalse = _StoreFalseAction
exports.ActionVersion = _VersionAction
exports.ActionSubparsers = _SubParsersAction

    
# basic methods in Python, used to access Namespace 
# with these do we need a special Namespace class?
getattr = (obj, key, defaultValue) ->
    obj[key] ? defaultValue
setattr = (obj, key, value) ->
    obj[key] = value
hasattr = (obj, key) ->
    obj[key]?

class Namespace
Namespace::isset = (key) ->
    this[key]?
Namespace::get = (key, defaultValue) ->
    this[key] ? defaultValue
Namespace::set = (key, value) ->
  this[key] = value 
Namespace::repr = () ->
    'Namespace'+ util.inspect(@)
    
# should I make None a syn of null?

if not module.parent?
  console.log action = new Action({help:'testing Action'})
  console.log action = new _StoreAction({dest:'xxx',help:'testing StoreAction'})
  action.call(null, namespace = new Namespace(), 1); console.log namespace
  console.log action = new _StoreConstAction({dest:'xxx',help:'testing StoreConstAction',constant:4})
  action.call(null, namespace = new Namespace()); console.log namespace
  console.log action = new _StoreTrueAction({dest:'xxx',help:'testing storeTrue'})
  action.call(null, namespace = new Namespace()); console.log namespace
  console.log action = new _StoreFalseAction({dest:'xxx',help:'testing storeFalse'})
  action.call(null, namespace = new Namespace()); console.log namespace
  
  console.log action = new _AppendAction({dest:'xxx',help:'testing AppendAction',constant:'x',nargs:'?'})
  namespace = new Namespace(); namespace.set('xxx',[2,3])
  action.call(null, namespace, 1); console.log namespace
  
  console.log action = new _AppendConstAction({dest:'xxx',constant:0, help:'testing AppendConstAction',nargs:'?'})
  action.call(null, namespace, 1); console.log namespace
  console.log action = new _CountAction({dest:'xxx',help:'testing CountAction',nargs:'?'})
  action.call(null, namespace=new Namespace()); console.log namespace
  action.call(null, namespace); console.log namespace
  
  parser = {}; parser.debug=false
  parser.print_help = ()->console.log "HELP"
  parser.exit = (msg='') -> console.log "EXIT", msg
  console.log 'parser', parser
  console.log action = new _HelpAction({})
  action.call(parser)
  parser._get_formatter = () -> 
    formatter  = {}
    formatter.add_text = (@text) -> 
    formatter.format_help = () -> "help;version #{@text}"
    formatter
  console.log action = new _VersionAction({version:'1.2.3'})
  action.call(parser)

  
