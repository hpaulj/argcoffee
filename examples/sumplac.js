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
    console.log(integers)
    var fn
    if (accumulate)
        fn = sum
    else
        fn = max
    return [fn.name, integers, fn(integers)];
}
// annotation array: [help, kind, abbrev, type, choices, metavar]
var d = {
    accumulate: ['sum the integers (default: find the max)', "flag"],
    integers: ['an integer for the accumulator', "positional", null, 'int', null, 'N']}  // nargs '+'
main = plac.annotations(d)(main);
console.log(main);

//plac.call(main)
//parser = plac.call(main)
var parser = plac.parser_from(main, {prog: 'Main', 
                description: 'plac version of argparse sum example',
                debug: true});

console.log(parser.format_help());

['', '2 4 -1', '-a 2 4 -1', '-accumulate'].forEach(function (arglist) {
    var alist = arglist.split(' ');
    alist = alist.filter(function (l){return l.length>0;});
    try {
        console.log(alist, '=>', parser.consume(alist)[1]);
        }
    catch(error) {
        console.log(error);
        }        
    })

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
