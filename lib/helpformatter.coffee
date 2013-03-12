if not module.parent?
    DEBUG = (arg...) ->
      arg.unshift('==> ')
      console.log arg...
else
    DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')

# other argparse
adir = './'
#adir = '../node_modules/argparse/lib/'
$$ = require('./const')

fmtwindent= (fmt, tup) ->
  # @_current_indent, '', action_width, action_header
  # '%*s'%(5,'x') => '    x'; len('%*s'%(5,'')) is 5
  # len('%-*s'%(5,'x')) 'x    '
  [indent, text, width, spc] = tup
  spc = spc ? ' '
  text = text ? ''
  #indentstr = (spc for i in [0...indent]).join('')
  indentstr = new Array(indent+1).join(spc)
  text = indentstr + text
  if width?
    text = _.str.pad(text, width+indent, ' ', 'right')
  # append everything after the last %..s
  trailing = _.str.strRightBack(fmt,'s') # e.g '%*s%-*s:\n'-> ':\n'
  if trailing != fmt
    text = text + trailing
  else if _.str.endsWith(fmt, '\n')
    text = text + '\n'
  return text

_textwrap =
  wrap: (text, width, initial_indent=0, subsequent_indent=0) ->
    return [text]
  fill: (args...) ->
    return _textwrap.wrap(args...).join('\n')

pformat = (fmt, params) ->
  # standin for python format
  # params is a list
  for p in params
    fmt=fmt.replace(/%s/,p)
  return fmt

pnformat = (fmt, params) ->
  # standin for python format with named entries
  # params is an object,
  # if {k:v} in params, then fmt='%(k)s' becomes 'v'
  for k of params
    fmt = fmt.replace("%(#{k})s",params[k])
  return fmt


# ===============
# Formatting Help
# ===============

