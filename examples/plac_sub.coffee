# from test_plac.py
# example with class and commands
# not working yet

plac = require('../lib/plac')
parser_from = (f, kw) ->
    f.__annotations__ = kw
    return plac.parser_from(f, {debug:true})
    
cmds = {
    add_help: false
    commands: ['help', 'commit']
    help: (name) ->
        return ['help:', name]
    commit: () ->
        return 'commit'
    }

parser = parser_from(cmds, {'name': ['commit name help','positional']})

console.log(parser.format_help());

console.log parser.subparsers._name_parser_map['help'].format_help()

console.log 'help foo:', parser.consume(['help','foo'])
console.log plac.call(cmds, ['help','foo'])

console.log 'commit:', parser.consume(['commit'])
###
def test_cmds():
    assert 'commit' == plac.call(cmds, ['commit'])
    assert ['help', 'foo'] == plac.call(cmds, ['help', 'foo'])
    expect(SystemExit, plac.call, cmds, [])

def test_cmd_abbrevs():
    assert 'commit' == plac.call(cmds, ['comm'])
    assert ['help', 'foo'] == plac.call(cmds, ['h', 'foo'])
    expect(SystemExit, plac.call, cmds, ['foo'])

def test_sub_help():
    c = Cmds()
    c.add_help = True    
    expect(SystemExit, plac.call, c, ['commit', '-h'])
###
