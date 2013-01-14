# adapted from plac_core.py, the core part of plac module
if true # not module.parent?
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

`// http://stackoverflow.com/questions/6921588/is-it-possible-to-reflect-the-arguments-of-a-javascript-function
var FN_ARGS = /^function\s*[^\(]*\(\s*([^\)]*)\)/m;
var FN_ARG_SPLIT = /,/;
var FN_ARG = /^\s*(_?)(\S+?)\1\s*$/;
var STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;

function formalParameterList(fn) {
   var fnText,argDecl;
   var args=[];
   fnText = fn.toString().replace(STRIP_COMMENTS, '');
   argDecl = fnText.match(FN_ARGS); 

   var r = argDecl[1].split(FN_ARG_SPLIT);
   for(var a in r){
      var arg = r[a];
      arg.replace(FN_ARG, function(all, underscore, name){
         args.push(name);
      });
   }
   return args;
 }`
 
formal_parameter_list = (fn) ->
  FN_ARGS = /^function\s*[^\(]*\(\s*([^\)]*)\)/m;
  FN_ARG_SPLIT = /,/;
  FN_ARG = /^\s*(_?)(\S+?)\1\s*$/;
  STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;
  # why is '_x_' parsed as just 'x'? (rm paired _)
  args = []
  fn_text = fn.toString().replace(STRIP_COMMENTS, '')
  arg_decl = fn_text.match(FN_ARGS)
  r = arg_decl[1].split(FN_ARG_SPLIT)
  for a of r
    arg = r[a]
    arg.replace(FN_ARG, (all, underscore, name) ->
      args.push(name))
  args

alt_getarglist = (fn) ->
  return fn.toString().match(/function\s+\w*\s*\((.*?)\)/)[1].split(/\s*,\s*/)

class getfullargspec
  constructor: (f) ->
    # inspect.getargspac(f)
    @args = alt_getarglist(f)
    @varargs = []
    @varkw = {}
    @defaults = []
    @annotations = f.__annotations__ ? {}

# set class

getargspec = (callableobj) ->
  # Given a callable return an object with attributes .args, .varargs, 
  #  .varkw, .defaults. It tries to do the "right thing" with functions,
  #  methods, classes and generic callables.
  if _.isFunction(callableobj)
    argspec = new getfullargspec(callableobj)
    name = callableobj.name ? ''
  # else if method, remove 1st arg, py self
  # else if class, 
  # else if callableobj.__call__?
  else
    throw new TypeError('Could not determine the signature of'+callableobj)
  DEBUG name, argspec
  return argspec

#DEBUG 'gerartspec args:',formalParameterList(getargspec)
#DEBUG formal_parameter_list(getargspec)
#DEBUG alt_getarglist(getargspec)

#DEBUG alt_getarglist(`function foo(x,y){return x;}`)

annotations = (ann) ->
  #Returns a decorator annotating a function with the given annotations.
  #This is a trick to support function annotations in Python 2.X.
  
  annotate = (f) ->
    fas = getargspec(f)
    args = fas.args
    # append varargs to args
    # append varkw to args
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
    assert(@kind in ['positional', 'option', 'flag'])
    if @kind == 'positional'
      assert(@abbrev == null)
  
# class method  
annotation_from = (obj) ->
  # helper to convert an object into an annotation, if needed
  if is_annotation(obj)
    return obj
  else if _.isArray(obj)
    return new Annotation(obj...)
  return new Annotation(obj)
  # not quite right; this constructor takes (array...)
  # but there should be a way of passing an obj (dictionary)
  #
  # annotation is just an obj with a few tests on values
  
# DEBUG Annotation.toString()
#DEBUG 'annotation args:',formalParameterList(Annotation)
#DEBUG alt_getarglist(Annotation)
  
# None = {} # sentinel use to signal the absence of a default

