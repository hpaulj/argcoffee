/*global describe, it*/


'use strict';

var assert = require('assert');
var argparse = require('argcoffee')
var ArgumentParser = argparse.ArgumentParser;
var Namespace = argparse.Namespace;

function split(args) {
  console.log(args)
  if (args.length===0) {return []};
  return args.split(' ');
}
// also _.str.words(args)

var parse_intermixed_args = require('../lib/intermixed').parse_intermixed_args;

describe('Intermixed:', function () {
  var parser;
  var args;
  var failures;
  var successes;

  it("TestOptionalsBetween2PositionalsZeroOrMore", function () {
    /*Tests optionals within positionals, '*' 2nd positional
    2nd positional is not consumed by the 1st argument set
    before if 'cmd -f1 1 2', 'rest' is consumed by 'cmd', leaving
    '1 2' 'unrecognized'.*/
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['cmd']);
    parser.addArgument(['-f', '--foo']);
    parser.addArgument(['rest'],{nargs:'*'});
    failures = ['',  // the following arguments are required: cmd, rest
                'cmd 1 -f1 2', // unrecognized arguments: 2
                'cmd 1 --foo 1 2',
                // optional cannot split arguments for 'rest'
                ];
    successes = [
        ['-f1 cmd 1 2', {cmd:'cmd', foo:'1', rest:['1', '2']}],
        ['cmd -f1 1 2', {cmd:'cmd', foo:'1', rest:['1', '2']}], // error
        ['cmd 1 2 --foo 1', {cmd:'cmd', foo:'1', rest:['1', '2']}],
        ['cmd --foo 1 1 2',{cmd:'cmd', foo:'1', rest:['1', '2']}]
    ];
    for (var ii=0;ii<failures.length;ii++) {
      assert.throws(
        function () {
          args = parser.parseArgs(split(failures[ii]));
        }
      );
    };
    for (var ii=0;ii<successes.length;ii++) {
      args = parser.parseArgs(split(successes[ii][0]));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it("TestOptionalsBetween2PositionalsOptional", function () {
    parser = new ArgumentParser({debug: true});
    /*Tests optionals within positionals, '?' 2nd positional
    2nd positional is not consumed by the 1st argument set*/

    parser.addArgument(['cmd']);
        parser.addArgument(['-f', '--foo']);
        parser.addArgument(['rest'],{nargs:'?'});
    successes = [
        ['-f1 cmd 1', {cmd:'cmd', foo:'1', rest:'1'}],
        ['cmd -f1 1', {cmd:'cmd', foo:'1', rest:'1'}], // unrec 1
    ];
    for (var ii=0;ii<successes.length;ii++) {
      args = parser.parseArgs(split(successes[ii][0]));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it("TestOptionalsBetween3PositionalsZeroOrMore", function () {
    parser = new ArgumentParser({debug: true});
    /*Tests optionals within positionals, '*' 2nd positional
    2 positionals that might not be consumed by the 1st argument*/

        parser.addArgument(['cmd']);
        parser.addArgument(['-f', '--foo']);
        parser.addArgument(['resta'],{nargs:'?'});
        parser.addArgument(['restb'],{nargs:'*'});
    failures = ['cmd 1 2 -f1 3'];
    successes = [
        ['-f1 cmd 1 2 3', {cmd:'cmd', foo:'1', resta:'1', restb:['2', '3']}],
        ['cmd -f1 1 2 3', {cmd:'cmd', foo:'1', resta:'1', restb:['2', '3']}],
        ['cmd 1 -f1 2 3', {cmd:'cmd', foo:'1', resta:'1', restb:['2', '3']}],
        ['cmd 1 2 3 -f1', {cmd:'cmd', foo:'1', resta:'1', restb:['2', '3']}],
    ];
    for (var ii=0;ii<failures.length;ii++) {
      assert.throws(
        function () {
          args = parser.parseArgs(split(failures[ii]));
        },
        /unrecognized arguments/
      );
    };
    for (var ii=0;ii<successes.length;ii++) {
      args = parser.parseArgs(split(successes[ii][0]));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it("TestOptionalsBetween3PositionalsOptional", function () {
    parser = new ArgumentParser({debug: true});
    /*Tests optionals within positionals, '?' 2nd positional
    2 positionals that might not be consumed by the 1st argument set*/

    parser.addArgument(['cmd']);
        parser.addArgument(['-f', '--foo']);
        parser.addArgument(['resta'], {nargs:'?'});
        parser.addArgument(['restb'], {nargs:'?'});

    var successes = [
        ['-f1 cmd 1 2', {cmd:'cmd', foo:'1', resta:'1', restb:'2'}],
        ['cmd -f1 1 2', {cmd:'cmd', foo:'1', resta:'1', restb:'2'}],  // unrec 1 2
        ['cmd 1 -f1 2', {cmd:'cmd', foo:'1', resta:'1', restb:'2'}],
        ['cmd 1 2 -f1', {cmd:'cmd', foo:'1', resta:'1', restb:'2'}],
      ];
        for (var ii=0;ii<successes.length;ii++) {
      args = parser.parseArgs(split(successes[ii][0]));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it("test intermixed", function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {dest:'foo'})
    parser.addArgument(['--bar'], {dest:'bar'})
    parser.addArgument(['cmd'])
    parser.addArgument(['rest'], {nargs:'*'})

    successes = [['a b c d --foo x --bar 1', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]]],

              ['--foo x a b c d --bar 1', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]]],

              ['--foo x --bar 1 a b c d', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]]],

              ['a b --foo x --bar 1 c d', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]],
                [{"foo":"x","bar":"1","cmd":"a","rest":["b"]},["c","d"]]],

              ['a --foo x b --bar 1 c d', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]],
                [{"foo":"x","bar":"1","cmd":"a","rest":["b"]},["c","d"]], // mixed
                [{"foo":"x","bar":"1","cmd":"a","rest":[]},["b","c","d"]]  // original
              ],

              ['a --foo x b c --bar 1 d', [{"foo":"x","bar":"1","cmd":"a","rest":["b","c","d"]},[]],
                [{"foo":"x","bar":"1","cmd":"a","rest":["b","c"]},["d"]], // mixed
                [{"foo":"x","bar":"1","cmd":"a","rest":[]},["b","c","d"]] // original
              ],

              ['a --foo x b --bar 1 c --error d',
                [{"foo":"x","bar":"1","cmd":"a","rest":["b","c"]},["--error","d"]],
                [{"foo":"x","bar":"1","cmd":"a","rest":["b"]},["c","--error","d"]], // mixed
                [{"foo":"x","bar":"1","cmd":"a","rest":[]},["b","c","--error","d"]] // original
              ],

              ['a --foo x b --error d --bar 1 c',
                [{"foo":"x","bar":"1","cmd":"a","rest":["b"]},["--error","d","c"]],
                [{"foo":"x","bar":"1","cmd":"a","rest":["b"]},["--error","d","c"]], // mixed
                [{"foo":"x","bar":"1","cmd":"a","rest":[]},["b","--error","d","c"]] // original
              ],

              ['a b c', [{"foo":null,"bar":null,"cmd":"a","rest":["b","c"]},[]]],

              ['a', [{"foo":null,"bar":null,"cmd":"a","rest":[]},[]]]];

    failures = ['--foo 1', // error: the following arguments are required: cmd, rest
              '--foo',  // error: argument --foo: expected one argument
              ];
    // parseIntermixedArgs
    for (var ii=0;ii<failures.length;ii++) {
      assert.throws(
        function () {
          // args = parser.parseKnownArgs(split(failures[ii]));
          args = parse_intermixed_args(parser, split(failures[ii]));
        },
        /(the following argument\(s\) are required ||expected one argument)/
      );
    };
    for (var ii=0;ii<successes.length;ii++) {
      var xx = successes[ii];
      var axx = split(xx[0]);
      if (xx.length>2) {
        args = parser.parseKnownArgs(axx);
        assert.deepEqual(args, xx[2]);
      }
      args = parse_intermixed_args(parser, axx);
      assert.deepEqual(args, xx[1]);
    };
  });
});
