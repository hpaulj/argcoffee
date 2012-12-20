'use strict';

module.exports.ArgumentParser = require('./argcoffee').ArgumentParser;
var path = require('path');
//console.log(path.normalize('.'));
//console.log(process);
var thisdir = process.mainModule.filename;
thisdir = path.dirname(thisdir);
//console.log(thisdir)
var apdir = '../../argparse/lib/';
module.exports.Namespace = require(apdir+'namespace');
module.exports.Action = require(apdir+'./action');
module.exports.HelpFormatter = require(apdir+'./help/formatter.js');
module.exports.Const = require(apdir+'./const.js');
