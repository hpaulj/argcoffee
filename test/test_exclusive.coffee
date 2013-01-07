
#ArgumentParser = require('argcoffee').ArgumentParser
ArgumentParser = require('../lib/argparse').ArgumentParser
parser = new ArgumentParser({prog: "PROG", debug: true})
group = parser.addMutuallyExclusiveGroup({required: true})
group.addArgument(['--bar'], {help: 'bar help'})
group.addArgument(['--baz'], {nargs: '?', constant:'Z', help: 'baz help'})
console.log "'--bar X' ->", parser.parseArgs(['--bar', 'X'])

usage_when_not_required = "usage: PROG [-h] [--bar BAR | --baz [BAZ]]"
usage_when_required = "usage: PROG [-h] (--bar BAR | --baz [BAZ])"
pyhelp = """optional arguments:
          -h, --help   show this help message and exit
          --bar BAR    bar help
          --baz [BAZ]  baz help
        """
console.log 'exp:',usage_when_required
console.log 'got:',parser.formatUsage()


group.required = false
console.log 'exp:',usage_when_not_required
console.log 'got:',parser.formatUsage()


console.log parser.formatHelp()

console.log 'pyhelp:'
console.log pyhelp
#console.log parser
###
class TestMutuallyExclusiveSimple(MEMixin, TestCase):

    def get_parser(self, required=None):
        parser = ErrorRaisingArgumentParser(prog='PROG')
        group = parser.add_mutually_exclusive_group(required=required)
        group.add_argument('--bar', help='bar help')
        group.add_argument('--baz', nargs='?', const='Z', help='baz help')
        return parser

    failures = ['--bar X --baz Y', '--bar X --baz']
    successes = [
        ('--bar X', NS(bar='X', baz=None)),
        ('--bar X --bar Z', NS(bar='Z', baz=None)),
        ('--baz Y', NS(bar=None, baz='Y')),
        ('--baz', NS(bar=None, baz='Z')),
    ]
    successes_when_not_required = [
        ('', NS(bar=None, baz=None)),
    ]

    usage_when_not_required = '''\
        usage: PROG [-h] [--bar BAR | --baz [BAZ]]
        '''
    usage_when_required = '''\
        usage: PROG [-h] (--bar BAR | --baz [BAZ])
        '''
    help = '''\

        optional arguments:
          -h, --help   show this help message and exit
          --bar BAR    bar help
          --baz [BAZ]  baz help
        '''
###
