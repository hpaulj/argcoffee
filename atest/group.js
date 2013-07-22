/*global describe, it*/


'use strict';

var assert = require('assert');

var argparse = require('argcoffee');
var ArgumentParser = argparse.ArgumentParser;
var ArgumentError = argparse.ArgumentError;




describe('group', function () {
  var parser;
  var args;
  var group;
  var group1;
  var group2;

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

  it('2 groups test', function () {
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

  it('mutually exclusive group test (2)', function () {
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
        // change to account for difference in ArgumentError formatting
        var pat = /"(.*)": not allowed with argument (.*)/i;
        if (err instanceof ArgumentError) {
          var m = (""+err).match(pat);
          return m && m[1] !== m[2];
        }
      },
      "unexpected error"
    );
  });

  it('mutually exclusive group test (3)', function () {
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

  it('mutually exclusive optional and positional', function () {
    // adapted from test_argparse.py TestMutuallyExclusiveOptionalAndPositional
    var usage;
    parser = new ArgumentParser({prog: 'PROG', debug: true});
    group = parser.addMutuallyExclusiveGroup({required: true});
    // or should the input be {required: true}?
    group.addArgument(['--foo'], {action: 'storeTrue', help: 'foo help'});
    group.addArgument(['--spam'], {help: 'spam help'});
    group.addArgument(['badger'], {nargs: '*', defaultValue: 'X', help: 'badger help'});
    args = parser.parseArgs(['--spam', 'S']);
    assert.deepEqual(args, {foo: false, spam: 'S', badger: 'X'});
    args = parser.parseArgs(['X']);
    assert.deepEqual(args, {"foo": false, "spam": null, "badger": ['X']});
    args = parser.parseArgs(['--foo']);
    assert.deepEqual(args, {foo: true, spam: null, badger: 'X'});
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
  });

  it('two mutually exclusive groups', function () {
    // adapted from test_argparse.py
    var usage, group1, group2;
    parser = new ArgumentParser({prog: 'PROG', debug: true});
    group1 = parser.addMutuallyExclusiveGroup({required: true});
    group1.addArgument(['--foo'], {action: 'storeTrue'});
    group1.addArgument(['--bar'], {action: 'storeFalse'});
    group2 = parser.addMutuallyExclusiveGroup({required: false});
    group2.addArgument(['--soup'], {action: 'storeTrue'});
    group2.addArgument(['--nuts'], {action: 'storeFalse'});
    usage = parser.formatUsage();
    assert.equal(usage, 'usage: PROG [-h] (--foo | --bar) [--soup | --nuts]\n');
  });

  it('suppressed and single action groups', function () {
    // adapted from test_argparse.py
    var usage, group1, group2;
    parser = new ArgumentParser({prog: 'PROG', debug: true});
    group1 = parser.addMutuallyExclusiveGroup();
    group1.addArgument(['--sup'], {help: '==SUPPRESS=='});
    // should produce an empty group (), which is removed
    group2 = parser.addMutuallyExclusiveGroup({required: true});
    group2.addArgument(['--xxx'], {});
    // single entry in a required group, remove group ()
    usage = parser.formatUsage();
    // assert.equal(usage, 'usage: PROG [-h]  --xxx XXX\n');
    // changed by py issue 17890
    assert.equal(usage, 'usage: PROG [-h] --xxx XXX\n');
  });

  it('long usage with special metavars', function () {
    // adapted from test_argparse.py http://bugs.python.org/issue11874
    // tests usage wrapping, and special chars in metavar
    var usage;
    var longA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    var longD = 'dddddddddddddddddddddddddddddddddddddddddddddddddd';
    parser = new ArgumentParser({prog: 'PROG', debug: true});
    parser.addArgument(['--a'], {metavar: longA});
    parser.addArgument(['--b'], {metavar: '[innerpart]outerpart'});
    parser.addArgument(['--c']);
    parser.addArgument(['d'], {metavar: longD});
    parser.addArgument(['e'], {metavar: 'range(0, 20)'});
    parser.addArgument(['foo'], {nargs: '*'});
    usage = parser.formatUsage();
    console.log('\n'+usage);
    assert.equal(usage.split('\n').length,5,'wrong number of lines');
    assert.ok(usage.match(/\[--b \[innerpart\]outerpart\] \[--c C\]/gm),'splitting on []')
    assert.ok(usage.match(/range\(0, 20\)/gm),'removing ()')
  });

  it('mutually exclusive optionals mixed', function () {
    // adapted from test_argparse.py
    // cannot format group with default formatter
    var usage, group;
    parser = new ArgumentParser({prog: 'PROG', debug: true});
        parser.addArgument(['-x'], {action:'storeTrue', help:'x help'});
        group = parser.addMutuallyExclusiveGroup({required:true});
        group.addArgument(['-a'], {action:'storeTrue', help:'a help'});
        group.addArgument(['-b'], {action:'storeTrue', help:'b help'});
        parser.addArgument(['-y'], {action:'storeTrue', help:'y help'});
        group.addArgument(['-c'], {action:'storeTrue', help:'c help'});
    usage = parser.formatUsage();
    assert.equal(usage, 'usage: PROG [-h] [-x] [-a] [-b] [-y] [-c]\n');
    // console.log(parser.formatter_class);
    parser.formatter_class = argparse.MultiGroupHelpFormatter;
    parser.addArgument(['foo']);
    usage = parser.formatUsage();
    assert.equal(usage, 'usage: PROG [-h] [-x] [-y] (-a | -b | -c) foo\n');
  });

  it('mutually exclusive optionals mixed long', function () {
    // adapted from test_argparse.py
    // cannot format group with default formatter
    var usage, group1, group2;
    parser = new ArgumentParser({prog: 'PROG', debug: true});
        parser.addArgument(['-A'], {action:'storeTrue'});
        group1 = parser.addMutuallyExclusiveGroup({required:true});
        group2 = parser.addMutuallyExclusiveGroup({required:false});
        group2.addArgument(['x'], {nargs: '?'});
        group1.addArgument(['-a'],{action:'storeTrue', help:'a help'});
        group1.addArgument(['-b'], {action:'storeTrue', help:'b help'});
        parser.addArgument(['foo']);
        group1.addArgument(['y'], {nargs: '?'});
        group2.addArgument(['-c'], {action:'storeTrue', help:'c help'});
    usage = parser.formatUsage();
    assert.equal(usage, 'usage: PROG [-h] [-A] [-a] [-b] [-c] [x] foo [y]\n');
    // console.log(parser.formatter_class);
    parser.formatter_class = argparse.MultiGroupHelpFormatter;
    usage = parser.formatUsage();
    // x foo y are not in correct parsing order
    // assert.equal(usage, 'usage: PROG [-h] [-A] (-a | -b | y) [x | -c] foo\n');
    assert.equal(usage, 'usage: PROG [-h] [-A] [x | -c] foo (-a | -b | y)\n');
    ['-b X FOO', 'X FOO Y', 'FOO -b -c'].forEach(function(astr) {
        args = parser.parseArgs(astr.split(' '));
        assert.equal(args.foo, 'FOO');
        console.log(args);
    });
  });

  it('mutually exclusive optionals with existing actions', function () {
    // adapted from test_argparse.py
    // can add existing actions to a group
    // actions may occur in more than one group
    var usage, a_action, b_action, c_action, d_action;
    var x_action, foo_action, y_action;
    parser = new ArgumentParser({prog: 'PROG', debug: true});

    a_action = parser.add_argument('-a', {help:'a help'});
    b_action = parser.add_argument('-b', {help:'b help'});
    c_action = parser.add_argument('-c', {help:'c help'});
    d_action = parser.add_argument('-d', {help:'d help'});
    x_action = parser.add_argument('x', {nargs:'?', help:'x help'});
    foo_action = parser.add_argument('foo', {help:'foo help'});
    y_action = parser.add_argument('y', {nargs:'?', help:'y help'});
    parser.add_mutually_exclusive_group({}, [a_action, c_action]);
    parser.add_mutually_exclusive_group({}, [a_action, d_action]);
    parser.add_mutually_exclusive_group({}, [a_action, b_action]);
    parser.add_mutually_exclusive_group({}, [b_action, d_action]);
    parser.add_mutually_exclusive_group({}, [b_action, y_action]);
    parser.add_mutually_exclusive_group({}, [d_action, x_action]);
    usage = parser.formatUsage();
    assert.equal(usage,
        'usage: PROG [-h] [-a A] [-b B] [-c C] [-d D] [x] foo [y]\n');
    // console.log(parser.formatter_class);
    parser.formatter_class = argparse.MultiGroupHelpFormatter;
    usage = parser.formatUsage();
    var expected = '\
usage: PROG [-h] [-a A | -c C] [-a A | -d D] [-a A | -b B] [-b B | -d D]\n\
            [-d D | x] foo [-b B | y]\n';
    assert.equal(usage, expected);
    ['-b B X FOO', 'X FOO Y', 'FOO -b B -c C'].forEach(function(astr) {
        args = parser.parseArgs(astr.split(' '));
        assert.equal(args.foo, 'FOO');
        console.log(args);
    });
  });
});

/*
usage: PROG [-h] [--a aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa]
            [--b [innerpart]outerpart] [--c C]
            dddddddddddddddddddddddddddddddddddddddddddddddddd range(0, 20)
            [foo [foo ...]]

*/
