'use strict';

var argparse = require('./argcoffee');
/*
module.exports.ArgumentParser = argparse.ArgumentParser;
module.exports.Namespace = argparse.Namespace;
module.exports.Const = argparse.Const;
module.exports.FileType = argparse.FileType;
*/
var path = require('path');

for (var key in argparse) {
    module.exports[key] = argparse[key];
}

// generalize to pass all formatters
var helpers = require('./helpformatter');
for (var key in helpers) {
    module.exports[key] = helpers[key];
}
//s exports.ArgumentDefaultsHelpFormatter = require('./helpformatter').ArgumentDefaultsHelpFormatter