/*
class TestDoubleDashRemoval(ParserTestCase):
    """Test actions with multiple -- values"""

    """argparse removed all '--'
    a 3-2012 patch removed just the 1st -- of each positional group
    this new patch removes just the 1st --
    this change is most valuable when passing arg strings to another process"""
    argument_signatures = [
        Sig('-f', '--foo', help='an optional'),
        Sig('cmd', help='a command'),
        Sig('rest', nargs='*', help='zero or more args'),
    ]
    failures = ['cmd --foo bar 1 2 3', 'cmd -f1 2 3']
    successes = [
        ('-f1 1 -- 2 3', NS(cmd='1', foo='1', rest=['2', '3'])),
        ('cmd -- --foo bar', NS(cmd='cmd', foo=None, rest=['--foo', 'bar'])),
        ('cmd -- --foo -- -f2', NS(cmd='cmd', foo=None, rest=['--foo', '--', '-f2'])),

        ('-- --foo -- --bar 2', NS(cmd='--foo', foo=None, rest=['--', '--bar', '2'])),
        # NS(cmd='--foo', foo=None, rest=['--bar', '2']) old

        ('-f1 -- -- 1 -- 2', NS(cmd='--', foo='1', rest=['1', '--', '2'])),
        # NS(cmd=[], foo='1', rest=['1', '2']) older, note cmd=[]
        # NS(cmd='--', foo='1', rest=['1', '2']) old

        ('-- cmd -- -- --foo', NS(cmd='cmd', foo=None, rest=['--', '--', '--foo'])),
        # NS(cmd='cmd', foo=None, rest=['--foo'])  older
        # NS(cmd='cmd', foo=None, rest=['--', '--foo']) old
    ]

class TestDoubleDashRemoval1(ParserTestCase):
    """Test actions with multiple -- values, with '+' positional"""

    argument_signatures = [
        Sig('-f', '--foo', help='an optional'),
        Sig('cmd', help='a command'),
        Sig('rest', nargs='+', help='1 or more args'),
    ]
    failures = ['cmd -f1', '-f1 -- cmd', '-f1 cmd --']
    successes = [
        ('cmd -f1 2 3', NS(cmd='cmd', foo='1', rest=['2', '3'])),
        ('cmd -f1 -- 2 3', NS(cmd='cmd', foo='1', rest=['2', '3'])),
        ('-f1 -- cmd -- -f2 3', NS(cmd='cmd', foo='1', rest=['--', '-f2', '3'])),
    ]

http://bugs.python.org/issue14364
http://bugs.python.org/issue13922
*/

/*global describe, it*/

'use strict';

var assert = require('assert');
var _ = require('underscore');
_.str = require('underscore.string');


var lib = 1 ? '../lib/allinone' : 'argparse';
console.log(lib)
var argparse = require(lib);
var ArgumentParser = require(lib).ArgumentParser;
var ArgumentError = require(lib).ArgumentError;

describe('double dash removal', function () {
  var parser;
  var args;
  it('Test actions with multiple -- values', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-f', '--foo'], {help: 'an optional'});
    parser.addArgument(['cmd'], {help: 'a command'});
    parser.addArgument(['rest'], {nargs: '*', help: 'zero or more args'});
    var failures = ['cmd --foo bar 1 2 3', 'cmd -f1 2 3']
    for (var ii=0; ii<failures.length; ii += 1) {
      assert.throws(function () {
        args = parser.parseArgs(failures[ii].split(' '));
      });
    };
    var successes = [
        ['-f1 1 -- 2 3', {cmd:'1', foo:'1', rest:['2', '3']}],
        ['cmd -- --foo bar', {cmd:'cmd', foo:null, rest:['--foo', 'bar']}],
        ['cmd -- --foo -- -f2', {cmd:'cmd', foo:null, rest:['--foo', '--', '-f2']}],

        ['-- --foo -- --bar 2', {cmd:'--foo', foo:null, rest:['--', '--bar', '2']}],
        // NS(cmd='--foo', foo=null, rest=['--bar', '2']) old

        ['-f1 -- -- 1 -- 2', {cmd:'--', foo:'1', rest:['1', '--', '2']}],
        // NS(cmd=[], foo='1', rest=['1', '2']) older, note cmd=[]
        // NS(cmd='--', foo='1', rest=['1', '2']) old

        ['-- cmd -- -- --foo', {cmd:'cmd', foo:null, rest:['--', '--', '--foo']}],
        // NS(cmd='cmd', foo=null, rest=['--foo'])  older
        // NS(cmd='cmd', foo=null, rest=['--', '--foo']) old
    ];
    for (var ii=0; ii<successes.length; ii += 1) {
      args = parser.parseArgs(successes[ii][0].split(' '));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it('Test actions with multiple -- values, with '+' positional', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-f', '--foo'], {help: 'an optional'});
    parser.addArgument(['cmd'], {help: 'a command'});
    parser.addArgument(['rest'], {nargs: '+', help: 'one or more args'});
    var failures = ['cmd -f1', '-f1 -- cmd', '-f1 cmd --']
    for (var ii=0; ii<failures.length; ii += 1) {
      assert.throws(function () {
        args = parser.parseArgs(failures[ii].split(' '));
      });
    };
    var successes = [
      ['cmd -f1 2 3', {cmd:'cmd', foo:'1', rest:['2', '3']}],
      ['cmd -f1 -- 2 3', {cmd:'cmd', foo:'1', rest:['2', '3']}],
      ['-f1 -- cmd -- -f2 3', {cmd:'cmd', foo:'1', rest:['--', '-f2', '3']}],
    ];
    for (var ii=0; ii<successes.length; ii += 1) {
      args = parser.parseArgs(successes[ii][0].split(' '));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it('Test an Optional with a single-dash option string', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-x']);
    var failures = ['-x', 'a', '--foo', '-x --foo', '-x -y', '-x -- bar']
    for (var ii=0; ii<failures.length; ii += 1) {
      assert.throws(function () {
        args = parser.parseArgs(failures[ii].split(' '));
      });
    };
    var successes = [
      ['-x a', {x: 'a'}],
      ['-x-1', {x: '-1'}],
      ['-x--', {x: '--'}],
    ];
    for (var ii=0; ii<successes.length; ii += 1) {
      args = parser.parseArgs(successes[ii][0].split(' '));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

  it('Test an Optional with a double-dash option string', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo']);
    var failures = ['--foo', '-f', '-f a', 'a', '--foo -x', '--foo --bar','--foo -- bar']
    for (var ii=0; ii<failures.length; ii += 1) {
      assert.throws(function () {
        args = parser.parseArgs(failures[ii].split(' '));
      });
    };
    var successes = [
      ['--foo=-2.5', {foo: '-2.5'}],
      ['--foo=--', {foo: '--'}],
    ];
    for (var ii=0; ii<successes.length; ii += 1) {
      args = parser.parseArgs(successes[ii][0].split(' '));
      assert.deepEqual(args, successes[ii][1]);
    };
  });

});
