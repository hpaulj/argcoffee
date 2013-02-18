###
# class _ActionsContainer
# not meant to be exported to users
# may need to do action group at the same time
###

if not module.parent?
    DEBUG = (arg...) ->
      arg.unshift('====> ')
      console.log arg...
else
    DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

# Constants
$$ = require('./const');
{ArgumentError} = require('./error')

# Actions
if false
  ActionHelp = require(adir+'action/help');
  ActionAppend = require(adir+'action/append');
  ActionAppendConstant = require(adir+'action/append/constant');
  ActionCount = require(adir+'action/count');
  ActionStore = require(adir+'action/store');
  ActionStoreConstant = require(adir+'action/store/constant');
  ActionStoreTrue = require(adir+'action/store/true');
  ActionStoreFalse = require(adir+'action/store/false');
  ActionVersion = require(adir+'action/version');
  ActionSubparsers = require(adir+'action/subparsers');
else
  action = require('./action')
  ActionHelp = action.ActionHelp
  ActionAppend = action.ActionAppend
  ActionAppendConstant = action.ActionAppendConstant
  ActionCount = action.ActionCount
  ActionStore = action.ActionStore
  ActionStoreConstant = action.ActionStoreConstant
  ActionStoreTrue = action.ActionStoreTrue
  ActionStoreFalse = action.ActionStoreFalse
  ActionVersion = action.ActionVersion
  ActionSubparsers = action.ActionSubparsers

