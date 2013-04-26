###
Constants
###
$$ = {}
$$.EOL = '\n'
$$.SUPPRESS = '==SUPPRESS=='
$$.OPTIONAL = '?'
$$.ZERO_OR_MORE = '*'
$$.ONE_OR_MORE = '+'
$$.PARSER = 'A...'
$$.REMAINDER = '...'
$$._UNRECOGNIZED_ARGS_ATTR = '_unrecognized_args'

exports.$$ = $$

for k,v of $$
  exports[k] = v

