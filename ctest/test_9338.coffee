
argparse = require('argcoffee')
NS = argparse.Namespace
_ = require('underscore')
split = require('underscore.string').words
print = console.log

run = (argv, ns=null) =>
    if _.isString(argv)
        print(argv)
        argv = split(argv)
    try
        args = parser.parse_args(argv)
        print(args)
        if ns
            assert.deepEqual(args,ns)
    catch e
        print(e.message)

aa=[]
parser = argparse.newParser()
aa[0]=parser.add_argument('-w')
aa[1]=parser.add_argument('-x', {nargs:'+'})
aa[2]=parser.add_argument('y',{type:'int'})
aa[3]=parser.add_argument('z', {nargs:'*',type:'int'})

trials = [
          Array('-w 1 -x 2 3 4 5', NS({w:'1', x:['2', '3', '4'], y:5, z:[]})),
            # prototypical case for this issue
          Array('-w 1 -x2 3 4 5', NS({w:'1', x:['2'], y:3, z:[4, 5]})), # not an issue case
          Array('-w 1 2 -x 3 4 5', NS({w:'1', x:['3', '4', '5'], y:2, z:[]})), # not an issue
          Array('-w 1 -x 2 3', NS({w:'1', x:['2'], y:3, z:[]})), # issue
          Array('-w 1 -x2 3', NS({w:'1', x:['2'], y:3, z:[]})), # not
          Array('-w 1 -x 2 3 -w 4', NS({w:'4', x:['2'], y:3, z:[]})), # issue
          Array('-x 1 2 -w 3 4 5 6',NS({w:'3', x:['1', '2'], y:4, z:[5, 6]})), # not
            # if pattern isnt general enough, x:[1],y:2, z:[], [5,6] extras
            # enough after -w that -x gets all 2, but cannot tell that by looking
            # just at '-x 1 2' part
          Array('-x 1 2 -w 3', NS({w:'3', x:['1'], y:2, z:[]})), # issue
          Array('-x 1 2 3 4 -w 5 6 7', NS({w:'5', x:['1', '2', '3', '4'], y:6, z:[7]})), # not
          # alt? w:5, x:[1,2,3], y:4, z:[6,7] -
          Array('1 2 3 -x 4 5 -w 6', NS({w:'6', x:['4', '5'], y:1, z:[2, 3]})), # not
          Array('1 2 3',NS({w:null, x:null, y:1, z:[2, 3]})),
          Array('1 -x 2 3 -w 4 5 6',NS({w:'4', x:['2', '3'], y:1, z:[5, 6]})), # not
           # error: unrecognized arguments: 5 6
           # z consumed in 1st positionals group
           # not an error here because of a 'mixed' patch
          Array('-x 1 2 3 4 -w 5',NS({w:'5', x:['1', '2', '3'], y:4, z:[]})),
        ]

# '-x 1 2 -w 3 4' - how it matches depends on which order of x and w are allowed
# [-xA A -wA A]  versus [-xAA -wA A]

for astr in trials
    if _.isArray(astr)
        ns = astr[1]
        astr = astr[0]
    else
        ns = null
    argv = split(astr)
    print(astr)
    run(argv,ns)
    print('')

parser = argparse.newParser()
parser.add_argument('-x', {nargs:'?'})
parser.add_argument('y',{type:'int'})
run('-x 1', NS({x:null, y:1}))
run('-x 1 2', NS({x:'1', y:2}))

print('')
parser = argparse.newParser()
parser.add_argument('-x', {nargs:'*'})
parser.add_argument('y',{type:'int'})
run('-x 1', NS({x:[], y:1}))
run('-x 1 2', NS({x:['1'], y:2}))
run('-x 1 2 3',NS({x:['1', '2'], y:3}))

print('')
parser = argparse.newParser()
parser.add_argument('-x', {nargs:'*'})
parser.add_argument('y',{type:'int',nargs:2})
run('-x 1') # error
run('-x 1 2', NS({x:[], y:[1,2]}))
run('-x 1 2 3',NS({x:['1'], y:[2,3]}))

print('')
parser = argparse.newParser()
parser.add_argument('-x', {nargs:'+'})
parser.add_argument('y',{type:'int',nargs:2})
parser.add_argument('z',{type:'int',nargs:'+'})
run('-x 1') # error
run('-x 1 2') # error
run('-x 1 2 3') # error
run('-x 1 2 3 4', NS({x:['1'], y:[2,3], z:[4]}))
run('-x 1 2 3 4 5', NS({x:['1','2'], y:[3,4], z:[5]}))

