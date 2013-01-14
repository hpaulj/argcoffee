#!/usr/bin/env node

'use strict';

var plac = require('../lib/plac')

// var ArgumentParser  = require('../lib/argparse').ArgumentParser;
// var parser = new ArgumentParser({ description: 'Process some integers.' });

function sum(arr) {
  return arr.reduce(function (a, b) {
    return a + b;
  }, 0);
}
function max(arr) {
  return Math.max.apply(Math, arr);
}

function main (accumulate, integers) {
    // apply function <accumulate> to <integers>
    if (accumulate)
        fn = sum
    else
        fn = max
    return fn(integers);
}
// annotation array: [help, kind, abbrev, type, choices, metavar]
var d = {
    accumulate: ['sum the integers (default: find the max)', "flag", '--sum'],
    integers: ['an integer for the accumulator', "positional", null, 'int', null, 'N']}  // nargs '+'
main = plac.annotations(d)(main);
console.log(main);

//plac.call(main)
//parser = plac.call(main)
var parser = plac.parser_from(main, {prog: 'Main', description: 'plac version of argparse sum example'})

console.log(parser.format_help())

var arglist = '1 2 -1'.split(' ')
console.log(arglist, '=>', parser.consume(arglist))

arglist = '--sum 1 2 -1'.split(' ')
console.log(arglist, '=>', parser.consume(arglist))

/*
parser.addArgument(['integers'], {
  metavar:      'N',
  type:         'int',
  nargs:        '+',
  help:         'an integer for the accumulator'
});
parser.addArgument(['--sum'], {
  dest:         'accumulate',
  action:       'storeConst',
  constant:     sum,
  defaultValue: max,
  help:         'sum the integers (default: find the max)'
});
*/
