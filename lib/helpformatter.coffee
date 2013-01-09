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
  [indent, text, width, spc] = tup
  spc = spc ? ' '
  text = text ? ''
  indentstr = (spc for i in [0...indent]).join('')
  text = indentstr + text
  if width?
    text = _.str.pad(text, width+indent, ' ', 'right')
  if _.str.endsWith(fmt, '\n')
    # or maybe grab everything after the last %s
    text = text + '\n'
  return text

_textwrap =
  wrap: (text, width) -> 
    return text
  fill: (text, width, initial_indent=0, subsequent_indent=0) -> 
    return text
  
pformat = (fmt, params) ->
  # standin for python format
  for p in params
    fmt=fmt.replace(/%s/,p)
  return fmt
  
# ===============
# Formatting Help
# ===============

class HelpFormatter
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
      if width?
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

      @_whitespace_matcher = /\s+/ # _re.compile(r'\s+')
      @_long_break_matcher = /\n\n\n+/g # _re.compile(r'\n\n\n+')

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
            DEBUG 'new Section',@heading

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
                heading = fmtwindent('%*s%s:\n', [current_indent, @heading+':'])
            else
                heading = ''

            # join the section-initial newline, the heading and the help
            return join(['\n', heading, item_help, '\n'])

    _add_item: (func, args) ->
        DEBUG 'add_item', @_current_section.heading,args[0]?.dest
        @_current_section.items.push([func, args])

    # ========================
    # Message building methods
    # ========================
    start_section: (heading) ->
        @_indent()
        section = new @_Section(@, @_current_section, heading)
        @_add_item(section.format_help, [])
        @_current_section = section

    end_section: () ->
        @_current_section = @_current_section.parent
        @_dedent()

    add_text: (text) ->
        if text != $$.SUPPRESS and text?
            @_add_item(@_format_text, [text])

    add_usage: (usage, actions, groups, prefix=null) ->
        if usage != $$.SUPPRESS
            args = [usage, actions, groups, prefix]
            @_add_item(@_format_usage, args)

    add_argument: (action) ->
        if action.help != $$.SUPPRESS

            # find all invocations
            get_invocation = @_format_action_invocation
            invocations = [get_invocation(action)]
            for subaction in @_indented_subactions(action)
                invocations.push(get_invocation(subaction))

            # update the maximum item length
            invocation_length = Math.max(s.length for s in invocations)
            action_length = invocation_length + @_current_indent
            @_action_max_length = Math.max(@_action_max_length,action_length)

            # add the item to the list
            @_add_item(@_format_action, [action])

    add_arguments: (actions) ->
        for action in actions
            @add_argument(action)

    # =======================
    # Help-formatting methods
    # =======================
    format_help: () ->
        help = @_root_section.format_help()
        if help
            # help = @_long_break_matcher.sub('\n\n', help)
            help = help.replace(@_long_break_matcher, '\n\n')
            help = _.str.strip(help,'\n') + '\n'
        return help

    _join_parts: (part_strings) ->
        return (part for part in part_strings when part and part != $$.SUPPRESS).join('')

    _format_usage: (usage, actions, groups, prefix) =>
        if prefix is null
            prefix = 'usage: '

        # if usage is specified, use that
        if usage?
            #  usage = usage % dict(prog=@_prog)
            usage = usage.replace(/%(prog)/, @_prog)

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
                if action.optionStrings.length>0
                    optionals.push(action)
                else
                    positionals.push(action)

            # build full usage string
            format = @_format_actions_usage
            action_usage = format([].concat(optionals, positionals), groups)
            usage = (s for s in [prog, action_usage] when s).join(' ')
              
            ###  
            # wrap the usage parts if it's too long
            text_width = @_width - @_current_indent
            if prefix.length + usage.length > text_width

                # break usage into wrappable parts
                part_regexp = /\(.*?\)+|\[.*?\]+|\S+/g
                opt_usage = format(optionals, groups)
                pos_usage = format(positionals, groups)
                  
                opt_parts = opt_usage.match(part_regexp) ? []
                pos_parts = pos_usage.match(part_regexp) ? []
                #opt_parts = _re.findall(part_regexp, opt_usage)
                #pos_parts = _re.findall(part_regexp, pos_usage)
                #assert opt_parts?.join(' ') == opt_usage
                #assert pos_parts?.join(' ') == pos_usage

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
                    if line
                        lines.push(indent + line.join(' '))
                    if prefix?
                        lines[0] = lines[0][indent.length]
                    return lines

                # if prog is short, follow it with optionals or positionals
                if prefix.length + prog.length <= 0.75 * text_width
                    indent = ' ' * (prefix.length + prog.length + 1)
                    if opt_parts
                        lines = get_lines([prog].concat(opt_parts), indent, prefix)
                        lines.concat(get_lines(pos_parts, indent))
                    else if pos_parts
                        lines = get_lines([prog].concat(pos_parts), indent, prefix)
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
          ###
        # prefix with 'usage:'
        return prefix + usage + "\n\n"

    _format_actions_usage: (actions, groups) =>
        # find group indices and identify actions in groups
        group_actions = {} # set()
        inserts = {}
        ###
        for group in groups
            try
                start = actions.index(group._group_actions[0])
            catch ValueError
                continue
            #else
            end = start + group._group_actions.length
            if actions[start...end] == group._group_actions
                for action in group._group_actions
                    group_actions[action] = true
                if not group.required
                    if start in inserts
                        inserts[start] += ' ['
                    else
                        inserts[start] = '['
                    inserts[end] = ']'
                else
                    if start in inserts
                        inserts[start] += ' ('
                    else
                        inserts[start] = '('
                    inserts[end] = ')'
                for i in range(start + 1, end)
                    inserts[i] = '|'
        ###
        # collect all actions format strings
        parts = []
        i = -1
        for action in actions
            i++
            # suppressed arguments are marked with null
            # remove | separators for suppressed arguments
            if action.help is $$.SUPPRESS
                parts.push(null)
                if inserts[i] == '|'
                    delete inserts[i]
                else if inserts[i + 1] == '|'
                    delete inserts[i + 1]

            # produce all arg strings
            else if action.optionStrings.length==0
                part = @_format_args(action, action.dest)

                # if it's in a group, strip the outer []
                if action of group_actions
                    if part[0] == '[' and _.last(part) == ']'
                        part = _last(_.rest(part)) # part[1...-1]

                # add the action string to the list
                parts.push(part)

            # produce the first way to invoke the option in brackets
            else
                option_string = action.optionStrings[0]

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
                if not action.required and action not of group_actions
                    part = "[#{part}]"

                # add the action string to the list
                parts.push(part)
        # insert things at the necessary indices
        #for i in sorted(inserts, reverse=true)
        #    parts[i...i] = [inserts[i]]
        `for (var i = inserts.length-1; i >= 0; --i) {
           if (inserts[i] != null) {
             parts.splice(i, 0, inserts[i]);
           }
         };`

        # join all the action items with spaces
        text = (item for item in parts when item?)
        text = text.join(' ')

        # clean up separators for mutually exclusive groups
        ###
        open = r'[\[(]'
        close = r'[\])]'
        text = _re.sub(r'(%s) ' % open, r'\1', text)
        text = _re.sub(r' (%s)' % close, r'\1', text)
        text = _re.sub(r'%s *%s' % (open, close), r'', text)
        text = _re.sub(r'\(([^|]*)\)', r'\1', text)
        text = text.strip()
        ###
        # clean up separators for mutually exclusive groups
        `text = text.replace(/([\[(]) /g,'$1'); // remove spaces
        text = text.replace(/ ([\])])/g,'$1');
        text = text.replace(/\[ *\]/g, ''); // remove empty groups
        text = text.replace(/\( *\)/g, '');
        text = text.replace(/\(([^|]*)\)/g, '$1'); // remove () from single action groups
        text = _.str.strip(text);`
        # return the text
        return text

    _format_text: (text) =>
        if '%(prog)' in text
            text = text.replace(/\%\(prog\)/, @prog)
            #text = text % {prog:@prog}
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
            tup = [@_current_indent, action_header, action_width+2]
            action_header = fmtwindent('%*s%-*s  ',tup)
            indent_first = 0

        # long action name; start on the next line
        else
            action_header = ftmwindent('%*s%s\n', [@_current_indent, ' ', action_header])+'\n'
            indent_first = help_position

        # collect the pieces of the action help
        parts = [action_header]

        # if there was help for the action, add lines of help text
        if action.help?
            help_text = @_expand_help(action)
            help_lines = @_split_lines(help_text, help_width)
            help_lines = if _.isString(help_lines) then [help_lines] else help_lines
            # parts.push('%*s%s\n' % (indent_first, '', help_lines[0]))
            parts.push(fmtwindent('%*s%s\n',[indent_first, help_lines[0]]))
            for line in help_lines[1...]
                #parts.push('%*s%s\n' % (help_position, '', line))
                parts.push(fmtwindent('%*s%s\n', [help_position, line]))
        # or add a newline if the description doesn't end with one
        else if not _.str.endsWith(action_header, '\n')
            parts.push('\n')
        # if there are any sub-actions, add their help as well
        for subaction in @_indented_subactions(action)
            parts.push(@_format_action(subaction))

        # return a single string
        return @_join_parts(parts)

    _format_action_invocation: (action) =>
        if action.optionStrings.length==0
            metavar = @_metavar_formatter(action, action.dest)(1)[0]
            return metavar
        else
            parts = []
            
            # if the Optional doesn't take a value, format is
            #    -s, --long
            if action.nargs == 0
                parts = parts.concat(action.optionStrings)
            # if the Optional takes a value, format is
            #    -s ARGS, --long ARGS
            else
                defaultValue = action.dest.toUpperCase()
                args_string = @_format_args(action, defaultValue)
                for option_string in action.optionStrings
                    parts.push("#{option_string} #{args_string}")

            return parts.join(', ')

    _metavar_formatter: (action, default_metavar) ->
        if action.metavar?
            result = action.metavar
        else if action.choices?
            choice_strs = (str(choice) for choice in action.choices)
            #result = '{%s}' % ','.join(choice_strs)
            result = "#{choice_strs.join(',')}"
        else
            result = default_metavar

        format = (tuple_size) ->
            return (result for i in [0...tuple_size]) 
                
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
            formats = ('%s' for i in [0...action.nargs]).join(' ')
            result = pformat(formats ,get_metavar(action.nargs))
        return result

    _expand_help: (action) ->
        return @_get_help_string(action)    
        # params = dict(vars(action), prog=@_prog)
        params = _.clone(action); params.prog = @_prog
        for name in _.keys(params)
            if params[name] == $$.SUPPRESS
                delete params[name]
        for name in _.keys(params)
            # process.title?
            # process.argv
            # process.mainModule.id
            # if hasattr(params[name], '__name__')
            if params[name]?.__name__?
                params[name] = params[name].__name__
        if params.choices?
            choices_str = (''+c for c in params.choices).join(', ')
            params.choices = choices_str
        return pformat(@_get_help_string(action), params)
        
    _indented_subactions: (action) ->
        # was iter in py
        if action._get_subactions?
          get_subactions = action._get_subactions
          return get_subactions()
          # skip indent for now; maybe a callback is the way to implement this
          # subparser has subactions
          #@_indent()
          #for subaction in get_subactions()
          #  return subaction # really is yield
          #@_dedent()
        else
          return []

    _split_lines: (text, width) ->
        return text
        # text = @_whitespace_matcher.sub(' ', text).strip()
        text = text.replace(@_whitespace_matcher, ' ')
        text = _.str.strip(text)
        return _textwrap.wrap(text, width)

    _fill_text: (text, width, indent) ->
        return text
        # text = @_whitespace_matcher.sub(' ', text).strip()
        text = _.str.strip(text.replace(@_whitespace_matcher, ' '))
        return _textwrap.fill(text, width, indent, indent)

    _get_help_string: (action) ->
        return action.help