# PARSER_CFG = getfullargspec(argparse.ArgumentParser.constructor).args[1...]
# args[1:], skip initial self
# the default arguments accepted by an ArgumentParser object
###
in js version, ArgumentParser takes one argument 'options'
possible attributes of options are:
prog, usage, epilog, parents, formatter_class, fromfile_prefix_chars, 
add_help, debug, description, prefix_chars, argument_default, conflict_handler,
version
###

PARSER_CFG = 'prog, usage, epilog, parents, formatter_class, fromfile_prefix_chars, '+ 
    'add_help, debug, description, prefix_chars, argument_default, conflict_handler, '+
    'version'
PARSER_CFG = PARSER_CFG.split(', ')
DEBUG PARSER_CFG
pconf = (obj) ->
  # Extracts the configuration of the underlying ArgumentParser from obj
  cfg = {description: 'obj doc', formatter_class:argparse.HelpFormatter}
  for name of obj # dir(obj)  # what is dir() equivalent? ownProperties?
    if name in PARSER_CFG # argument of ArgumentParse
      cfg[name] = obj[name]
  return cfg
  
_parser_registry = {}

parser_from = (obj, confparams={}) ->
  #obj can be a callable or an object with a .commands attribute.
  #Returns an ArgumentParser.
  if _parser_registry[obj]?
    # the underlying parser has been generated already
    return _parser_registry[obj]
  conf = _.extend({}, pconf(obj), confparams)
  _parser_registry[obj] = parser = new ArgumentParser(conf)
  parser.obj = obj
  parser.case_sensitive = confparams['case_sensitive'] ? obj['case_sensitive'] ? true
  if obj['commands']? and !_.isClass(obj)
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
    m = arg.match(/([a-zA-Z_]\w*])=/)
    if m?
      name = m[1]
      kwargs[name] = arg[name.length+1...]
    else
      arglist.push(arg)
  return [arglist, kwargs]

