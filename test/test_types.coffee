
print = console.log

argparse = require('argcoffee')
argparse = require('argparse')

dateType = (arg) ->
    x = new Date(arg)
    if x.toString().match('Invalid')
        throw new TypeError("#{arg} is not a valid date.")
    return x
###
# js function with name
`function dateType(arg) {
  var x = new Date(arg);
  if (x.toString().match('Invalid')) {
    throw new TypeError("" + arg + " is not a valid date.");
    }
  return x;
  }`
###
print dateType('12/1/2012')
try
  print dateType('abc')
catch err
  print err
p = new argparse.ArgumentParser({debug:true})

p.addArgument(['-d'],{type:dateType})
p.addArgument(['-i'],{type:'int'})
p.addArgument(['-f'],{type:'float'})

print p.parseArgs(['-f','1.23'])
try
  print p.parseArgs(['-d','13/1/12'])
catch err
  print err
try
  print p.parseArgs(['-f','abc'])
catch err
  print err
print p.parseArgs(['-i','123'])
try
  print p.parseArgs(['-i','abc'])
catch err
  print err
print p.parseArgs(['-d','12/1/2012'])
try
  print p.parseArgs(['-d','13/1/12'])
catch err
  print err
print p.parseArgs(['-f','1.23','-i','123','-d','1/24/2012'])  
try
  print p.parseArgs(['-d','abc','-f','abc','-i','abc'])  
catch err
  print err

###
 py error
  error: argument -x: invalid float value: 'abc'
if fn is 'foo': invalid foo value 
  invalid <lambda> value

js:  error: argument "-f": Invalid float value: abc
but:  error: argument "-d": Invalid function (arg) {...

In py, error in get_value is formated with:
            name = getattr(action.type, '__name__', repr(action.type))
            args = {'type': name, 'value': arg_string}
            msg = _('invalid %(type)s value: %(value)r')
i.e. get the action.type functions __name__

In JS, action.type itself is used.  For builtin types that is fine,
since they use a string to index a function; but for custom types,
the type is itself the function; hence its toString() ends up in the
error message

In CS, I just pass on the error message from the type execution
So the message isnt as standardized, but can be tailored by the user

Possible JS solutions:
- try to parse function name from toString(); I do that for plac 
   (but not all js fn have a name; e.g. ones originating in coffee)
- if action.type is not string, use the unaltered error msg as I do in CS

###

###
modified _getValue
ArgumentParser.prototype._getValue = function (action, argString) {
  var result;

  var typeFunction = this._registryGet('type', action.type, action.type);
  if (!_.isFunction(typeFunction)) {
    var message = _.str.sprintf(
      '%(callback)s is not callable',
      {callback: typeFunction}
    );
    throw argumentErrorHelper(action, message);
  }

  // convert the value to the appropriate type
  try {
    result = typeFunction(argString);

    // ArgumentTypeErrors indicate errors
  } catch (e) {

    if (_.isString(action.type)) {
        throw argumentErrorHelper(
          action,
          _.str.sprintf('Invalid %(type)s value: %(value)s', {
            type: action.type,
            value: argString
          })
        );
    }
    else {
        // if action.type is a function the above inserts action.type.toString()
        // into the error message, i.e. the full text
        // Python just uses the function's __name__
        // Compromise is to use the error message that the function gave
        throw e
    }    
  }
  // return the converted value
  return result;
};
###
