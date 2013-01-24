# adapted from plac_core.py, the core part of plac module
if not module.parent?
    DEBUG = (arg...) ->
      arg.unshift('==> ')
      console.log arg...
else
    DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

argparse = require('argcoffee')

# argparse = require('argparse')
# conditionally add this, need to add add_argument parser_args
 
formal_parameter_list = (fn) ->
  FN_ARGS = /^function\s*([^\(]*)\(\s*([^\)]*)\)/m;
  FN_ARG_SPLIT = /,/;
  FN_ARG = /^\s*(\S+?)\s*$/
  STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;
  args = []
  name = null
  doc = null
  fn_text = fn.toString().replace(STRIP_COMMENTS, '')
  cmts = fn.toString().match(STRIP_COMMENTS)
  # could refine this to take just the comment at the start
  # also remove the comment marks
  if cmts? and cmts.length>0
    doc = cmts[0]
  arg_decl = fn_text.match(FN_ARGS)  # function name(args)
  name = arg_decl[1]
  arg_decl = arg_decl[2]
  r = arg_decl.split(FN_ARG_SPLIT)
  for a of r
    arg = r[a]
    arg.replace(FN_ARG, (all, name) ->
      args.push(name))
  if name? and name==''
    name = null
  if doc? and doc.length==0
    doc = null
  return [args, name, doc]

class getfullargspec
  constructor: (f) ->
    # inspect.getargspac(f)
    # @args = alt_getarglist(f)
    [@args, @name, @doc] = formal_parameter_list(f)
    @varargs = null
    @varkw = null
    [first...,last] = @args 
    if last in ['kwarg','kwargs','__kw','varkw']
      [@args, @varkw] = [first, last]
    [first...,last] = @args
    if last in ['vargs','_arg']
      [@args, @varargs] = [first, last]
    @defaults = f.defaults ? []
    @annotations = f.__annotations__ ? {}

getargspec = (callableobj) ->
  # Given a callable return an object with attributes .args, .varargs, 
  #  .varkw, .defaults. It tries to do the "right thing" with functions,
  #  methods, classes and generic callables.
  if _.isFunction(callableobj)
    argspec = new getfullargspec(callableobj)
    if callableobj.name?
      # explicit name of obj takes presidence over one deduced from string
      argspec.name = callableobj.name     
    # py has special treatment for method, class, and callable
    # js all is either obj, or function
  else
    throw new TypeError('Could not determine the signature of'+callableobj)
  return argspec

# this distinction between getargspec and getfullargspec is a python artifact

annotations = (ann) ->
  #Returns a decorator annotating a function with the given annotations.
  #This is a trick to support function annotations in Python 2.X.
  
  annotate = (f) ->
    fas = getargspec(f)
    # check that the names in 'ann' match those found by getargspec
    args = fas.args
    if fas.varargs?
      args.push(fas.varargs)
    if  fas.varkw?
      args.push(fas.varkw)
    for argname of ann
      if not argname in args
        thrown new Error('Annotating non-existing argument'+ argname)
    f.__annotations__ = ann
    return f
  return annotate
exports.annotations = annotations

is_annotation = (obj) ->
  #An object is an annotation object if it has the attributes
  #help, kind, abbrev, type, choices, metavar.
  return obj.help? and obj.kind? and obj.abbrev? and obj.type? and obj.choices? and obj.metaver?

class Annotation
  constructor: (@help=null, @kind='positional', @abbrev=null, @type=null, @choices=null, @metavar=null) ->
    # alt: options:{}
    assert(@kind in ['positional', 'option', 'flag'],'kind should be positional, option, or flag')
    if @kind == 'positional'
      assert(@abbrev == null, 'abbrev for positional should be null')
  @from_ = (obj) -> 
    # helper to convert an object into an annotation, if needed
    if is_annotation(obj)
      return obj
    else if _.isArray(obj)
      return new Annotation(obj...)
    return new Annotation(obj)

# PARSER_CFG 
# the default arguments accepted by an ArgumentParser object

PARSER_CFG = 'prog, usage, epilog, parents, formatter_class, fromfile_prefix_chars, '+ 
    'add_help, debug, description, prefix_chars, argument_default, conflict_handler, '+
    'version'
PARSER_CFG = PARSER_CFG.split(', ')

