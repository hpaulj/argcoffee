# test the argparse FileType
# roughly the same as OS cat command
fs = require('fs')
print = console.error
ap = require('argcoffee')
ap.FileType = ap.fileType # test the fn version
print ap.FileType('r').toString()
meStream = ap.FileType()(process.argv[1])

helpstr = 'Functionality is roughly that of <cat>'
parser = ap.newParser({epilog: helpstr})
parser.add_argument('-i', '--infile', {type:ap.FileType({flags: 'r', encoding:'utf8'}), \
   defaultValue: meStream, \
   help: 'Input filename or `-` (default is itself)'})
a = parser.add_argument('-o', '--outfile', {type:ap.FileType({flags: 'w'}), \
   help: 'Output filename or `-`'})
print parser.format_help()


if process.argv[2]?
  argv = null # use default process.argv
else
  argv = ['-i', './README.md']
args = parser.parse_args(argv)

print args
print ''
readStream = args.infile
writeStream = args.outfile

# direct read of file, without stream 'baggage'
# use of stream does not force use to
if false
  print fs.readSync(readStream.fd,100)


if readStream?
  readStream.on 'error', (error) -> print error
  
if writeStream?
  writeStream.on('open', () ->
    print "wrote to #{writeStream.path}"
    )
  writeStream.on 'error', (error) -> print error
  readStream.on('end', () ->
    print 'pipe end'
    )
  readStream.resume()
  readStream.pipe(writeStream, {end: false})
else

  readStream.on('open', -> print readStream.path)
  # readStream.on('data', (data)->print data.toString('utf8'))
  readStream.on('data', (data)->print data)
  readStream.on('end', ()->print '\nStream END')

        
print 'after setup'
  
###
data2array = (data) ->
  # convert data to lines
  lines = []
  line = ''
  for d in data.toString('utf8')
    if d == '\n'
      lines.push(line)
      line = ''
    else
      line += d
  lines
    

foo = ({x, y}) -> [x,y]
foo({z:3,x:4,y:6})
[ 4, 6 ]
class bar
  constructor: ({@x,@y}={y:3,x:''})->
new bar()
{ x: '', y: 3 }

https://github.com/joyent/node/blob/master/test/simple/test-fs-read-stream-fd.js
create readstream from an fd
output = ''
fd = fs.openSync(file, 'r');
stream = fs.createReadStream(null, { fd: fd, encoding: 'utf8' });
stream.on('data', function(data) {
  output += data;
});

###
