
fs = require('fs')
os = require('os')
path = require('path')
assert = require('assert')
_ = require('underscore')
_.str = require('underscore.string')

print = console.log

argparse = require('../lib/argcoffee')
# argparse = require('argparse')

psplit = (argv) -> (a for a in argv.split(' ') when a?)

NS = (args) ->
  args


setup_tempdir = () ->
  tdir = path.join(os.tmpDir(),'argparse_temp')
  try
    fs.mkdirSync(tdir)
  catch error
    if not error.message.match(/EEXIST/)
      throw error
  oldcwd = process.cwd()
  process.chdir(tdir)
  console.log 'Now in '+ process.cwd()
  return oldcwd
  
teardown_tempdir = (oldcwd) ->
  tdir = process.cwd()
  process.chdir(oldcwd)
  if _.str.startsWith(tdir,os.tmpDir())
    for f in fs.readdirSync(tdir)
      fs.unlinkSync(path.join(tdir,f))
    fs.rmdir(tdir)
    console.log 'Removed ' + tdir
  
oldcwd = setup_tempdir()

psplit = (astring) ->
  # split that is closer the python split()
  # psplit('') produces [], not ['']
  if astring.split?
    result = astring.split(' ')
    result = (r for r in result when r) # remove ''
    return result
  return astring # it probably is a list already


for file_name in ['foo', 'bar']
    fs.writeFileSync(file_name, "Content of #{file_name}")

try
  fs.writeFileSync('readonly','readonly content')
  fs.chmodSync('readonly', '444')
catch error
  # Error: EACCES, permission denied 'readonly'

print argparse.FileType()

parser = new argparse.ArgumentParser({debug:true})
parser.addArgument(['-x'],{type:argparse.FileType()})
parser.addArgument(['spam'],{type:argparse.FileType('r')})

failures = ['-x', '-x bar', 'non-existent-file.txt']

RFile = (filename) ->
  # something that compare itself with the NS arg
  # which is either a fd number or stdin obj
  # don't know if there is a way of getting filename from a fd
  return filename


successes = [
    ['foo', NS({x:null, spam:RFile('foo')})],
    ['-x foo bar', NS({x:RFile('foo'), spam:RFile('bar')})],
    ['bar -x foo', NS({x:RFile('foo'), spam:RFile('bar')})],
    ['-x - -', NS({x:process.stdin, spam:process.stdin})],
    ['readonly', NS({x:null, spam:RFile('readonly')})],
]

print parser.formatHelp()

# print parser

args = parser.parseArgs(['foo'])
print args
# args.spam is fd (filehandle, e.g. 7)
print fs.readSync(args.spam, 1000)

print 'fd stats', fs.fstatSync(args.spam)
print 'foo stats', fs.statSync('foo')
fs.closeSync(args.spam)

args = parser.parseArgs(psplit('-x foo bar'))
print args
print 'boo', fs.fstatSync(args.spam)
fs.closeSync(args.x)
fs.closeSync(args.spam)

args = parser.parseArgs(psplit('-x - -'))
print args.x.fd, args.spam.fd
# args.x is process.stdin, an object
# 
