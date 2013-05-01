/*global describe, it*/


'use strict';

var assert = require('assert');
var argparse = require('argcoffee')
var ArgumentParser = argparse.ArgumentParser;
var Namespace = argparse.Namespace;

describe('allinone additions', function () {
  var parser;
  var args;

  it("should be ok with scientific notation", function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--xlim'], {nargs: 2, type: 'float'});

    args = parser.parseArgs(['--xlim', '-.002', '1e4']);
    assert.deepEqual(args, {xlim: [-.002, 1e4]});
    args = parser.parseArgs(['--xlim', '-0.002', '1e4']);
    assert.deepEqual(args, {xlim: [-.002, 1e4]});
    args = parser.parseArgs(['--xlim', '2.e3', '-1e4']);
    assert.deepEqual(args, {xlim: [2e3, -1e4]});
    args = parser.parseArgs(['--xlim', '-2.12e3', '-1e4']);
    assert.deepEqual(args, {xlim: [-2.12e3, -1e4]});
  });

  it('option-like positionals not accepted', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--onetwo'], {nargs: 2});

    args = parser.parseArgs(['--onetwo', 'one', 'two']);
    assert.deepEqual(args, { onetwo: [ 'one', 'two' ] });

    assert.throws(
      function () {
        parser.parseArgs(['--onetwo', 'one', '-two']);
      },
      /expected 2 argument/i
    );
    assert.throws(
      function () {
        args = parser.parseArgs(['--onetwo', 'one', '--', '-two']);
      },
      /expected 2 argument/i
    );
  });
  it('option-like positionals not accepted', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--one'], {nargs: 1});
    parser.addArgument(['two'], {nargs: '?'});
    args = parser.parseArgs(['--one', 'one', 'two']);
    assert.deepEqual(args, { one: [ 'one' ], two: 'two' });
    args = parser.parseArgs(['--one', 'one', '--', '-two']);
    assert.deepEqual(args, { one: [ 'one' ], two: '-two' });
    assert.throws(
      function () {
        args = parser.parseArgs(['--one=-one', '-two']);
      },
      /unrecognized arguments: -two/i
    );
  });

  it('args_default_to_positional:true', function () {
    parser = new ArgumentParser({debug: true, args_default_to_positional: true});
    parser.addArgument(['--onetwo'], {nargs: 2});
    args = parser.parseArgs(['--onetwo', 'one', 'two']);
    assert.deepEqual(args, { onetwo: [ 'one', 'two' ] });
    args = parser.parseArgs(['--onetwo', 'one', '-two']);
    assert.deepEqual(args, { onetwo: [ 'one', '-two' ] });
    assert.throws(function () {
      parser.parseArgs(['--onetwo', 'one', '--', '-two']);
      // no -- within optional and its args
    });
    assert.deepEqual(args, { onetwo: [ 'one', '-two' ] });
  });
  it('option-like positionals not accepted', function () {
    parser = new ArgumentParser({debug: true, args_default_to_positional: true});
    parser.addArgument(['--one'], {nargs: 1});
    parser.addArgument(['two'], {nargs: '?'});
    args = parser.parseArgs(['--one', 'one', 'two']);
    assert.deepEqual(args, { one: [ 'one' ], two: 'two' });
    args = parser.parseArgs(['--one', 'one', '--', '-two']);
    assert.deepEqual(args, { one: [ 'one' ], two: '-two' });
    args = parser.parseArgs(['--one=-one', '-two']);
    assert.deepEqual(args, { one: [ '-one' ], two: '-two' });
  });

  // py issue http://bugs.python.org/issue9253   (subparsers required/or not)
  it('test error msg when cmd is missing or wrong', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {action: 'storeTrue'});
    parser.addArgument(['bar'], {type: 'float'});
    var subparsers = parser.addSubparsers({title: 'commands'});
    var parser1 = subparsers.addParser('1');
    parser1.addArgument(['-w']);
    var parser2 = subparsers.addParser('2');
    // console.log(parser._actions)
    // console.log('commands required:', subparsers.required)
    args = parser.parseArgs(['0.5', '1', '-wW']);
    assert.deepEqual(args, { foo: false, bar: 0.5, w: 'W' });
    //console.log(parser.parseArgs(['0.5']))
    assert.throws(
      function () {
        args = parser.parseArgs(['0.5']);
      },
      // /too few arguments/i
      /the following argument\(s\) are required: {1\/2}/
    );
    // test error msg when cmd is wrong choice
    assert.throws(
      function () {
        parser.parseArgs(['0.5', '0']);
      },
      /ArgumentError: argument "{1\/2}": invalid choice: 0 \(choose from 1,2\)/i
    );
  });
  it('test ability to change "required"; default is True', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {action: 'storeTrue'});
    parser.addArgument(['bar'], {type: 'float'});
    var subparsers = parser.addSubparsers({title: 'commands', required: false});
    var parser1 = subparsers.addParser('1');
    parser1.addArgument(['-w']);
    var parser2 = subparsers.addParser('2');
    args = parser.parseArgs(['0.5', '1', '-wW']);
    assert.deepEqual(args, { foo: false, bar: 0.5, w: 'W' });
    args = parser.parseArgs(['0.5']);
    assert.deepEqual(args, { foo: false, bar: 0.5});
  });
  it('test error msg when cmd is missing or wrong; metavar', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {action: 'storeTrue'});
    parser.addArgument(['bar'], {type: 'float'});
    var subparsers = parser.addSubparsers({title: 'commands', metavar: 'COMMANDS'});
    var parser1 = subparsers.addParser('1');
    parser1.addArgument(['-w']);
    var parser2 = subparsers.addParser('2');
    args = parser.parseArgs(['0.5', '1', '-wW']);
    assert.deepEqual(args, { foo: false, bar: 0.5, w: 'W' });
    //console.log(parser.parseArgs(['0.5']))
    assert.throws(
      function () {
        args = parser.parseArgs(['0.5']);
      },
      /the following argument\(s\) are required: COMMANDS/
    );
    // test error msg when cmd is wrong choice
    assert.throws(
      function () {
        parser.parseArgs(['0.5', '0']);
      },
      /ArgumentError: argument "COMMANDS": invalid choice: 0 \(choose from 1,2\)/i
    );
  });

});

// maybe also test when subparsers is given a dest