/*global describe, it*/

'use strict';

var assert = require('assert');

var ArgumentParser = require('../lib/argparse').ArgumentParser;
// var ArgumentError = require('../lib/argument/error_types').ArgumentError;
try {
  var ArgumentTypeError = require('../lib/argument/error_types').ArgumentTypeError;
} catch (err){
  ArgumentTypeError = require('../lib/error').ArgumentTypeError;
}

describe('user defined type', function () {
  var parser;
  var args;

  it("should handle builtin types", function () {
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--eggs'], {type: 'int'});
    parser.addArgument(['spam'], {type: 'float'});

    args = parser.parseArgs(['--eggs=42', '42']);
    assert.deepEqual(args, {eggs: 42, spam: 42.0});
    args = parser.parseArgs(['1024.675']);
    assert.deepEqual(args, {eggs: null, spam: 1024.675});
    assert.throws(
      function () { parser.parseArgs(['--eggs', 'a']); },
        /Invalid int value: a/i
    );
  });

  it("should handle user-defined type", function () {
    function myType(arg) {
      return arg;
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-x'], {type: myType});
    parser.addArgument(['spam'], {type: myType});

    args = parser.parseArgs(['a', '-x', 'b']);
    assert.deepEqual(args, {x: myType('b'), spam: myType('a')});
    args = parser.parseArgs(['-xf', 'g']);
    assert.deepEqual(args, {x: myType('f'), spam: myType('g')});
  });

  it("should give consistent type errors", function () {
    function dateType(arg) {
      var x = new Date(arg);
      if (x.toString().match('Invalid')) {
        throw new TypeError("" + arg + " is not a valid date.");
      }
      return x;
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-i'], {type: 'int', defaultValue: 0});
    parser.addArgument(['-f'], {type: 'float', defaultValue: 0});
    parser.addArgument(['-d'], {type: dateType, defaultValue: new Date(0)});
    assert.throws(
    function () { parser.parseArgs(['-f', 'abc']); },
      /Invalid float value: abc/i
    );
    assert.throws(
    function () { parser.parseArgs(['-i', 'abc']); },
      /Invalid int value: abc/i
    );
    args = parser.parseArgs([]);
    assert.deepEqual(args, {i: 0, f: 0, d: new Date(0)});
    args = parser.parseArgs(['-d', '1/1/2012']);
    assert.deepEqual(args, {i: 0, f: 0, d: new Date('1/1/2012')});
    assert.throws(
      function () {parser.parseArgs(['-d', '13/1/2000']); },
        /Invalid dateType value: (.*)/i
      /*
      it used to insert the function code rather than its name
      Invalid <dateType.toString()> value: 13/1/2000
      */
    );
    assert.throws(
    function () { parser.parseArgs(['-d', 'abc']); },
      /Invalid dateType value: (.*)/i
    );
  });

  it("test a user-defined type by registering it", function () {
    function dateType(arg) {
      var x = new Date(arg);
      if (x.toString().match('Invalid')) {
        throw new TypeError("" + arg + " is not a valid date.");
      }
      return x;
    }
    parser = new ArgumentParser({debug: true});
    parser.register('type', 'dateType', dateType);
    parser.addArgument(['-d'], {type: 'dateType'});
    args = parser.parseArgs(['-d', '1/1/2012']);
    assert.deepEqual(args, {d: new Date('1/1/2012')});
    assert.throws(
    function () { parser.parseArgs(['-d', '13/1/2000']); },
      /Invalid dateType value: (.*)/
    );
  });

  it("test an anonymous user-defined type", function () {
    var dateType = function (arg) {
      var x = new Date(arg);
      if (x.toString().match('Invalid')) {
        throw new TypeError("" + arg + " is not a valid date.");
      }
      return x;
    };
    //dateType.displayName = 'dateType';
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-d'], {type: dateType});
    args = parser.parseArgs(['-d', '1/1/2012']);
    assert.deepEqual(args, {d: new Date('1/1/2012')});
    assert.throws(
    function () { parser.parseArgs(['-d', 'abc']); },
      /Invalid <function> value: abc/im
    );
  });
  it("test ArgumentTypeError", function () {
    var dateType = function (arg) {
      var x = new Date(arg);
      if (x.toString().match('Invalid')) {
        throw new ArgumentTypeError("" + arg + " is not a valid date.");
      }
      return x;
    };
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-d'], {type: dateType, defaultValue: '12/31/2012'});
    args = parser.parseArgs(['-d', '1/1/2012']);
    assert.deepEqual(args, {d: new Date('1/1/2012')});
    args = parser.parseArgs([]);
    assert.deepEqual(args, {d: new Date('12/31/2012')});
    assert.throws(
      function () { parser.parseArgs(['-d', 'abc']); },
      /abc is not a valid date/im
    );
  });
  it("Check that the type function is called only once", function () {
    var record = [];
    var dateType = function (arg) {
      record.push(arg); // keep record of what arg are sent here
      var x = new Date(arg);
      if (x.toString().match('Invalid')) {
        throw new ArgumentTypeError("" + arg + " is not a valid date.");
      }
      return x;
    };
    function countCalls(parser, argv) {
      record = [];
      args = parser.parseArgs(argv);
      if (record.length !== 1) {
        console.log(args);
        console.log(record);
      }
      assert.equal(record.length, 1);
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['-d'], {type: dateType, defaultValue: '12/31/2012'});
    countCalls(parser, []);
    countCalls(parser, ['-d', '1/1/2012']);
  });
  it("test for delayed default evaluation(2)", function () {
    // delayed default evaluation means an error in the default value
    // is not detected if the default is not used.
    parser = new ArgumentParser({debug: true});
    assert.doesNotThrow(function () {
      parser.addArgument(['-f'], {type: 'float', defaultValue: 'foo'});
      // args = parser.parseArgs([]); // throws ArgumentError
      args = parser.parseArgs(['-f', '1.03']);
    });
  });
  it("TestTypeFunctionCallOnlyOnce", function () {
    function spam(stringToConvert) {
      assert.equal(stringToConvert, 'spam!');
      return 'fooConverted';
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {type: spam, defaultValue: 'bar'});
    args = parser.parseArgs(['--foo', 'spam!']);
    assert.deepEqual({foo: 'fooConverted'}, args);
    // the error with previous code
    // ArgumentError: argument "--foo": Invalid spam value: bar
    // http://hg.python.org/cpython/rev/62b5667ef2f4
  });
  it("TestTypeFunctionCallWithNonStringDefault", function () {
    function spam(intToConvert) {
      assert.equal(intToConvert, 0);
      return 'fooConverted';
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {type: spam, defaultValue: 0});
    args = parser.parseArgs([]);
    // foo shold not be converted because its default is not a string
    assert.deepEqual({foo: 0}, args);
  });
  it("TestTypeFunctionCallWithStringDefault", function () {
    function spam(intToConvert) {
      return 'fooConverted';
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {type: spam, defaultValue: '0'});
    args = parser.parseArgs([]);
    // foo shold not be converted because its default is not a string
    assert.deepEqual({foo: 'fooConverted'}, args);
  });
  it("test no double type conversion of default", function () {
    function extend(strToConvert) {
      return strToConvert + "*";
    }
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {type: extend, defaultValue: '*'});
    args = parser.parseArgs([]);
    // The test argument will be two stars, one coming from the default
    // value and one coming from the type conversion being called exactly
    // once.
    assert.deepEqual({foo: '**'}, args);
  });
  it("test issue 15906", function () {
    // Issue #15906: When action='append', type=str, default=[] are
    // provided, the dest value was the string representation "[]" when it
    // should have been an empty list.
    parser = new ArgumentParser({debug: true});
    parser.addArgument(['--foo'], {dest: 'foo', type: 'string', defaultValue: [], action: 'append'});
    args = parser.parseArgs([]);
    assert.deepEqual(args.foo, []);
  });
});