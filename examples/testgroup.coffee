argparse = require('argparse')

parser = new argparse.ArgumentParser({prog: 'Prog', addHelp: true})

parser.addArgument(['--xxx'])
parser.addArgument(['-d','--debug'],{action: 'storeTrue', defaultValue: false, help: 'extra debug output'})

group1 = parser.addArgumentGroup({title:'group1'})
group1.addArgument(['--foo'],{help: 'foo help'})
group1.addArgument(['bar'],{help: 'bar help'})

console.log parser.formatHelp()
# python help displays 'group'

group2 = parser.addArgumentGroup({title:'group2',description:'2nd group',prefixChars:'-+'})
group2.addArgument(['--foobar'],{help: 'foobar help'})
console.log parser.formatHelp()

if process.argv.length>2
    console.log args = parser.parseArgs()
else
    console.log args = parser.parseArgs('--foo 1 --foobar 2 3'.split(' '))

if args.debug
    console.log '========================='
    _ = require('underscore')
    util = require('util')
    console.log util.inspect(parser,false,1)
    console.log _.keys(parser)
# requires title option to function properly