exports.HelpFormatter = class HelpFormatter
    ###Formatter for generating usage messages and argument help strings.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    constructor: (options={}) ->
      prog = options.prog
      indent_increment = options.indent_increment ? options.indentIncrement ? 2
      max_help_position = options.max_help_position ? options.maxHelpPosition ? 24
      width = options.width ? null

      # default setting for width
      if not width?
        # environ['COLUMNS'] or 80 -2
        width = 80 - 2

      @_prog = prog
      @_indent_increment = indent_increment
      @_max_help_position = max_help_position
      @_width = width

      @_current_indent = 0
      @_level = 0
      @_action_max_length = 0

      @_root_section = new @_Section(@, null)
      @_current_section = @_root_section

      @_whitespace_matcher = /\s+/g # _re.compile(r'\s+')
      @_long_break_matcher = /\n\n\n+/g # _re.compile(r'\n\n\n+')
      @_prog_matcher = /%\(prog\)s/

    # ===============================
    # Section and indentation methods
    # ===============================
    _indent: () ->
        @_current_indent += @_indent_increment
        @_level += 1

    _dedent: () ->
        @_current_indent -= @_indent_increment
        assert @_current_indent >= 0, 'Indent decreased below 0.'
        @_level -= 1

    _Section: class _Section

        constructor: (formatter, parent, heading=null) ->
            @formatter = formatter
            @parent = parent
            @heading = heading
            @items = []

        format_help: () =>
            # format the indented section
            if @parent?
                @formatter._indent()
            join = @formatter._join_parts
            # why the dbl call to func?
            #for [func, args] in @items
            #    func(args...)
            item_help = join(func(args...) for [func, args] in @items)

            if @parent?
                @formatter._dedent()

            # return nothing if the section was empty
            if item_help.length==0
                return ''

            # add the heading if the section was non-empty
            if @heading != $$.SUPPRESS and @heading != null
                current_indent = @formatter._current_indent
                # heading = '%*s%s:\n' % (current_indent, '', @heading)
                heading = fmtwindent('%*s%s:\n', [current_indent, @heading])
            else
                heading = ''

            # join the section-initial newline, the heading and the help
            return join(['\n', heading, item_help, '\n'])

    _add_item: (func, args) ->
        @_current_section.items.push([func, args])

    # ========================
    # Message building methods
    # ========================
    start_section: (heading) ->
        @_indent()
        section = new @_Section(@, @_current_section, heading)
        @_add_item(section.format_help, [])
        @_current_section = section
    startSection: (heading) -> @start_section(heading)

    end_section: () ->
        @_current_section = @_current_section.parent
        @_dedent()
    endSection: () -> @end_section()

    add_text: (text) ->
        if text != $$.SUPPRESS and text?
            @_add_item(@_format_text, [text])
    addText: (text) -> @add_text(text)

    add_usage: (usage, actions, groups, prefix=null) ->
        if usage != $$.SUPPRESS
            args = [usage, actions, groups, prefix]
            @_add_item(@_format_usage, args)
    addUsage: (args...) -> @add_usage(args...)

    add_argument: (action) ->
        if action.help != $$.SUPPRESS
            # appears main action is to adjust @_action_max_length
            # find all invocations
            invocations = [@_format_action_invocation(action)]
            # in py this was in an generator with an indent
            if action._get_subactions?
              for subaction in action._get_subactions()
                @_indent()
                invocations.push(@_format_action_invocation(subaction))
                @_dedent()
            # update the maximum item length
            invocation_length = Math.max((s.length for s in invocations)...)
            action_length = invocation_length + @_current_indent
            @_action_max_length = Math.max(@_action_max_length, action_length)
            # add the item to the list
            @_add_item(@_format_action, [action])
    addArgument: (action) -> @add_argument(action)

    add_arguments: (actions) ->
        for action in actions
            @add_argument(action)
    addArguments: (actions) -> @add_arguments(actions)

    # =======================
    # Help-formatting methods
    # =======================
    format_help: () ->
        help = @_root_section.format_help()
        if help? and help.length>0
            help = help.replace(@_long_break_matcher, '\n\n')
            help = _.str.strip(help,'\n') + '\n'
        return help
    formatHelp: () -> @format_help()

    _join_parts: (part_strings) ->
        return (part for part in part_strings when part and part != $$.SUPPRESS).join('')

    _format_usage: (usage, actions, groups, prefix) =>
        if prefix is null
            prefix = 'usage: '

        # if usage is specified, use that
        if usage?
            #  usage = usage % dict(prog=@_prog)
            usage = usage.replace(@_prog_matcher, @_prog)

        # if no optionals or positionals are available, usage is just prog
        else if not usage? and actions.length==0
            # usage = '%(prog)s' % dict(prog=@_prog)
            usage = @_prog

        # if optionals and positionals are available, calculate usage
        else if not usage?
            #prog = '%(prog)s' % dict(prog=@_prog)
            prog = @_prog
            # split optionals from positionals
            optionals = []
            positionals = []
            for action in actions
                if action.isOptional()
                    optionals.push(action)
                else
                    positionals.push(action)

            # build full usage string
            format = @_format_actions_usage
            action_usage = format([].concat(optionals, positionals), groups)
            usage = (s for s in [prog, action_usage] when s).join(' ')

            # wrap the usage parts if it's too long
            text_width = @_width - @_current_indent
            if prefix.length + usage.length > text_width

                # break usage into wrappable parts
                part_regexp = /\(.*?\)+|\[.*?\]+|\S+/g
                opt_usage = format(optionals, groups)
                pos_usage = format(positionals, groups)

                opt_parts = opt_usage.match(part_regexp) ? []
                pos_parts = pos_usage.match(part_regexp) ? []
                # helper for wrapping lines
                get_lines = (parts, indent, prefix=null) ->
                    lines = []
                    line = []
                    if prefix?
                        line_len = prefix.length - 1
                    else
                        line_len = indent.length - 1
                    for part in parts
                        if line_len + 1 + part.length > text_width
                            lines.push(indent + line.join(' '))
                            line = []
                            line_len = indent.length - 1
                        line.push(part)
                        line_len += part.length + 1
                    if line.length>0
                        lines.push(indent + line.join(' '))
                    if prefix?
                        lines[0] = lines[0][indent.length...]
                    return lines

                # if prog is short, follow it with optionals or positionals
                if prefix.length + prog.length <= 0.75 * text_width
                    indent = fmtwindent('',[prefix.length + prog.length + 1])
                    if opt_parts.length>0
                        lines = [prog].concat(opt_parts)
                        lines = get_lines(lines, indent, prefix)
                        lines = lines.concat(get_lines(pos_parts, indent))
                        #lines = [lines.join(' ')]
                        #lines = [lines, indent + pos_parts.join(' ')]
                    else if pos_parts.length>0
                        lines = [prog].concat(pos_parts)
                        lines = get_lines(lines, indent, prefix)
                    else
                        lines = [prog]

                # if prog is long, put it on its own line
                else
                    indent = fmtwindent('',[prefix.length])
                    opt_parts.concat(pos_parts)
                    parts = opt_parts
                    lines = get_lines(parts, indent)
                    if lines.length > 1
                        lines = []
                        lines.concat(get_lines(opt_parts, indent))
                        lines.concat(get_lines(pos_parts, indent))
                    # lines = [prog] + lines
                    lines.unshift(prog)

                # join lines into usage
                usage = lines.join('\n')

        # prefix with 'usage:'
        return prefix + usage + "\n\n"

    _format_actions_usage: (actions, groups) =>
        # find group indices and identify actions in groups
        group_actions = []
        # set() in python; could use {}, but using action as key is awkward
        inserts = {}
        for group in groups
            #try
            start = actions.indexOf(group._group_actions[0])
            #catch ValueError
            #    continue
            #else
            # looks like it expects group actions to be defined in sequence
            end = start + group._group_actions.length
            if _.isEqual(actions[start...end], group._group_actions)
                for action in group._group_actions
                    group_actions.push(action)
                if not group.required
                    if start of inserts
                        inserts[start] += ' ['
                    else
                        inserts[start] = '['
                    inserts[end] = ']'
                else
                    if start of inserts
                        inserts[start] += ' ('
                    else
                        inserts[start] = '('
                    inserts[end] = ')'
                for i in [start + 1...end]
                    inserts[i] = '|'
        # collect all actions format strings
        parts = []
        # i = -1
        for action, i in actions
            # i++
            # suppressed arguments are marked with null
            # remove | separators for suppressed arguments
            if action.help is $$.SUPPRESS
                parts.push(null)
                if inserts[i] == '|'
                    delete inserts[i]
                else if inserts[i + 1] == '|'
                    delete inserts[i + 1]

            # produce all arg strings
            else if action.isPositional()
                part = @_format_args(action, action.dest)

                # if it's in a group, strip the outer []
                if action in group_actions
                    if part[0] == '[' and _.last(part) == ']'
                        # part = _.initial(_.rest(part)).join('') # part[1...-1]
                        # part.match(/\[(.*)\]/)[1]
                        part = part.slice(1, part.length-1)

                # add the action string to the list
                parts.push(part)

            # produce the first way to invoke the option in brackets
            else
                option_string = action.option_strings[0]

                # if the Optional doesn't take a value, format is
                #    -s or --long
                if action.nargs == 0
                    part = option_string # '%s' % option_string

                # if the Optional takes a value, format is
                #    -s ARGS or --long ARGS
                else
                    defaultValue = action.dest.toUpperCase()
                    args_string = @_format_args(action, defaultValue)
                    part = "#{option_string} #{args_string}"

                # make it look optional if it's not required or in a group
                if not action.required and action not in group_actions
                    part = "[#{part}]"

                # add the action string to the list
                parts.push(part)
        # insert things at the necessary indices
        #for i in sorted(inserts, reverse=true)
        #    parts[i...i] = [inserts[i]]
        pairs = _.pairs(inserts)
        if pairs.length>0
          for i in [pairs.length-1..0]
            [k,v] = pairs[i]
            if v?
              parts.splice(k,0,v)
        # join all the action items with spaces
        text = (item for item in parts when item?).join(' ')

        # clean up separators for mutually exclusive groups
        # coffeescript is having problems parsing / ([\])])/g
        text = text.replace(/([\[(]) /g,'$1'); # remove spaces
        text = text.replace(/\ ([\])])/g,'$1');
        text = text.replace(/\[ *\]/g, ''); # remove empty groups
        text = text.replace(/\( *\)/g, '');
        text = text.replace(/\(([^|]*)\)/g, '$1'); # remove () from single action groups
        text = _.str.strip(text);
        # return the text
        return text

    _format_text: (text) =>
        text = text.replace(@_prog_matcher, @_prog)
        text_width = @_width - @_current_indent
        indent = fmtwindent('',[@_current_indent])
        return @_fill_text(text, text_width, indent) + '\n\n'

    _format_action: (action) =>
        # determine the required width and the entry label
        help_position = Math.min(@_action_max_length + 2,
                            @_max_help_position)
        help_width = @_width - help_position
        action_width = help_position - @_current_indent - 2
        action_header = @_format_action_invocation(action)
        # no help; start on same line and add a final newline
        if not action.help?
            action_header = fmtwindent('%*s%s\n',[@_current_indent, action_header])

        # short action name; start on the same line and pad two spaces
        else if action_header.length <= action_width
            tup = [@_current_indent, action_header, action_width]
            action_header = fmtwindent('%*s%-*s  ',tup)
            indent_first = 0

        # long action name; start on the next line
        else
            action_header = fmtwindent('%*s%s\n', [@_current_indent, action_header])
            indent_first = help_position

        # collect the pieces of the action help
        parts = [action_header]

        # if there was help for the action, add lines of help text
        if action.help?
            help_text = @_expand_help(action)
            help_lines = @_split_lines(help_text, help_width)
            # help_lines = if _.isString(help_lines) then [help_lines] else help_lines
            # parts.push('%*s%s\n' % (indent_first, '', help_lines[0]))
            parts.push(fmtwindent('%*s%s\n',[indent_first, help_lines[0]]))
            for line in help_lines[1...]
                #parts.push('%*s%s\n' % (help_position, '', line))
                parts.push(fmtwindent('%*s%s\n', [help_position, line]))
        # or add a newline if the description doesn't end with one
        else if not _.str.endsWith(action_header, '\n')
            parts.push('\n')
        # if there are any sub-actions, add their help as well
        if action._get_subactions?
          for subaction in action._get_subactions()
            @_indent()
            parts.push(@_format_action(subaction))
            @_dedent()



        # return a single string
        return @_join_parts(parts)

    _format_action_invocation: (action) =>
        if action.isPositional()
            metavar = @_metavar_formatter(action, action.dest)(1)[0]
            return metavar
        else
            parts = []

            # if the Optional doesn't take a value, format is
            #    -s, --long
            if action.nargs == 0
                parts = parts.concat(action.option_strings)
            # if the Optional takes a value, format is
            #    -s ARGS, --long ARGS
            else
                defaultValue = action.dest.toUpperCase()
                args_string = @_format_args(action, defaultValue)
                for option_string in action.option_strings
                    parts.push("#{option_string} #{args_string}")

            return parts.join(', ')

    _metavar_formatter: (action, default_metavar) ->
        if action.metavar?
            result = action.metavar
        else if action.choices?
          # copy from ArgumentParser._check_value
          if _.isString(action.choices)
            choices = action.choices
            choices = choices.split(/\W+/) # 'white space' separators
            if choices.length==1
              choices = choices[0].split('') # individual letters
          else if _.isArray(action.choices)
            choices = action.choices
          else if _.isObject(action.choices)
            choices = _.keys(action.choices)
          else
            throw new Error('bad choices variable')
          result = "{#{choices.join(',')}}"
        else
            result = default_metavar

        #format = (tuple_size) ->
        #    return (result for i in [0...tuple_size])

        format = (tuple_size) ->
          if _.isArray(result)
            return result
          else
            # return (result for i in [0...tuple_size])
            return _.times(tuple_size, ()->result)
        return format

    _format_args: (action, default_metavar) ->
        get_metavar = @_metavar_formatter(action, default_metavar)
        if !action.nargs?
            result = pformat('%s', get_metavar(1))
        else if action.nargs == $$.OPTIONAL
            result = pformat('[%s]', get_metavar(1))
        else if action.nargs == $$.ZERO_OR_MORE
            result = pformat('[%s [%s ...]]',get_metavar(2))
        else if action.nargs == $$.ONE_OR_MORE
            result = pformat('%s [%s ...]',get_metavar(2))
        else if action.nargs == $$.REMAINDER
            result = '...'
        else if action.nargs == $$.PARSER
            result = pformat('%s ...', get_metavar(1))
        else
            # formats = ('%s' for i in [0...action.nargs]).join(' ')
            formats = Array(action.nargs+1).join('%s')
            result = pformat(formats ,get_metavar(action.nargs))
        return result

    _expand_help: (action) ->
        # return @_get_help_string(action)
        # params = dict(vars(action), prog=@_prog)
        params = _.clone(action); params.prog = @_prog
        # for name in _.keys(params)
        for name of params when params[name] == $$.SUPPRESS
            delete params[name]
        for name of params when params[name]?.__name__?
            # python specific; e.g. fns have a __name__
            params[name] = params[name].__name__
        if params.choices?
            choices_str = (''+c for c in params.choices).join(', ')
            params.choices = choices_str
        return pnformat(@_get_help_string(action), params)

    _indented_subactions: (action) ->
        # was iter in py
        # replace with inline code to get the indent right

    _split_lines: (text, width=80, indent=0) ->
        text = text.replace(@_whitespace_matcher, ' ')
        text = _.str.strip(text)
        wds = text.split(' ')
        lines = []
        line = []
        cnt = 0
        for wd in wds
          if (cnt+wd.length+1) < (width-indent)
            line.push(wd)
            cnt += wd.length+1
          else
            lines.push(line.join(' '))
            line = [wd]
            cnt = wd.length+1
        lines.push(line.join(' '))
        return lines
        # return text.split('\n')
        # py: split text in lines roughly width long
        # text = @_whitespace_matcher.sub(' ', text).strip()
        # return _textwrap.wrap(text, width)

    _fill_text: (text, width, indent=0) ->
        text = @_split_lines(text,width, indent)
        text = (indent+line for line in text)
        text = text.join('\n')
        return text
        # py returns text reformed into indented lines
        # text = @_whitespace_matcher.sub(' ', text).strip()
        # return _textwrap.fill(text, width, indent, indent)

    _get_help_string: (action) ->
        return action.help


