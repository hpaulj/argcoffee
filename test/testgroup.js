/*global describe, it, beforeEach*/


'use strict';

var assert = require('assert');

var ArgumentParser = require('../lib/argparse').ArgumentParser;
describe('ArgumentParser', function () {
  describe('group', function () {
    var parser;
    var args;
    var group;
    var group1;
    var group2;
    beforeEach(function () {
      // parser = new ArgumentParser({prog: 'PROG', addHelp: false, debug: true});
      // parser.addArgument([ '-f', '--foo' ]);
    });
    
    it('group test', function () {
      parser = new ArgumentParser({prog: 'PROG', addHelp: false, debug: true});
      group = parser.addArgumentGroup({title: 'group'});
      group.addArgument(['--foo'], {help: 'foo help'});
      group.addArgument(['bar'], {help: 'bar help'});
      // what to test for in help?
      // parser.print_help()
      // does group make an difference in parseArgs output?
      assert(group._group_actions.length, 2);
    });

    it('2 group test', function () {
      parser = new ArgumentParser({prog: 'PROG', addHelp: false, debug: true});
      group1 = parser.addArgumentGroup({title: 'group1', description: 'group1 description'});
      group1.addArgument(['foo'], {help: 'foo help'});
      group2 = parser.addArgumentGroup({title: 'group2', description: 'group2 description'});
      group2.addArgument(['--bar'], {help: 'bar help'});
      //parser.print_help();
      assert(group1._group_actions.length, 1);
      assert(parser._action_groups.length, 4); // group1, group2, positionals, optionals
    });

    it('mutually exclusive group test', function () {
      parser = new ArgumentParser({prog: 'PROG', debug: true});
      group = parser.addMutuallyExclusiveGroup();
      group.addArgument(['--foo'], {action: 'storeTrue'});
      group.addArgument(['--bar'], {action: 'storeFalse'});
      args = parser.parseArgs([]);
      // Python: Namespace(bar=True, foo=False)
      assert.equal(args.foo, false);
      assert.equal(args.bar, true);

      args = parser.parseArgs(['--foo']);
      // Python: Namespace(bar=True, foo=True)
      assert.equal(args.foo, true);
      assert.equal(args.bar, true);

      args = parser.parseArgs(['--bar']);
      // Python: Namespace(bar=False, foo=False)
      assert.equal(args.foo || args.bar, false);
    });
    
    it('mutually exclusive group test', function () {
      parser = new ArgumentParser({prog: 'PROG', debug: true});
      group = parser.addMutuallyExclusiveGroup();
      group.addArgument(['--foo'], {action: 'storeTrue'});
      group.addArgument(['--bar'], {action: 'storeFalse'});

      assert.throws(
        function () {
          args = parser.parseArgs(['--foo', '--bar']);
        },
        // Python:  error: argument --bar: not allowed with argument --foo
        // I  had problems with the proper pairing of bar and foo
        // may also test case with 2 overlapping exlusive groups
        // /("--bar"): Not allowed with argument ("--foo")/
        function (err) {
          // right and left actions should be different
          // allow for variations in formatting
          var pat = /(.*): not allowed with argument (.*)/i;
          if (err instanceof Error) {
            var m = err.message.match(pat);
            return m && m[1] !== m[2];
          }
        },
        "unexpected error"
      );
    });
    it('mutually exclusive group test', function () {
      parser = new ArgumentParser({prog: 'PROG', debug: true});
      group = parser.addMutuallyExclusiveGroup({required: true});
      // or should the input be {required: true}?
      group.addArgument(['--foo'], {action: 'storeTrue'});
      group.addArgument(['--bar'], {action: 'storeFalse'});
      assert.equal(group.required, true);
      assert.equal(group._group_actions.length, 2);
      assert.throws(
        function () {
          args = parser.parseArgs([]);
        },
        // Python: error: one of the arguments --foo --bar is required
        /one of the arguments (.*) is required/i
      );
    });
    it('mutually exclusive group usage', function () {
      // adapted from test_argparse.py TestMutuallyExclusiveSimple
      var usage;
      parser = new ArgumentParser({prog: 'PROG', debug: true});
      group = parser.addMutuallyExclusiveGroup({required: true});
      // or should the input be {required: true}?
      group.addArgument(['--bar'], {help: 'bar help'});
      group.addArgument(['--baz'], {nargs: '?', constant: 'Z', help: 'baz help'});   
      args = parser.parseArgs(['--bar', 'X']);
      assert.deepEqual(args, {bar: 'X', baz: null});
   
      assert.throws(
        function () {
            args = parser.parseArgs('--bar X --baz Y'.split(' '));
        },
        /Not allowed with argument/i
      );
      usage = parser.formatUsage();
      assert.equal(usage, 'usage: PROG [-h] (--bar BAR | --baz [BAZ])\n');
      group.required = false;
      usage = parser.formatUsage();
      assert.equal(usage, 'usage: PROG [-h] [--bar BAR | --baz [BAZ]]\n');
      // could also test all or part of parser.formatHelp()
    });
    // related test_argparse.py tests
    // TestMutuallyExclusiveLong - 2 regular arguments, 2 in an MEGroup
    // TestMutuallyExclusiveFirstSuppressed - one argument in group is SUPPRESSED
    // TestMutuallyExclusiveManySuppressed
    it('mutually exclusive optional and positional', function () {
      // adapted from test_argparse.py TestMutuallyExclusiveOptionalAndPositional
      var usage;
      parser = new ArgumentParser({prog: 'PROG', debug: true});
      group = parser.addMutuallyExclusiveGroup({required: true});
      // or should the input be {required: true}?
      group.addArgument(['--foo'], {action: 'storeTrue', help: 'foo help'});
      group.addArgument(['--spam'], {help: 'spam help'});
      group.addArgument(['badger'], {nargs: '*', defaultValue: 'X', help: 'badger help'});
      //args = parser.parseArgs(['--spam', 'S']);
      //assert.deepEqual(args, {foo: false, spam: 'S', badger: 'X'});
      // this fails with 'badger' not allowed with '--spam'
      // parser.parseArgs(['X'])
      // parser.parseArgs(['--foo']) error?
      assert.throws(
        function () {
            args = parser.parseArgs('--foo --spam 5'.split(' '));
        },
        /Not allowed with argument/i
      );
      usage = parser.formatUsage();
      assert.equal(usage, 'usage: PROG [-h] (--foo | --spam SPAM | badger [badger ...])\n');
      group.required = false;
      usage = parser.formatUsage();
      assert.equal(usage, 'usage: PROG [-h] [--foo | --spam SPAM | badger [badger ...]]\n');
      // could also test all or part of parser.formatHelp()
    });
    // 3 more
    
  });
});