pconf = (obj) ->
  # Extracts the configuration of the underlying ArgumentParser from obj
  doc = name = null
  try
    argspec = getargspec(obj)
    doc = argspec.doc ? null
    name = argspec.name ? null
  catch TypeError
    ""    
  if !name? or name==''
    name = null
  cfg = {prog: name, description: doc} # , formatter_class:argparse.HelpFormatter}
  for key of obj when key in PARSER_CFG
    cfg[key] = obj[key]
  return cfg
  
# PY stores the parser in this dictionary, using the function (obj) as key
# looks like JS uses obj.toString() as the key in _parser_registry[obj]
# thus 2 anonymous fn with same string reference the same parser

_parser_registry = {}
_parser_registry.get = (obj) -> return null
_parser_registry.set = (obj, p) -> _parser_registry[obj] = p

parser_from = (obj, confparams={}) ->
  #obj can be a callable or an object with a .commands attribute.
  #Returns an ArgumentParser.
  if _parser_registry.get(obj)?
    # the underlying parser has been generated already
    return _parser_registry.get(obj)
  conf = _.extend({}, pconf(obj), confparams)
  parser = new ArgumentParser(conf)
  _parser_registry.set(obj,parser)
  parser.obj = obj
  parser.case_sensitive = confparams['case_sensitive'] ? obj['case_sensitive'] ? true
  if obj['commands']?
    # a command container instance
    parser.addsubcommands(obj.commands, obj, 'subcommands')
  else
    parser.populate_from(obj)
  return parser
exports.parser_from = parser_from

_extract_kwargs = (args) ->
  #"Returns two lists: regular args and name=value args"
  # not going to work in js; 
  arglist = []
  kwargs = {}
  for arg in args
    # arg of form 'name=value', put in kwargs, else in arglist
    m = arg.match(/([a-zA-Z_]\w*)=/)
    if m?
      name = m[1]
      kwargs[name] = arg[name.length+1...]
    else
      arglist.push(arg)
  return [arglist, kwargs]

_match_cmd = (abbrev, commands, case_sensitive=true) ->
  #"Extract the command name from an abbreviation or raise a NameError"
  commands = _.keys(commands)
  if not case_sensitive
    abbrev = abbrev.toUpperCase()
    commands = (c.toUpperCase() for c in commands)
  perfect_matches = (name for name in commands when name == abbrev)
  if perfect_matches.length == 1
    return perfect_matches[0]
  matches = (name for name in commands when _.str.startsWith(name, abbrev))
  n = matches.length
  if n==1
    return matches[0]
  else if n>1
    throw Error("Ambiguous command #{abbrev} matching #{matches}")
  

