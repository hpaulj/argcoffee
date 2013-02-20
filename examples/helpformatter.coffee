
argparse = require('argcoffee')

console.log "====> argparse.ArgumentDefaultsHelpFormatter"

parser = new argparse.ArgumentParser({debug: true,\
           formatterClass: argparse.ArgumentDefaultsHelpFormatter,\
           description: 'description'})

a=parser.addArgument(['--foo'], {help:'foo help - oh and by the way, %(defaultValue)s'})

parser.addArgument(['--bar'], {action:'store_true', help:'bar help'})
parser.addArgument(['spam'], {help:'spam help'})
parser.addArgument(['badger'], {nargs:'?', defaultValue:'wooden', help:'badger help'})

group = parser.addArgumentGroup({title: 'title', description: 'description'})
group.addArgument(['--baz'], {type:'int', defaultValue: 42, help:'baz help'})
console.log parser.formatHelp()

# missing indent on group description
###

usage: PROG [-h] [--foo FOO] [--bar] [--baz BAZ] spam [badger]

description

positional arguments:
  spam        spam help
  badger      badger help (default: wooden)

optional arguments:
  -h, --help  show this help message and exit
  --foo FOO   foo help - oh and by the way, None
  --bar       bar help (default: False)

title:
  description

  --baz BAZ   baz help (default: 42)

###
console.log "====> argparse.RawDescriptionHelpFormatter"
parser = new argparse.ArgumentParser({debug: true, \
  prog: 'PROG', \
  formatterClass: argparse.RawDescriptionHelpFormatter, \
  description: 'Keep the formatting\n' +
               '    exactly as it is written\n' +
               '\n' +
               'here\n'})
# console.log parser.description

a = parser.addArgument(['--foo'],{help: '  foo help should not\n'+
                          '    retain this odd formatting'})
# console.log a.help
parser.addArgument(['spam'],{'help': 'spam help'})
group = parser.addArgumentGroup({title: 'title', \
  description: '    This text\n' +
               '  should be indented\n' +
               '    exactly like it is here\n'})
group.addArgument(['--bar'], {help:'bar help'})
console.log parser.formatHelp()

###
class TestHelpRawDescription(HelpTestCase):
    """Test the RawTextHelpFormatter"""
....

usage: PROG [-h] [--foo FOO] [--bar BAR] spam

Keep the formatting
    exactly as it is written

here

positional arguments:
  spam        spam help

optional arguments:
  -h, --help  show this help message and exit
  --foo FOO   foo help should not retain this odd formatting

title:
      This text
    should be indented
      exactly like it is here

  --bar BAR   bar help
# got extra space after group description
###
console.log "===> argparse.RawTextHelpFormatter"
parser = new argparse.ArgumentParser({debug: true, \
  prog: 'PROG', \
  formatterClass: argparse.RawTextHelpFormatter, \
  description: 'Keep the formatting\n' +
               '    exactly as it is written\n' +
               '\n' +
               'here\n'})
parser.addArgument(['--baz'], \
  {help:'    baz help should also\n' +
        'appear as given here'})

console.log parser.formatHelp()

###
class TestHelpRawText(HelpTestCase):
    """Test the RawTextHelpFormatter"""

usage: PROG [-h] [--foo FOO] [--bar BAR] spam

Keep the formatting
    exactly as it is written

here

positional arguments:
  spam        spam help

optional arguments:
  -h, --help  show this help message and exit
  --foo FOO       foo help should also
              appear as given here

title:
      This text
    should be indented
      exactly like it is here

  --bar BAR   bar help

###

console.log "===> metavar as a tuple"
###
not working
class TestHelpTupleMetavar(HelpTestCase):
    """Test specifying metavar as a tuple"""

    parser_signature = Sig(prog='PROG')
    argument_signatures = [
        Sig('-w', help='w', nargs='+', metavar=('W1', 'W2')),
        Sig('-x', help='x', nargs='*', metavar=('X1', 'X2')),
        Sig('-y', help='y', nargs=3, metavar=('Y1', 'Y2', 'Y3')),
        Sig('-z', help='z', nargs='?', metavar=('Z1', )),
    ]
    argument_group_signatures = []
    usage = '''\
        usage: PROG [-h] [-w W1 [W2 ...]] [-x [X1 [X2 ...]]] [-y Y1 Y2 Y3] \
[-z [Z1]]
        '''
    help = usage + '''\

        optional arguments:
          -h, --help        show this help message and exit
          -w W1 [W2 ...]    w
          -x [X1 [X2 ...]]  x
          -y Y1 Y2 Y3       y
          -z [Z1]           z
        '''
    version = ''
###
