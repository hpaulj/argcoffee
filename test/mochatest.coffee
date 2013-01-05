# ./mocha --compilers coffee:coffee-script test/temptest.coffee


assert = require('assert')

ArgumentParser = require('../lib/argparse').ArgumentParser
describe 'test_argparse.py', () ->
    describe '....', () ->
        it 'TestClassName', () ->
            parser = new ArgumentParser({debug:true, prog:'testname'})
            parser.addArgument(['-f','--foo'], {nargs:'*'})
            
            args = parser.parseArgs([])
            assert.deepEqual(args, {foo:null})
            
        it 'TestClassName', () ->
            parser = new ArgumentParser({debug:true, prog:'testname'})
            parser.addArgument(['-f','--foo'], {nargs:'*'})
            
            args = parser.parseArgs([])
            assert.deepEqual(args, {foo:null})
            
