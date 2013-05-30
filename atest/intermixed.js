/*global describe, it*/

'use strict';

var assert = require('assert');

var ArgumentParser = require('argcoffee').ArgumentParser;
var $$ = require('argcoffee').Const;
var split = require('underscore.string').words;

describe('intermixed optionals and postionals', function () {
  var parser;
  var args;
  it('test permutations of arguments', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {dest: 'foo', required: true});
    parser.addArgument(['--bar'], {dest: 'bar'});
    parser.addArgument(['cmd']);
    parser.addArgument(['rest'], {nargs: '*', type: 'int'});

    var ns = { foo: 'x', bar: 'y', cmd: 'cmd1', rest: [1, 2, 3] };
    args = parser.parseArgs(split('cmd1 1 2 3 --foo x --bar y'));
    assert.deepEqual(args, ns);
    args = parser.parseArgs(split('--foo x cmd1 1 2 3 --bar y'));
    assert.deepEqual(args, ns);
    args = parser.parseArgs(split('--foo x --bar y cmd1 1 2 3'));
    assert.deepEqual(args, ns);

    // optionals split up 'rest'
    assert.throws(function () {
      args = parser.parseArgs(split('cmd1 1 --foo x --bar y 2 3'));
    }, /unrecognized arguments: 2 3/);
    args = parser.parse_known_args(split('cmd1 1 --foo x --bar y 2 3'));
    assert.deepEqual(args, [{"foo": "x", "bar": "y", "cmd": "cmd1", "rest": [1]}, ["2", "3"]]);
    args = parser.parse_intermixed_args(split('cmd1 1 --foo x --bar y 2 3'));
    assert.deepEqual(args, ns);

    args = parser.parse_intermixed_args(split('cmd1 --foo x 1 --bar y 2 3'));
    assert.deepEqual(args, ns);
    args = parser.parse_intermixed_args(split('cmd1 --foo x 1 2 --bar y 3'));
    assert.deepEqual(args, ns);

    // optional like extras
    assert.throws(function () {
      args = parser.parseArgs(split('cmd1 --foo x 1 --bar y 2 --error 3'));
    }, /unrecognized arguments: 2 --error 3/);
    assert.throws(function () {
      args = parser.parse_intermixed_args(split('cmd1 --foo x 1 --bar y 2 --error 3'));
    }, /unrecognized arguments: --error 3/);
    args = parser.parse_known_intermixed_args(split('cmd1 --foo x 1 --bar y 2 --error 3'));
    assert.deepEqual(args, [{"foo": "x", "bar": "y", "cmd": "cmd1", "rest": [1, 2]}, ["--error", "3"]]);

    assert.throws(function () {
      args = parser.parse_intermixed_args(split('cmd1 --foo x 1 --error 2 --bar y 3'));
    }, /unrecognized arguments: --error 2 3/);

    args = parser.parse_intermixed_args(split('cmd1 1 --foo x 2'));
    assert.deepEqual(args, {"foo": "x", "bar": null, "cmd": "cmd1", "rest": [1, 2]});

    assert.throws(function () {
      args = parser.parse_intermixed_args(split('cmd1 1 2 3'));
    }, /the following argument\(s\) are required: --foo/);
    assert.throws(function () {
      args = parser.parse_intermixed_args(split('--foo 1'));
    }, /the following argument\(s\) are required: cmd,rest/);
    assert.throws(function () {
      args = parser.parse_intermixed_args(split('--foo'));
    }, /argument "--foo": expected one argument/);
  });

  it('test intermixed with REMAINDER', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-z'])
    parser.addArgument(['x'])
    parser.addArgument(['y'], {nargs: $$.REMAINDER})
    args = parser.parseArgs(split('X A B -z Z'));
    assert.deepEqual(args, {"z":null, "x": "X", "y": ["A", "B", "-z", "Z"]});
    assert.throws(function () {
      args = parser.parse_intermixed_args(split('X A B -z Z'));
    }, /parse_intermixed_args: positional arg with nargs=.../);
  });

  it('test intermixed with subparser', function () {
    parser = new ArgumentParser({debug: true});
    var sp = parser.add_subparsers()
    var spp = sp.add_parser('cmd')
    spp.add_argument('foo')
    args = parser.parseArgs(split('cmd 1'));
    assert.deepEqual(args, {"foo": "1"});
    assert.throws(function () {
      args = parser.parse_intermixed_args(split('cmd 1'));
    }, /parse_intermixed_args: positional arg with nargs=A.../);
  });

  it('test intermixed with mutually exclusive group', function () {
    parser = new ArgumentParser({debug: true});
    var group = parser.addMutuallyExclusiveGroup({required:true})
    group.addArgument(['--foo'], {action: 'storeTrue', help: 'FOO'})
    group.addArgument(['--spam'], {help: 'SPAM'})
    assert.throws(function () {
      args = parser.parseArgs([]);
    }, /one of the arguments --foo --spam is required/);
    assert.throws(function () {
      args = parser.parse_intermixed_args([]);
    }, /one of the arguments --foo --spam is required/);
    args = parser.parse_intermixed_args(split('--spam x'));
    assert.deepEqual(args, {"foo":false, "spam": "x"});
  });

  it('test intermixed with mutually exclusive group, both', function () {
    parser = new ArgumentParser({debug: true});
    var group = parser.addMutuallyExclusiveGroup({required:true})
    group.addArgument(['--foo'], {action:'storeTrue', help:'FOO'})
    group.addArgument(['--spam'], {help:'SPAM'})
    group.addArgument(['badger'], {nargs:'*', defaultValue:'X', help:'BADGER'})
    assert.throws(function () {
      args = parser.parseArgs([]);
    }, /one of the arguments --foo --spam badger is required/);
    assert.throws(function () {
      args = parser.parse_intermixed_args([]);
    }, /parse_intermixed_args: positional in mutuallyExclusiveGroup/);
  });
});