class RawDescriptionHelpFormatter extends HelpFormatter
    ###Help message formatter which retains any formatting in descriptions.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _fill_text: (text, width, indent) ->
        lines = text.split('\n')
        lines = (indent + line for line in lines)
        lines = (_.str.rtrim(line) for line in lines)
        return lines.join('\n')
        # use rtrim to prevent sequence like '\n  \n\n'

class RawTextHelpFormatter extends RawDescriptionHelpFormatter
    ###Help message formatter which retains formatting of all help text.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _split_lines: (text, width) ->
        return text.split('\n')  # text.splitlines()



class ArgumentDefaultsHelpFormatter extends HelpFormatter
    ###Help message formatter which adds default values to argument help.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _get_help_string: (action) ->
        help = action.help
        if action.help.indexOf('%(defaultValue)s')==-1
            if action.defaultValue != $$.SUPPRESS
                defaulting_nargs = [$$.OPTIONAL, $$.ZERO_OR_MORE]
                if action.isOptional() or action.nargs in defaulting_nargs
                    help += ' (default: %(defaultValue)s)'
        return help

exports.RawDescriptionHelpFormatter = RawDescriptionHelpFormatter
exports.RawTextHelpFormatter = RawTextHelpFormatter
exports.ArgumentDefaultsHelpFormatter = ArgumentDefaultsHelpFormatter



