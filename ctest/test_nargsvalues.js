// test nargs error messages
// negative integer (nargs=-1), error or behave just like nargs=0?
// in py, just like 0, since nargs is used to replicate strings
// in range(nargs) and 'str'*nargs

// nargs='1' - integer like string
//   in py can do int(nargs)
//   but in my patch it triggers ArgumentError

// nargs='test' - ArgumentError

// nargs does not match metavar tuple
//    py raises error; changing that to ArgumentParser

// where to do error checking:
// in py patch move it to a ArgumentParser _check_argument
// set up group to call its container's

// need to also test a group

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

describe('nargs', function () {
  var parser;
  var args;
  it('test specifying the 1 arg for an Optional', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument([ '-x' ], { nargs: 1 });

    args = parser.parseArgs([]);
    assert.deepEqual(args, { x: null });
    args = parser.parseArgs([ '-x', 'a' ]);
    assert.deepEqual(args, { x: [ 'a' ] });

    assert.throws(function () {
      args = parser.parseArgs([ 'a' ]);
    });
    assert.throws(function () {
      args = parser.parseArgs([ '-x' ]);
    });
  });

  it('test specifying the -1 arg', function () {
    parser = new ArgumentParser({debug: true});
        assert.throws(function () {
      parser.addArgument([ 'foo' ], { nargs: -1 });
    },
    /less than 0/);
    /*
    args = parser.parseArgs([]);
    assert.deepEqual(args, { foo: [] });
    parser.addArgument(['bar'],{nargs: 2})
    var help = parser.formatHelp();
    console.log(help)
    assert.ok(help.match(/\[-h\]\s+bar bar/))
    // 1 or 2 spaces at the \s
    assert.ok(help.match(/foo\n  bar/))
    */
  });

  it('should give error if narg not valid string or integer', function () {
    parser = new ArgumentParser({debug: true});
        assert.throws(function () {
      parser.addArgument([ 'foo' ], { nargs: 'test' });
    },
    /not a valid string or integer/);
    /*
    args = parser.parseArgs([]);
    console.log(args)
    var help = parser.formatHelp();
    console.log(help)
    */
  });

  it('should give error if narg not valid string or integer; group', function () {
    parser = new ArgumentParser({debug: true});
    var group = parser.addArgumentGroup({title: 'g'});
    group.addArgument(['bar'], {nargs: '*'});
        assert.throws(function () {
      group.addArgument([ 'foo' ], { nargs: 'test' });
    },
    /not a valid string or integer/);
  });

  it('should give error if narg is string integar; or should it?', function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument([ 'foo' ], { nargs: '2' });
    args = parser.parseArgs(['1','2']);
    assert.deepEqual(args, { foo: [ '1', '2' ] })
    /*
    console.log(args)
    var help = parser.formatHelp();
    console.log(help)
    */
  });

  it('should handle metavar as an array', function () {
    // from formatters.js
    parser = new argparse.ArgumentParser({
      prog: 'PROG'
    });

    parser.addArgument(['-w'], {
      help: 'w',
      nargs: '+',
      metavar: ['W1', 'W2']
    });

    parser.addArgument(['-x'], {
      help: 'x',
      nargs: '*',
      metavar: ['X1', 'X2']
    });

    parser.addArgument(['-y'], {
      help: 'y',
      nargs: 3,
      metavar: ['Y1', 'Y2', 'Y3']
    });

    parser.addArgument(['-z'], {
      help: 'z',
      nargs: '?',
      metavar: ['Z1']
    });

    var helptext = parser.formatHelp();
    var ustring = 'PROG [-h] [-w W1 [W2 ...]] [-x [X1 [X2 ...]]] [-y Y1 Y2 Y3] [-z [Z1]]';
    ustring = ustring.replace(/\[/g, '\\[').replace(/\]/g, '\\]');
    // have to escape all of those brackets
    assert(helptext.match(new RegExp(ustring)));

/*
usage: PROG [-h] [-w W1 [W2 ...]] [-x [X1 [X2 ...]]] [-y Y1 Y2 Y3] [-z [Z1]]

optional arguments:
  -h, --help        show this help message and exit
  -w W1 [W2 ...]    w
  -x [X1 [X2 ...]]  x
  -y Y1 Y2 Y3       y
  -z [Z1]           z
*/
  });

  it('should give error if matavar array does not match nargs', function () {
    // from formatters.js
    parser = new argparse.ArgumentParser({prog: 'PROG'});

    assert.throws(function () {
      parser.addArgument(['-foo','-f'], {nargs: '3', metavar: ['X', 'Y']});
    },
    /length of metavar tuple does not match nargs/);

    parser.addArgument(['-y'], {
      help: 'y',
      nargs: 3,
      metavar: ['Y1', 'Y2', 'Y3']});
    // console.log(parser.formatHelp());
  });
/*
class TestAddArgumentMetavar(TestCase):

    EXPECTED_MESSAGE = "length of metavar tuple does not match nargs"

    def do_test_no_exception(self, nargs, metavar):
        parser = argparse.ArgumentParser()
        parser.add_argument("--foo", nargs=nargs, metavar=metavar)

    def do_test_exception(self, nargs, metavar):
        parser = argparse.ArgumentParser()
        with self.assertRaises(ValueError) as cm:
            parser.add_argument("--foo", nargs=nargs, metavar=metavar)
        self.assertEqual(cm.exception.args[0], self.EXPECTED_MESSAGE)

    # Unit tests for different values of metavar when nargs=None

    def test_nargs_None_metavar_string(self):
        self.do_test_no_exception(nargs=None, metavar="1")

    def test_nargs_None_metavar_length0(self):
        self.do_test_exception(nargs=None, metavar=tuple())

    def test_nargs_None_metavar_length1(self):
        self.do_test_no_exception(nargs=None, metavar=("1"))

    def test_nargs_None_metavar_length2(self):
        self.do_test_exception(nargs=None, metavar=("1", "2"))

    def test_nargs_None_metavar_length3(self):
        self.do_test_exception(nargs=None, metavar=("1", "2", "3"))
*/

});
