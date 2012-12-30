'use strict';

var argparse = require('./argcoffee');
module.exports.ArgumentParser = argparse.ArgumentParser;
module.exports.Namespace = argparse.Namespace;
module.exports.Const = argparse.Const;
var path = require('path');
//console.log(path.normalize('.'));
//console.log(process);
var thisdir = process.mainModule.filename;
thisdir = path.dirname(thisdir);
//console.log(thisdir)

// var apdir = '../../argparse/lib/';
// // module.exports.Namespace = require(apdir+'namespace');
// module.exports.Action = argparse.Action; //require(apdir+'./action');
// module.exports.HelpFormatter = argparse.HelpFormatter; //require(apdir+'./help/formatter.js');
// module.exports.Const = argparse.Const; //require(apdir+'./const.js');
