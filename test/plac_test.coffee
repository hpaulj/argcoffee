assert = require('assert')
plac = require('../lib/plac')

parser_from = (f, kw) ->
    f.__annotations__ = kw
    return plac.parser_from(f, {debug:true})
    
p1 = parser_from(((delete_, vargs) -> None),
                 {delete_:['delete a file', 'option']})
                 
console.log p1.format_help()

test_p1 = () ->
    arg = p1.parse_args(['-d', 'foo', 'arg1', 'arg2'])
    console.log arg
    assert.equal(arg.delete_, 'foo')
    assert.deepEqual(arg.vargs, ['arg1', 'arg2'])

    arg = p1.parse_args([])
    console.log arg
    assert.equal(arg.delete, null)
    assert.deepEqual(arg.vargs, [])

for test in [test_p1]
  test()