_match_cmd = (abbrev, commands, case_sensitive=true) ->
  #"Extract the command name from an abbreviation or raise a NameError"
  if not case_sensitive
    abbrev = abbrev.toUpper()
    commands = (c.toUpper() for c in commands)
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

  case_sensitive = true
  alias: (arg) ->
    # Can be overridden to preprocess command-line arguments
    return arg
    
  consume: (args) ->
    #Call the underlying function with the args. Works also for
    #   command containers, by dispatching to the right subparser.
    
    arglist = (@alias(a) for a in args)
    cmd = null
    if @.subparsers?
      [subp, cmd] = @_extract_subparser_cmd(arglist)
      if !subp? and cmd?
        return [cmd, @missing(cmd)]
      else if subp?
        '' # @ = subp 
    if @argspec? and !_.isEmpty(@argspec.varkw)
      [arglist, kwargs] = @_extract_kwargs(arglist)
    else
      kwargs = {}
    if @argspec? and @argspec.varargs.length>0
      # ignore unrecognized arguments
      [ns, extraopts] = @parse_known_args(arglist)
    else
      [ns, extraopts] = [@parse_args(arglist), []] # may raise an exit
    args = (ns[a] for a in @argspec.args)
    varargs = ns[@argspec.varargs]? []
    collision = [] # set(@argspec.args) & set(kwargs)
    if collision.length>0
      @error('colliding keyword arguments:' + collision)
    alist = [].concat(args, varargs, extraopts)
    return [cmd, @func(alist, kwargs)]
    
  _extract_subparse_cmd: (arglist) ->
    # Extract the right subparser from the first recognized argument
    optprefix = @prefix_chars[0]
    name_parser_map = @subparsesrs._name_parser_map
    for [i,arg] in _.zip([0...arglist.length], arglist)
      if arg[0] != optprefix  # or _.str.startsWith
        cmd = _match_cmd(arg, name_parser_map, @case_sensitive)
        delete arglist[i]
        return [name_parser_map[cmd], cmd || arg]
    return [null,null]
    
  addsubcommands: (commands, obj, title=null, cmdprefix='') ->
    # Extract a list of subcommands from obj and add them to the parser
    # obj.cmdprefix? or obj[cmdprefix]
    # 'hasattr(obj, cmdprefix) and obj.cmdprefix' looks a bit suspect
    if !@subparsers?
      @subparsers = @add_subparsers({title:title})
    else if title?
      @add_argument_group({title:title})
    prefixlen = (obj.cmdprefix ? '').length
    add_help = obj.add_help ? true
    for cmd in commands
      func = obj[cmd[prefixlen...]] # strip the prefix
      options = {add_help:add_help, help:'func.__doc__'}
      # options.extend(pconf(func)
      subparser = @subparsers.add_parser(cmd, options)
      subparser.populate_from(func)
    
  _set_func_argspec: (obj) ->
    # Extracts the signature from a callable object and adds an .argspec
    # attribute to the parser. Also adds a .func reference to the object.
    @func = obj
    @argspec = getargspec(obj)
    _parser_registry[obj] = @

  populate_from: (func) ->
    #Extract the arguments from the attributes of the passed function
    # and return a populated ArgumentParser instance.
    
    @_set_func_argspec(func)
    f = @argspec
    defaults =f.defaults ? []
    n_args = f.args.length
    n_defaults = defaults.length
    alldefaults = (null for i in [0...(n_args-n_defaults)]).concat(defaults)
    prefix = @prefix = (func.prefix_chars ? '-')[0]
    for [name, defaultValue] in _.zip(f.args, alldefaults)
      ann = f.annotations[name] ? []
      a = annotation_from(ann)
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
      else if !defaultValue?
        @add_argument(name, {help:a.help, type:a.type, choices: a.choices, metaver:metavar})
      else # default  argument
        @add_argument(name, {nargs:'?',help:a.help, defaultValue:dflt, type:a.type, choices:a.choices, metavar:metavar})
      if a.kind == 'option'
        if defaultValue?
          metavar = metavar ? ""+metavar
        @add_argument(shortlong..., {help:a.help, defaultValue:dflt, type:a.type, choices:a.choices, metavar:metavar})
      else if a.king == 'flag'
        if defaultValue? and defaultValue != false
          throw new TypeError("Flat #{name} wants default false, got #{defaultValue}")
        @add_argument(shortlong..., {action:'storeTrue', help:a.help})
    if f.varargs.length>0
      a = annotation_from(f.annotations[f.varags] ? [])
      @add_argument(f.varkw, {nargs:'*', help:a.help, defaultValue:{},type:a.type, metavar:a.metaver})
      # where is the shortlong?, here or in py?

  missing: (name) ->
    # may raise a system exit
    miss = @obj['__missing__'] ? (name) -> @error("No command #{name}")
    return miss(name)
    
  print_actions: () ->
    #useful for debugging
    console.log @  # py has a defined __str__ for a parser
    for a in @._actions
      console.log a

    
iterable = (obj) ->
  return obj.__iter__? and not _.isString(obj)

call = (obj, arglist=process.argv[2...], eager=true) ->
  # If obj is a function or a bound method, parse the given arglist 
  #  by using the parser inferred from the annotations of obj
  #  and call obj with the parsed arguments. 
  #  If obj is an object with attribute .commands, dispatch to the 
  #  associated subparser.
  
  [cmd, result] = parser_from(obj).consume(arglist)
  #if iterable(result) and eager # listify the result
  #  return list(result)
  return result
  # py iterable is anything that can be turned into a list (array)
  # is there a parallel to a callback?
  # _.toArray(iterable), convert anything that can be iterated over 
  # to true array (mainly the psuedo array arguments)
exports.call = call

#DEBUG 'call args:',formalParameterList(call)

###
# Convert anything iterable into a real, live array.
_.toArray = (iterable) ->
  return []                   if (!iterable)
  return iterable.toArray()   if (iterable.toArray)
  return iterable             if (_.isArray(iterable))
  return slice.call(iterable) if (_.isArguments(iterable))
  _.values(iterable)
###

if not module.parent?
  # example3.py
  main = (dsn) ->
    # Do something with the database
    console.log dsn
    return 'Done'
    # ...
  console.log call(main, ['DSN obj'])

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