class ArgumentParser extends argparse.ArgumentParser
   # An ArgumentParser with .func and .argspec attributes, and possibly
   # .commands and .subparsers.
  constructor: (options) ->
    super(options)
    
  case_sensitive = true
  alias: (arg) ->
    # Can be overridden to preprocess command-line arguments
    return arg
    
  consume: (args) ->
    # Call the underlying function with the args. Works also for
    #   command containers, by dispatching to the right subparser.
    
    arglist = (@alias(a) for a in args)
    cmd = null
    if @subparsers?
      [subp, cmd, arglist] = @_extract_subparser_cmd(arglist)
      DEBUG cmd, arglist
      if !subp? and cmd?
        return [cmd, @missing(cmd)]
      else if subp?
        return subp.consume(arglist) 
    if @argspec? and !_.isEmpty(@argspec.varkw)
      [arglist, kwargs] = _extract_kwargs(arglist)
    else
      kwargs = {}
    if @argspec? and @argspec.varargs?
      # ignore unrecognized arguments
      [ns, extraopts] = @parse_known_args(arglist)
    else
      [ns, extraopts] = [@parse_args(arglist), []] # may raise an exit
    DEBUG 'ns', ns
    DEBUG 'extrapopts', extraopts
    args = (ns[a] for a in @argspec.args)
    varargs = ns[@argspec.varargs] ? []
    collision = (arg for arg in @argspec.args when arg of kwargs)
    if collision.length>0
      @error('colliding keyword arguments: ' + collision)
    alist = [].concat(args, [varargs], extraopts)
    DEBUG 'alist', alist
    DEBUG 'kwargs', kwargs
    return [cmd, @func(alist..., kwargs)]
    
  _extract_subparser_cmd: (arglist) ->
    # Extract the right subparser from the first recognized argument
    optprefix = @prefix_chars[0]
    name_parser_map = @subparsers._name_parser_map
    for arg, i in arglist when arg[0] != optprefix
      cmd = _match_cmd(arg, name_parser_map, @case_sensitive)
      arglist = arglist.splice(i+1) # [(i+1)...]
      return [name_parser_map[cmd], cmd || arg, arglist]
    return [null, null, arglist] # none found
    
  addsubcommands: (commands, obj, title=null, cmdprefix='') ->
    # Extract a list of subcommands from obj and add them to the parser
    options = {title:title}
    options['parser_class'] = ArgumentParser
    if !@subparsers?
      @subparsers = @add_subparsers(options)
    else if title?
      @add_argument_group(options)
    prefixlen = (obj.cmdprefix ? '').length
    add_help = obj.add_help ? true
    for cmd in commands
      func = obj[cmd[prefixlen...]] # strip the prefix
      options = {add_help: add_help, help: 'subparser help'}
      subparser = @subparsers.add_parser(cmd, options)
      subparser.populate_from(func)
    
  _set_func_argspec: (obj) ->
    # Extracts the signature from a callable object and adds an .argspec
    # attribute to the parser. Also adds a .func reference to the object.
    @func = obj
    @argspec = getargspec(obj)
    _parser_registry.set(obj, @)

  populate_from: (func) ->
    # Extract the arguments from the attributes of the passed function
    # and return a populated ArgumentParser instance.
    @_set_func_argspec(func)
    f = @argspec
    # in python style, defaults, if any, are attributed to the last 'n'
    # of the args; i.e. args with defaults come after ones without
    # but if defaults are given as part of the annotations it might be
    # better to use key value pairs
    defaults = f.defaults ? []
    n_args = f.args.length
    n_defaults = defaults.length
    alldefaults = (null for i in [0...(n_args-n_defaults)]).concat(defaults)
    DEBUG f.args, alldefaults
    prefix = @prefix = (func.prefix_chars ? '-')[0]
    # args with possible defaults
    for [name, defaultValue] in _.zip(f.args, alldefaults)
      ann = f.annotations[name] ? []
      a = Annotation.from_(ann) # annotation_from(ann)
      metavar = a.metavar
      if !defaultValue?
        dflt = null
      else
        dflt = defaultValue
        if !a.help?
          a.help = "[#{dflt}]" # dflt can be a tuble
      if a.kind in ['option', 'flag']
        if a.abbrev?
          shortlong = [prefix + a.abbrev, prefix+prefix+name.replace('_','-')]
        else
          shortlong = [prefix + name.replace('_','-')]
      else if !dflt?   # positional without default
        # @add_argument(name, {nargs:'*',help:a.help, type:a.type, choices:a.choices, metavar:metavar})
        @add_argument(name, {help:a.help, type:a.type, choices: a.choices, metavar:metavar})
      else # default  argument
        nargs = if _.str.endsWith(name,'s') then '*' else '?'  # plural
        @add_argument(name, {nargs:nargs,help:a.help, defaultValue:dflt, type:a.type, choices:a.choices, metavar:metavar})

      if a.kind == 'option'
        if defaultValue?
          metavar = metavar ? "#{defaultValue}"
        @add_argument(shortlong..., {help:a.help, defaultValue:dflt, type:a.type, choices:a.choices, metavar:metavar})
      else if a.kind == 'flag'
        if defaultValue? and defaultValue != false
          throw new TypeError("Flag #{name} wants default false, got #{defaultValue}")
        @add_argument(shortlong..., {action:'storeTrue', help:a.help})
      # 'flag' action is storeTrue
      # for all others it is the default store with possbiel defaultValue and choices
      # nargs is either null (=1), '?' or '*'
        
    if f.varargs?
        a = Annotation.from_(f.annotations[f.varargs] ? [])
        @add_argument(f.varargs, {nargs:'*', help:a.help, defaultValue:[],\
                           type:a.type, metavar:a.metavar})
    if f.varkw?
        a = Annotation.from_(f.annotations[f.varkw] ? [])
        @add_argument(f.varkw, {nargs:'*', help:a.help, defaultValue:{},\
                           type:a.type, metavar:a.metavar})
    # 
    # py has simple arg, arg with defaultvalue, arg w/ multiple values, dict arg
    # js only has only has simple arg
    # so has to use other means to identify defaults, indicate '*' and '**' args
    # here I try positional 'integer' as '?', 'integers' as '*'
    # propose 'options' as equiv to **kwarg

  missing: (name) ->
    # may raise a system exit
    miss = @obj['__missing__'] ? (name) => @error("No command #{name}")
    return miss(name)
    
  print_actions: () ->
    #useful for debugging
    return (a.repr() for a in @_actions).join('\n')

    