setup = (parser) ->
  formatter = new HelpFormatter({prog:'PROG'})
  formatter.add_usage(parser.usage, parser._actions, parser._mutually_exclusive_groups)
  formatter.add_text(parser.description)
  for ag in parser._action_groups
    formatter.start_section(ag.title)
    formatter.add_text(ag.description)
    formatter.add_arguments(ag._group_actions)
    formatter.end_section()
  return formatter

#---------------
# Testing
#---------------
if not module.parent?
  ap = require('./argcoffee').ArgumentParser
  parser = new ap({prog:'PROG', debug:true})
  parser.add_argument('-f','--foo',{help: 'foo help'})
  parser.add_argument('boo',{help: 'boo help', nargs:1})
  parser.add_argument('baz',{nargs:'+'})
  # console.log parser.format_usage()
  console.log parser.format_help()
  formatter = new HelpFormatter({prog:'PROG'})
  formatter.add_usage(parser.usage, parser._actions, [])
  formatter.add_text('a description %(prog)s')
  console.log 'format_help\n', formatter.format_help()

  for ag in parser._action_groups
    formatter.start_section(ag.title)
    formatter.add_text(ag.description)
    formatter.add_arguments(ag._group_actions)
    formatter.end_section()
  DEBUG ''
  console.log 'format_help\n', formatter.format_help()
  console.log '============================================='
  # DEBUG = () -> # turn it off
  console.log 'help wrapping'
  parser = new ap({prog:'PROG', debug: true, \
      description: '   oddly    formatted\n' +
                    'description\n' +
                    '\n' +
                    'that is so long that it should go onto multiple ' +
                    'lines when wrapped'})
  parser.add_argument('-x',{metavar:'XX',help: 'oddly\n'+
                                     '    formatted -x help'})
  parser.add_argument('y',{metavar:'yyy',help: 'normal y help'})
  group = parser.add_argument_group({title:'title', description: '\n'+
                                  '    oddly formatted group\n' +
                                  '\n' +
                                  'description'})
  group.add_argument('-a',{action:'storeTrue',\
              help: ' oddly \n'+
                   'formatted    -a  help  \n'+
                   '    again, so long that it should be wrapped over '+
                   'multiple lines'})
  console.log parser.format_help()
  console.log '------------------'
  formatter = setup(parser)
  console.log 'format_help\n', formatter.format_help()

  console.log '============================================='
  console.log 'test usage wrap'
  ap = require('./argcoffee').ArgumentParser
  parser = new ap({prog:'PROG', debug:true})
  parser.add_argument('-f','--foo',{help: 'foo help',nargs: 3})
  parser.add_argument('--booboo',{help: 'booboo help', nargs:4})
  parser.add_argument('baz',{nargs:'+'})
  formatter = setup(parser)
  console.log parser.format_help()
  console.log '-------------------'
  console.log formatter.format_help()


  console.log '============================================='
  console.log 'parser with exclusive group'
  parser = new ap({prog: 'PROG', debug: true});
  group = parser.addMutuallyExclusiveGroup({required: true});
  // or should the input be {required: true}?
  group.addArgument(['--foo'], {action: 'storeTrue', help: 'foo help'});
  group.addArgument(['--spam'], {help: 'spam help'});
  #parser.addArgument(['badger'], {nargs: '*', defaultValue: 'X', help: 'badger help'});
  group2 = parser.addMutuallyExclusiveGroup({required: false});
  group2.addArgument(['--soup'], {action: 'storeTrue'});
  group2.addArgument(['--nuts'], {action: 'storeFalse'});
  args = parser.parseArgs(['--spam', 'S']);
  DEBUG 'xgroup actions:',(x.dest for x in parser._mutually_exclusive_groups[0]._group_actions)
  formatter = setup(parser)
  console.log parser.format_help()
  console.log '-------------------'
  console.log formatter.format_help()

  console.log '========================='
  console.log 'subparsers'
  HelpFormatter_js = require('./formatter')
  parser = new ap({prog:'PROG',debug:true, formatter_class:HelpFormatter_js,description:'description with %(prog)s subsitution'})
  parser.add_argument('--foo', {action:'storeTrue', help:'foo help'})
  subparsers = parser.add_subparsers({help:'sub-command of %(prog)s help'})

  # create the parser for the "a" command
  parser_a = subparsers.addParser('a', {help:'a help',formatter_class:HelpFormatter_js})
  parser_a.add_argument('bar', {type:'int', help:'bar help, type: %(type)s'})

  # create the parser for the "b" command
  parser_b = subparsers.addParser('b', {help:'b help',formatter_class:HelpFormatter_js})
  parser_b.add_argument('--baz', {choices:'XYZ', help:'baz help, default: %(defaultValue)s', defaultValue: 'X'})

  console.log parser.format_help()
  console.log parser_a.format_help()
  console.log parser_b.format_help()
  console.log '-------------------'
  formatter = setup(parser)
  console.log formatter.format_help()

  parser_a.formatter_class = HelpFormatter
  console.log parser_a.format_help()
  console.log parser_b.format_help()

if false
  console.log '==============================='
  console.log 'choices'
  parser = new ap({prog:'PROG',debug:true,formatter_class:HelpFormatter_js})
  parser.add_argument('foo', {type:'int', choices:[5...10]})
  formatter = setup(parser)
  console.log parser.format_help()
  console.log '-------------------'
  console.log formatter.format_help()

