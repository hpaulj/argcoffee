// http://bugs.python.org/issue16142
// user wants '-k -u', '-ku', '-uk' to all return same
// patch alters error response in the '-ku' case
// but does not change the '-uk' case
// in argparse '-uk' is a valid option string

var argparse = require('argcoffee');

var parser = new argparse.ArgumentParser({debug: true});
parser.addArgument(['-k','--known'], {action: 'storeTrue'});
console.log(parser.parseKnownArgs(['-k','-u'])); // [ { known: true }, [ '-u' ] ]
console.log(parser.parseKnownArgs(['-ku'])); // ArgumentError: argument "-k/--known": ignored explicit argument u
console.log(parser.parseKnownArgs(['-uk'])); // [ { known: false }, [ '-uk' ] ]

console.log(parser.parseKnownArgs(['-kuu']));
parser.addArgument(['-f','--foo']);
console.log(parser.parseKnownArgs(['-kufa']));
console.log(parser.parseKnownArgs(['-kuf','a']));
console.log(parser.parseKnownArgs(['-kufu']));