iterable = (obj) ->
  return obj.__iter__? and not _.isString(obj)

call = (obj, arglist=process.argv[2...], options={}) ->
  # If obj is a function or a bound method, parse the given arglist 
  #  by using the parser inferred from the annotations of obj
  #  and call obj with the parsed arguments. 
  #  If obj is an object with attribute .commands, dispatch to the 
  #  associated subparser.
  
  [cmd, result] = parser_from(obj, options).consume(arglist)
  #if iterable(result) and eager # listify the result
  #  return list(result)
  return result
  # py iterable is anything that can be turned into a list (array)
  # is there a parallel to a callback?
  # _.toArray(iterable), convert anything that can be iterated over 
  # to true array (mainly the psuedo array arguments)
exports.call = call

#=======================================================
if not module.parent?

  console.log require.module == module
  # example3.py
  main = (aflag, anopt, aposit, vargs, kwargs) ->
    ### Do something with the database
     vargs... is not usable; coffee just uses 'arguments' ###
    console.log 'main args:', aflag, anopt, aposit, vargs, kwargs
    return 'Done'
    
  d = {
    aflag: ["a flag", 'flag'],
    anopt: ["an optional", 'option'],
    aposit: ["a positional", 'positional'],
    vargs: ["multi element ", 'positional'],
    kwargs: ["keyword args", 'positional']}
  main = annotations(d)(main)
  main.defaults = ['posdefault']
  main.name = 'MAIN'
  main.description = 'documentation for main'

  parser = parser_from(main, {prog: 'Main', \
                description: 'plac version of argparse sum example',
                debug: true})

  console.log(parser.format_help());
  # usage: Main [-h] [-aflag] [-anopt ANOPT]
  #          [aposit] [vargs [vargs ...]] [kwargs [kwargs ...]]

  console.log parser.consume([])
  # main args: false null posdefault [] {}

  console.log parser.consume(['-aflag','-anopt', '42', 'posarg','var1','var2','one=1', 'two=foo'])
  # main args: true 42 posarg [ 'var1', 'var2' ] { one: '1', two: 'foo' }
  # looks right

  console.log "========================\ntest subparsers"
  # _parser_registry = {}
  afunc = (bar) -> 
    ### a command ###
    return ['a bar:',bar]
  main = () ->
    return "DONE"
  main.a = afunc
  main.b = (baz) -> 
    ### b command takes one arg ###
    return ['b baz:',baz]
    
  d = {}
  main = annotations(d)(main)
  main.commands = ['a','b']
  main.description = 'documentation for main'

  parser = parser_from(main, { # prog: 'Main', \
                debug: true})
  console.log(parser.format_help());
  
  # console.log parser.parse_args(['a','-h'])
  # exits; I thought debug was supposed to trap that

  console.log 'a bar', parser.consume(['a',42])
  console.log ''
  try
    console.log 'b',parser.consume(['b','BAZ'])
  catch error
    console.log error
  
  try
    parser.consume(['-h'])
  catch error
  try
    parser.consume(['a','-h'])
  catch error
  
  console.log '===================================='
  parser_from1 = (f, kw) ->
    f.__annotations__ = kw
    return parser_from(f, {debug:true})
  p4 = parser_from1(((delete_, delete_all, color)-> None),
                 {delete_:['delete a file', 'option', 'd'],
                 delete_all:['delete all files', 'flag', 'a'],
                 color:['color', 'option', 'c']})
                 # color default "black"
  console.log p4.format_help()
                 
  console.log 'done'
###
in py
def foo3(x,y=3,a=None,*z,**w):
    print x,y,z,w
    return 'done'
   ....: 

vars(plac.getargspec(foo3)) 
{'annotations': {},
 'args': ['x', 'y', 'a'],
 'defaults': (3, None),
 'varargs': 'z',
 'varkw': 'w'}

in js, there are only args
coffee adds defaults (of sorts)
and something like *z, array turned into string of args 
but those aren't directly visible in underlying js

square = function(x) {
  return x * x;
};
square.toString()
square.length   # of named arguments

function square(x) {...} will have square.name = 'square'
bar = function foo(x)

###