class _ActionsContainer
  constructor: (options={}) ->
    # description, prefixChars, argument_default, conflictHandler):
    # super(_ActionsContainer, self).__init__()

        @description = options.description
        @argument_default = options.argument_default
        @prefix_chars = options.prefixChars ? options.prefix_chars
        @conflictHandler = options.conflictHandler

        # set up registries
        @_registries = {}

        # register actions
        this.register('action', null, ActionStore);
        this.register('action', 'store', ActionStore);
        this.register('action', 'storeConst', ActionStoreConstant);
        this.register('action', 'store_const', ActionStoreConstant);
        this.register('action', 'storeTrue', ActionStoreTrue);
        this.register('action', 'store_true', ActionStoreTrue);
        this.register('action', 'storeFalse', ActionStoreFalse);
        this.register('action', 'store_false', ActionStoreFalse);
        this.register('action', 'append', ActionAppend);
        this.register('action', 'appendConst', ActionAppendConstant);
        this.register('action', 'append_const', ActionAppendConstant);
        this.register('action', 'count', ActionCount);
        this.register('action', 'help', ActionHelp);
        this.register('action', 'version', ActionVersion);
        this.register('action', 'parsers', ActionSubparsers);

        # raise an exception if the conflict handler is invalid
        @_get_handler()

        # action storage
        @_actions = []
        @_option_string_actions = {}

        # groups
        @_action_groups = []
        @_mutually_exclusive_groups = []

        # defaults storage
        @_defaults = {}

        # determines whether an "option" looks like a negative number
        @_negative_number_matcher = /^-\d+$|^-\d*\.\d+$/

        # whether or not there are any optionals that look like negative
        # numbers -- uses a list so it can be shared and edited
        @_hasNegativeNumberOptionals = []
        @

    # ====================
    # Registration methods
    # ====================
  register: (registry_name, value, object) ->
        if not _.has(@_registries, registry_name)
          @_registries[registry_name] = {}
        registry = @_registries[registry_name]
        # registry = @_registries.setdefault(registry_name, {})
        registry[value] = object

  _registry_get:  (registry_name, value, defaultValue=null)->
        # return @_registries[registry_name].get(value, defaultValue)
        return @_registries[registry_name][value] ? defaultValue
  _registryGet: (arg1,arg2,arg3) -> @_registry_get(arg1,arg2,arg3)
    # ==================================
    # Namespace default accessor methods
    # ==================================
  set_defaults: (options) ->
        #@_defaults.update(options)
        _.extend(@_defaults, options)

        # if these defaults match any existing arguments, replace
        # the previous default on the object with the new one
        for action in @_actions
            if action.dest of options
                action.default = options[action.dest]
  setDefaults: (options) -> @set_defaults(options)

  get_default: (dest) ->
        for action in @_actions
            if action.dest == dest and action.defaultValue != null
                return action.defaultValue
        #return @_defaults.get(dest, null)
        return @_defaults[dest] ? null
  getDefault: (dest) -> @get_default(dest)

    # =======================
    # Adding argument actions
    # =======================

  add_argument:  (args..., options) ->
        """
        add_argument(dest, ..., name=value, ...)
        add_argument(option_string, option_string, ..., name=value, ...)
        """
        if _.isString(options)
          # assume
          args.push(options)
          options = {}
        if not options?
          options = {}
        # at this point, args is list of strings (possibly empty)
        # options is an object (py dict)
        DEBUG 'args, options: ', args, options
        # if no positional args are supplied or only one is supplied and
        # it doesn't look like an option string, parse a positional
        # argument

        chars = @prefix_chars
        if args.length==0 or (args.length==1 and args[0][0] not in chars)
            #if not args or len(args) == 1 and args[0][0] not in chars
            if args.length>0 and 'dest' of options
                throw new Error('dest supplied twice for positional argument')
            options = @_get_positional_options(args, options)

        # otherwise, we're adding an optional argument
        else
            options = @_get_optional_options(args, options)

        DEBUG options
        # here options has an option_strings attribute
        # rest of this class expects that
        # but Action expects and returns (empty) option_strings
        # temp fix: duplicate the attribute in options
        # and always use action.option_strings
        # leave options_strings else where
        # positional has [], optional [...]

        # if no default was supplied, use the parser-level default
        if 'defaultValue' not of options
            dest = options['dest']
            if dest of @_defaults
                options['defaultValue'] = @_defaults[dest]
            else if @argument_default != null
                options['defaultValue'] = @argument_default
            else
                options['defaultValue'] = null

        # create the action object, and add it to the parser
        action_class = @_pop_action_class(options)
        # if not _callable(action_class)
        if not _.isFunction(action_class)
            throw new Error("unknown action '#{action_class}'")
        action = new action_class(options)

        # raise an error if the action type is not callable
        type_func = @_registry_get('type', action.type, action.type)
        if not _.isFunction(type_func) # _callable(type_func)
            throw new Error("#{type_func} is not callable")

        # raise an error if the metavar does not match the type
        # if hasattr (this, "_get_formatter")
        if @_get_formatter?
            try
                @_get_formatter()._format_args(action, null)
            catch error
                throw new Error("length of metavar tuple does not match nargs")
        DEBUG 'action', action
        return @_add_action(action)
  addArgument: (args, options) -> @add_argument(args..., options)

  add_argument_group: (options) ->
        group = new _ArgumentGroup(this, options)
        @_action_groups.push(group)
        return group
  addArgumentGroup: (options) -> @add_argument_group(options)

  add_mutually_exclusive_group: (options={}) ->
        group = new _MutuallyExclusiveGroup(this, options)
        @_mutually_exclusive_groups.push(group)
        return group
  addMutuallyExclusiveGroup: (options) -> @add_mutually_exclusive_group(options)

  _add_action: (action) ->
        # resolve any conflicts
        @_check_conflict(action)

        # add to actions list
        @_actions.push(action)
        action.container = this

        # index the action by any option strings it has
        for option_string in action.option_strings
            @_option_string_actions[option_string] = action

        # set the flag if any option strings look like negative numbers
        for option_string in action.option_strings
            if option_string.match(@_negative_number_matcher)
                if not _.any(@_hasNegativeNumberOptionals)
                    @_hasNegativeNumberOptionals.push(true)

        # return the created action
        return action

  _remove_action: (action) ->
        # @_actions.remove(action)
        i = @_actions.indexOf(action)
        if i>=0
          @_actions.splice(i,1)


  _add_container_actions: (container) =>
        # collect groups by titles
        title_group_map = {}
        DEBUG @
        for group in @_action_groups
            if group.title of title_group_map
                msg = "cannot merge actions - two groups are named #{group.title}"
                throw new Error(msg)
            title_group_map[group.title] = group

        # map each action to its group
        group_map = {}
        actionHash = (action) ->
            return action.getName()
        for group in container._action_groups

            # if a group with the title exists, use that, otherwise
            # create a new group matching the container's group
            if group.title not of title_group_map
                title_group_map[group.title] = @add_argument_group({
                    title:group.title,
                    description:group.description,
                    conflictHandler:group.conflictHandler})

            # map the actions to their new group
            for action in group._group_actions
                group_map[actionHash(action)] = title_group_map[group.title]

        # TODO - fix 'get' below; is group_map[action] right?
        # it is in dev

        # add container's mutually exclusive groups
        # NOTE: if add_mutually_exclusive_group ever gains title= and
        # description= then this code will need to be expanded as above
        for group in container._mutually_exclusive_groups
            mutex_group = @add_mutually_exclusive_group(
                required=group.required)

            # map the actions to their new mutex group
            for action in group._group_actions
                group_map[actionHash(action)] = mutex_group

        # add all actions to this container or their group
        for action in container._actions
            # group_map.get(action, self)._add_action(action)
            ctr = group_map[action.getName()] ? this
            ctr._add_action(action)

  _get_positional_options:  (dest, options) ->
        # make sure required is not specified
        if 'required' of options
            msg = "'required' is an invalid argument for positionals"
            throw new TypeError(msg)

        if _.isArray(dest)
          if dest.length==0
            dest = null
          else
            dest = dest[0]

        DEBUG 'in pos', dest, options

        # mark positional arguments as required if at least one is
        # always required
        ###
        if options.get('nargs') not in [$$.OPTIONAL, $$.ZERO_OR_MORE]
            options['required'] = True
        if options.get('nargs') == $$.ZERO_OR_MORE and 'defaultValue' not of options
            options['required'] = True
        ###

        if options.nargs not in [$$.OPTIONAL, $$.ZERO_OR_MORE]
          options.required = true
        else if options.nargs == $$.ZERO_OR_MORE and not options.defaultValue?
          options.required = true
        else
          options.required = false

        # return the keyword arguments with no option strings
        # return dict(options, dest=dest, option_strings=[])
        result = _.clone(options)
        if dest?
          result['dest'] = dest
        result['option_strings'] = []
        return result

  _get_optional_options: (args, options) ->
        # determine short and long option strings
        option_strings = []
        long_option_strings = []
        for option_string in args
            # error on strings that don't start with an appropriate prefix
            if not option_string[0] in @prefix_chars
                msg = "invalid option string #{option_string}: '
                        'must start with a character #{@prefix_chars}"
                throw new Error(msg)

            # strings starting with two prefix characters are long options
            option_strings.push(option_string)
            if option_string[0] in @prefix_chars
                if option_string.length > 1
                    if option_string[1] in @prefix_chars
                        long_option_strings.push(option_string)

        # infer destination, '--foo-bar' -> 'foo_bar' and '-x' -> 'x'
        # dest = options.pop('dest', null)
        if options['dest']?
          dest = options['dest']
          delete options['dest']
        else
          dest = null
        if dest is null
            if long_option_strings.length>0
                dest_option_string = long_option_strings[0]
            else
                dest_option_string = option_strings[0]
            dest = _.str.lstrip(dest_option_string, @prefix_chars)
            if not dest
                msg = "dest= is required for options like #{option_string}"
                throw new Error(msg)
            dest = dest.replace('-', '_')

        # return the updated keyword arguments
        # return dict(options, dest=dest, option_strings=option_strings)
        result = _.clone(options)
        result['dest'] = dest
        result['option_strings'] = option_strings
        return result

  _pop_action_class: (options, defaultValue=null) ->
        # action = options.pop('action', defaultValue)
        if options['action']?
          action = options['action']
          delete options['action']
        else
          action = defaultValue
        return @_registry_get('action', action, action)

  _get_handler: () ->
        # determine function from conflict handler string
        #return @conflictHandler == 'error'
        # skip more elaborate test for now
        handler_func_name = "_handle_conflict_#{@conflictHandler}"
        func = @[handler_func_name]
        if func?
          return func
        else
            msg = "invalid conflict resolution value: #{@conflictHandler}"
            throw new Error(msg)

  _check_conflict: (action) ->
        # find all options that conflict with this option
        confl_optionals = []
        for option_string in action.option_strings
            if option_string of @_option_string_actions
                confl_optional = @_option_string_actions[option_string]
                confl_optionals.push([option_string, confl_optional])

        # resolve any conflicts
        if confl_optionals.length>0
            conflictHandler = @_get_handler()
            conflictHandler(action, confl_optionals)

    _handle_conflict_error: (action, conflicting_actions) ->
        conflict_string = (tpl[0] for tpl in conflicting_actions).join(', ')
        message = "Conflicting option string(s): "+ conflict_string
        # throw new Error(action.getName() + message )
        throw new ArgumentError(action, message)

    _handle_conflict_resolve: (action, conflicting_actions) =>
        # remove all conflicting options
        for [option_string, action] in conflicting_actions
          # remove the conflicting option
          i = action.option_strings.indexOf(option_string)
          if i>=0
            action.option_strings.splice(i,1)
            # array delete is wrong here
          delete @_option_string_actions[option_string]
          # if the option now has no option string, remove it from the
          # container holding it
          if action.option_strings.length==0
            action.container._remove_action(action)

