# test the argparse FileType
# roughly the same as OS cat command
fs = require('fs')
print = console.error
ap = require('argcoffee')
# ap.FileType = ap.fileType # test the fn version
# print ap.FileType('r').toString()
meStream = ap.FileType()(process.argv[1])

# ap.FileType('a')(['-'])
# TypeError: argument '-' with flag a

helpstr = 'Functionality is roughly that of <cat>'
parser = ap.newParser({epilog: helpstr})
parser = new ap.ArgumentParser()
# parser.add_argument('-a', {type:ap.FileType('a')})
parser.add_argument('-i', '--infile', {type:ap.FileType({flags: 'r', encoding:'utf8'}), \
   defaultValue: meStream, \
   help: 'Input filename or `-` (default is itself)'})
a = parser.add_argument('-o', '--outfile', {type:ap.FileType({flags: 'w'}), \
   help: 'Output filename or `-`'})

# parser.parse_args(['-a','-'])

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

pipe = (readStream, writeStream) ->
  writeStream.on('open', () ->
    print "wrote to #{writeStream.path}"
    )
  writeStream.on 'error', (error) -> print error
  readStream.on('end', () ->
    print 'pipe end'
    )
  readStream.resume()
  readStream.pipe(writeStream, {end: false})

printall = (readStream) ->
  readStream.on('open', -> print readStream.path)
  # readStream.on('data', (data)->print data.toString('utf8'))
  readStream.on('data', (data)->print data)
  readStream.on('end', ()->print '\nStream END')

bylines = (stream) ->
  pad = (cnt,n) ->
    str = "#{cnt}"
    x = (' ' for i in [0..(n-str.length)]).join('')
    return x+str
  #pad = (cnt,n) -> return "#{cnt}"
  cnt = 0
  last = ""
  stream.on('data', (chunk) ->
    lines = (last + chunk).split("\n")
    [lines...,last] = lines
    for line in lines
      cnt += 1
      print "(#{pad(cnt,4)}): " + line
  #cnt = pad((cnt+1),5)
  )
  stream.on('end', () ->
    print "(#{pad('end',4)}): " + last
  )
  stream.resume()

getlines = (stream, cb) ->
  results = []
  last = ""
  stream.on('data', (chunk) ->
    lines = (last + chunk).split("\n")
    [lines...,last] = lines
    results.push(lines...)
    print lines.length
  )
  stream.on('end', () ->
    results.push(last)
    print results.length
    cb(results)
  )

if writeStream?
  pipe(readStream, writeStream)

else
  printall(readStream)
  #bylines(readStream)
  #getlines(readStream, (r)->print (r[i] for i in [r.length-1..0]))

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
