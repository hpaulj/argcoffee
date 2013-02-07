fs = require('fs')
os = require('os')
path = require('path')
assert = require('assert')
_ = require('underscore')
_.str = require('underscore.string')

ArgumentParser = require('../lib/argcoffee').ArgumentParser
# ArgumentParser = require('argparse').ArgumentParser

psplit = (argv) -> (a for a in argv.split(' ') when a?)

NS = (args) ->
  args

file_texts = [
    ['hello', 'hello world!\n'],
    ['recursive', '-a\n'
                  'A\n'
                  '@hello'],
    ['invalid', '@no-such-path\n']
]

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

for tpl in file_texts
  filename =  tpl[0] # '/tmp/' + tpl[0]
  data = tpl[1...].join('')
  fs.writeFileSync(filename, data)



parser = new ArgumentParser({debug: true, fromfile_prefix_chars: '@'})
parser.addArgument(['-a'])
parser.addArgument(['x'])
parser.addArgument(['y'], {nargs:'+'})

console.log parser.formatHelp()
console.log parser.parseArgs(['X','Y'])

failures = ['', '-b', 'X', '@invalid', '@missing']
successes = [
    ['X Y', NS({a:null, x:'X', y:['Y']})],
    ['X -a A Y Z', NS({a:'A', x:'X', y:['Y', 'Z']})],
    ['@hello X', NS({a:null, x:'hello world!', y:['X']})],
    ['X @hello', NS({a:null, x:'X', y:['hello world!']})],
    ['-a B @recursive Y Z', NS({a:'A', x:'hello world!', y:['Y', 'Z']})],
    ['X @recursive Z -a B', NS({a:'B', x:'X', y:['hello world!', 'Z']})],
]

for argv in failures
  try
    args = parser.parseArgs(psplit(argv))
    console.log "TODO, expected error for '#{argv}'"
    console.log args
  catch error
    console.log _.str.strip(error.message)
    console.log "error as expected for '#{argv}'"
  console.log ''
    
for arg in successes
  [argv, ns] = arg
  console.log argv,'=>', ns
  try
    args = parser.parseArgs(psplit(argv))
    assert.deepEqual(args, ns)
  catch error
    console.log 'TODO',error
  console.log ''

#----------------

parser = new ArgumentParser({debug: true, fromfile_prefix_chars: '@'})
parser.addArgument(['y'], {nargs:'+'})

parser.convert_arg_line_to_args = (arg_line) ->
  # split line into 'words'
  return (arg for arg in arg_line.split(' ') when arg.trim().length)
# use the same hello as before

successes = [['@hello X', NS({y:['hello', 'world!', 'X']})]]
for arg in successes
  [argv, ns] = arg
  console.log argv,'=>', ns
  try
    args = parser.parseArgs(psplit(argv))
    assert.deepEqual(args, ns)
  catch error
    console.log 'TODO',error
  console.log ''


teardown_tempdir(oldcwd)
    
###
another test creates new ArgumentParser class, one with a custom
convert_arg_line_to_args() function

    class FromFileConverterArgumentParser(ErrorRaisingArgumentParser):

        def convert_arg_line_to_args(self, arg_line):
            for arg in arg_line.split():
                if not arg.strip():
                    continue
                yield arg
    parser_class = FromFileConverterArgumentParser

###
