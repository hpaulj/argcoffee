# example10.py
plac = require('../lib/plac')

main = (operator, numbers) ->
    # A script to add and multiply numbers
    if operator == 'mul'
        return numbers.reduce(((a, b) -> a*b), 1.0)
    else if operator == 'add'
        return numbers.reduce(((a, b) -> a+b), 0.0)
main.name = 'main'
d = {
    operator: ["The name of an operator", 'positional', null, null, ['add', 'mul']],
    numbers: ["A number", 'positional', null, 'float', null, "n"]}
main = plac.annotations(d)(main);

console.log plac.call(main)
