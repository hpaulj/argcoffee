# separate these error classes to facilitate importation
# into several other modules

{$$} = require('./const')

###
class ArgumentTypeError(Exception):
    """An error from trying to convert a command line string to a type."""
    pass
###
class ArgumentTypeError extends Error
  constructor: (msg) ->
    Error.captureStackTrace(@, @)
    @.message = msg || 'Argument Error'
    @name = 'ArgumentTypeError'

###
An error from creating or using an argument (optional or positional).

The string value of this exception is the message, augmented with
information about the argument that caused it.
###
class ArgumentError extends Error
  constructor: (@argument=null, @message="") ->
    @name = "ArgumentError"
    Error.captureStackTrace(@, @)
    try
      @argument_name = @argument.getName() # action.getName
    catch err
      @argument_name = _get_action_name(@argument)
    #console.log @argument.getName()
    #console.log _get_action_name(@argument)
  toString: () ->
    if @argument_name?
      astr = "argument \"#{@argument_name}\": #{@message}"
    else
      astr = ""+@message
    astr = @name + ': ' + astr

exports.ArgumentTypeError = ArgumentTypeError
exports.ArgumentError = ArgumentError

_get_action_name = (argument) ->
    if argument is null
        return null
    else if argument.isOptional()
        return  argument.option_strings.join('/')
    else if argument.metavar not in [null, $$.SUPPRESS]
        return argument.metavar
    else if argument.dest not in [null, $$.SUPPRESS]
        return argument.dest
    else
        return null