exports._ActionsContainer = _ActionsContainer

class _ArgumentGroup extends _ActionsContainer

    constructor: (container, options={}) ->
        # def __init__(self, container, title=None, description=None, **kwargs):
        # add any missing keyword arguments by checking the container
        options.prefix_chars = options.prefixChars ? container.prefix_chars
        options.argument_default = options.argument_default ? container.argument_default
        options.conflictHandler = options.conflictHandler ? container.conflictHandler

        # super_init = super(_ArgumentGroup, self).__init__
        # _ActionsContainer.call(this, options)
        # super_init(description=description, **kwargs)
        super(options)
        # group attributes
        @title = options.title
        @_group_actions = []
        # share most attributes with the container
        @_registries = container._registries
        @_actions = container._actions
        @_option_string_actions = container._option_string_actions
        @_defaults = container._defaults
        @_hasNegativeNumberOptionals = container._hasNegativeNumberOptionals
        @_mutually_exclusive_groups = container._mutually_exclusive_groups

        @_container = container;

    _add_action: (action) ->
        #action = super(_ArgumentGroup, self)._add_action(action)
        action = super(action)
        @_group_actions.push(action)
        return action

    _remove_action: (action) ->
        #super(_ArgumentGroup, self)._remove_action(action)
        super(action)
        # delete @_group_actions[action] # TODO, [].remove not valid JS
        i = @_group_actions.indexOf(action)
        if i>=0
          @_group_actions.splice(i,1)