class RawDescriptionHelpFormatter extends HelpFormatter
    ###Help message formatter which retains any formatting in descriptions.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _fill_text: (text, width, indent) ->
        return (indent + line for line in text.splitlines(true)).join('')


class RawTextHelpFormatter extends RawDescriptionHelpFormatter
    ###Help message formatter which retains formatting of all help text.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _split_lines: (text, width) ->
        return text.splitlines()


class ArgumentDefaultsHelpFormatter extends HelpFormatter
    ###Help message formatter which adds default values to argument help.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _get_help_string: (action) ->
        help = action.help
        if not '%(default)' in action.help
            if action.defaultValue != $$.SUPPRESS
                defaulting_nargs = [$$.OPTIONAL, $$.ZERO_OR_MORE]
                if action.optionStrings or action.nargs in defaulting_nargs
                    help += ' (default: %(default)s)'
        return help


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
  formatter.add_text('a description')
  console.log 'format_help\n', formatter.format_help()
  
  for ag in parser._action_groups
    formatter.start_section(ag.title)
    #DEBUG 'add_text'
    formatter.add_text(ag.description)
    #DEBUG 'add_arg'
    formatter.add_arguments(ag._group_actions)
    #DEBUG 'end section'    
    formatter.end_section()
  DEBUG ''
  console.log 'format_help\n', formatter.format_help()