print('')
parser = argparse.newParser()
parser.add_argument('-w', {nargs:'+'})
parser.add_argument('-x', {nargs:'+'})
parser.add_argument('y',{type:'int',nargs:2})
parser.add_argument('z',{type:'int',nargs:'+'})
run('-x 1') # error
run('-x 1 2') # error
run('-x 1 2 3') # error
run('-x 1 2 3 4',NS({w:null, x:['1'], y:[2, 3], z:[4]}))
run('-x 1 2 3 4 5',NS({w:null, x:['1', '2'], y:[3, 4], z:[5]}))
run('-w 1 -x 2 3 4') # error (not enough)
run('-w 1 -x 2 3 4 5', NS({w:['1'], x:['2'], y:[3, 4], z:[5]}))
run('-w 1 2 -x 3 4 5 6',NS({w:['1', '2'], x:['3'], y:[4, 5], z:[6]}))
run('-w 1 2 3 -x 4 5 6', NS({w:['1'], x:['4', '5'], y:[2, 3], z:[6]}))

print('')
parser = argparse.newParser()
parser.add_argument('-a', {nargs:'?'})
parser.add_argument('-b', {nargs:'+'})
parser.add_argument('-c', {nargs:'*'})
parser.add_argument('-j', {action:'storeTrue'})
parser.add_argument('-l')
parser.add_argument('-m', {nargs:1})
parser.add_argument('x',{type:'int'})
parser.add_argument('y',{type:'int',nargs:2})
parser.add_argument('z',{type:'int',nargs:'+'})
run('1 2 3 4 5', NS({a:null, b:null, c:null, j:false, l:null, m:null, x:1, y:[2, 3], z:[4, 5]}))
run('-a 1 2 3 4 5')
run('-a 1 -b 2 3 4 5 6')
run('-a 1 -b 2 3 -c 4 5 6 7 8', NS({a:'1', b:['2', '3'], c:['4'], j:false, l:null, m:null, x:5, y:[6, 7], z:[8]}))
run('-a 1 -b 2 3 -j -c 4 5 6 7 8', NS({a:'1', b:['2', '3'], c:['4'], j:true, l:null, m:null, x:5, y:[6, 7], z:[8]}))
run('-a 1 -l L -b 2 3 -c 4 5 6 7 8', NS({a:'1', b:['2', '3'], c:['4'], j:false, l:'L', m:null, x:5, y:[6, 7], z:[8]}))
run('-a 1 -l L -b 2 3 -m M -c 4 5 6 7 8',NS({a:'1', b:['2', '3'], c:['4'], j:false, l:'L', m:['M'], x:5, y:[6, 7], z:[8]}))
# NS({a:'1', b:['2'], c:['4', '5'], j:false, l:'L', m:['M'], x:3, y:[6, 7], z:[8])
# the global regex changes x:5 to 3; backward iterative does not
run('-a 1 -l L -c 2 3 -m M -b 4 5 6 7 8',NS({a:'1', b:['4'], c:['2', '3'], j:false, l:'L', m:['M'], x:5, y:[6, 7], z:[8]}))
run('-l L -a 1 -j -b 2 3 -c 4 5 6 7 8', NS({a:'1', b:['2', '3'], c:['4'], j:true, l:'L', m:null, x:5, y:[6, 7], z:[8]}))

run('-lL -a1 -j -b 2 3 -c4 5 6 7 8', NS({a:'1', b:['2', '3'], c:['4'], j:true, l:'L', m:null, x:5, y:[6, 7], z:[8]}))

run('-lL -a 1 -jb2 3 -c4 5 6 7', NS({a:'1', b:['2'], c:['4'], j:true, l:'L', m:null, x:3, y:[5, 6], z:[7]}))
run('-lL -a 1 -jb 2 3 4 -c 5 6', NS({a:null, b:['2'], c:['5'], j:true, l:'L', m:null, x:1, y:[3, 4], z:[6]}))



parser = argparse.newParser()
parser.add_argument('req_pos')
parser.add_argument('-req_opt', {type:'int', required:true})
parser.add_argument('need_one', {nargs:'+'})
run('')
# efrror: the following arguments are required: req_pos, -req_opt, need_one

parser = argparse.newParser()
parser.add_argument('-x', {nargs:'{2,4}'})
parser.add_argument('y', {type:'int'})
console.log parser.format_usage()
run('-x 1') # error
run('-x 1 2') # error
run('-x 1 2 3', NS({x:['1','2'], y:3}))
run('-x 1 2 3 4', NS({x:['1','2','3'], y:4}))
run('-x 1 2 3 -- 4', NS({x:['1','2','3'], y:4}))
run('4 -x 1 2 3', NS({x:['1','2','3'], y:4}))

parser = argparse.newParser()
parser.add_argument('-x', {nargs:[1,3]})
parser.add_argument('y', {type:'int', nargs:'{2,}'})
console.log parser.format_usage()
run('-x 1') # error
run('-x 1 2') # error
run('-x 1 2 3', NS({x:['1'], y:[2,3]}))
run('-x 1 2 3 4 5 6', NS({x:['1','2','3'], y:[4,5,6]}))