class _MutuallyExclusiveGroup extends _ArgumentGroup

    constructor: (container, options) ->
        # def __init__(self, container, required=False):
        # _ArgumentGroup.call(this, acoptions)
        super(container, options)
        # super(_MutuallyExclusiveGroup, self).__init__(container)
        @required = options.required
        # @_container = container

    _add_action: (action) ->
        if action.required
            msg = 'mutually exclusive arguments must be optional'
            raise new Error(msg)
        # action = super(action)
        # super doesn't work here because an exclusive group is simply a
        # variation on group; an action can be in both an xgroup and a group
        # like optionals; where as an action cannot be in 2 regular groups
        action = @_container._add_action(action)
        @_group_actions.push(action)
        return action

    _remove_action: (action) ->
        # super(action)
        @_container._remove_action(action)
        @_group_actions.remove(action) # TODO





if not module.parent?
  container = new _ActionsContainer({description:'a desciption', prefixChars:'-', argument_default:null, conflictHandler:'error'})
  console.log container
  container.register('type', null, (x)->x) # types normally added by argparser
  container.add_argument('-x','--xxx', {help:'testing'})
  container.add_argument('-f', {help:'test short opt'})
  container.add_argument({dest:'pos'})
  container.add_argument('pos1', {nargs:'?'})
  container.add_argument('--test')
  console.log container
