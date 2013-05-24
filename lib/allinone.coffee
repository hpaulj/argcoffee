

###
coffeescript translation
hpaulj@github

argparse.py
# Author: Steven J. Bethard <steven.bethard@gmail.com>.

Command-line parsing library

This module is an optparse-inspired command-line parsing library that:

    - handles both optional and positional arguments
    - produces highly informative usage messages
    - supports parsers that dispatch to sub-parsers

The following is a simple usage example that sums integers from the
command-line and writes the result to a file::

    parser = argparse.ArgumentParser(
        description='sum the integers at the command line')
    parser.add_argument(
        'integers', metavar='int', nargs='+', type=int,
        help='an integer to be summed')
    parser.add_argument(
        '--log', default=sys.stdout, type=argparse.FileType('w'),
        help='the file where the sum should be written')
    args = parser.parse_args()
    args.log.write('%s' % sum(args.integers))
    args.log.close()

The module contains the following public classes:

    - ArgumentParser -- The main entry point for command-line parsing. As the
        example above shows, the add_argument() method is used to populate
        the parser with actions for optional and positional arguments. Then
        the parse_args() method is invoked to convert the args at the
        command-line into an object with attributes.

    - ArgumentError -- The exception raised by ArgumentParser objects when
        there are errors with the parser actions. Errors raised while
        parsing the command-line are caught by ArgumentParser and emitted
        as command-line messages.

    - FileType -- A factory for defining types of files to be created. As the
        example above shows, instances of FileType are typically passed as
        the type= argument of add_argument() calls.

    - Action -- The base class for parser actions. Typically actions are
        selected by passing strings like 'store_true' or 'append_const' to
        the action= argument of add_argument(). However, for greater
        customization of ArgumentParser actions, subclasses of Action may
        be defined and passed as the action= argument.

    - HelpFormatter, RawDescriptionHelpFormatter, RawTextHelpFormatter,
        ArgumentDefaultsHelpFormatter -- Formatter classes which
        may be passed as the formatter_class= argument to the
        ArgumentParser constructor. HelpFormatter is the default,
        RawDescriptionHelpFormatter and RawTextHelpFormatter tell the parser
        not to change the formatting for help text, and
        ArgumentDefaultsHelpFormatter adds information about argument defaults
        to the help.

All other classes in this module are considered implementation details.
(Also note that HelpFormatter and RawDescriptionHelpFormatter are only
considered public as object names -- the API of the formatter objects is
still considered an implementation detail.)

###

DEBUG = () ->

util = require('util') # node
assert = require('assert')
path = require('path')
_ = require('underscore')
_.str = require('underscore.string')


###
Constants
###
$$ = {}
$$.EOL = '\n'
$$.SUPPRESS = '==SUPPRESS=='
$$.OPTIONAL = '?'
$$.ZERO_OR_MORE = '*'
$$.ONE_OR_MORE = '+'
$$.PARSER = 'A...'
$$.REMAINDER = '...'
$$._UNRECOGNIZED_ARGS_ATTR = '_unrecognized_args'


# =============================
# Utility functions and classes
# =============================

# class _AttributeHolder(object):  # not implemented
__repr__ = (obj, arglist = null) ->
    # like _AttributeHolder.__repr__
    foo = (value) ->
      if _.isString(value)
        return "'#{value}'"
      if _.isArray(value)
        xxx = (foo(v) for v in value).join(', ')
        return "[#{xxx}]"
      if _.isFunction(value)
        return value.name
      return value
    type_name = obj.constructor.name # coffee class name
    arg_strings = []
    if arglist
        arg_strings = ("#{arg}: #{foo(obj[arg])}" for arg in arglist)
    else
        arg_strings = ("#{key}: #{foo(value)}" for own key,value of obj when value?)
    return "#{type_name} {#{ arg_strings.join(', ')}}"


# ===============
# Formatting Help
# ===============

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
  # add error checking as in python %
  for p in params
    if fmt.indexOf('%s')<0
      throw new Error('not all arguments converted during string formatting')
    fmt=fmt.replace(/%s/,p)
  if fmt.indexOf('%s')>-1
    throw new Error('not enough arguments for format string')
  return fmt

pnformat = (fmt, params) ->
  # standin for python format with named entries
  # params is an object,
  # if {k:v} in params, then fmt='%(k)s' becomes 'v'
  for k of params
    fmt = fmt.replace("%(#{k})s",params[k])
  return fmt


class HelpFormatter
    ###
    Formatter for generating usage messages and argument help strings.

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
        # text = _.str.strip(text);
        text = _.str.clean(text);  # rm duplicate spaces as well
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
            if tuple_size>0
              return (result for i in [0...tuple_size])
            else
              return []
        return format

    _format_args: (action, default_metavar) ->
        get_metavar = @_metavar_formatter(action, default_metavar)
        nargs = action.nargs
        if !nargs?  #  null
            result = pformat('%s', get_metavar(1))
        else if nargs == $$.OPTIONAL
            result = pformat('[%s]', get_metavar(1))
        else if nargs == $$.ZERO_OR_MORE
            result = pformat('[%s [%s ...]]',get_metavar(2))
        else if nargs == $$.ONE_OR_MORE
            result = pformat('%s [%s ...]',get_metavar(2))
        else if nargs == $$.REMAINDER
            result = '...'
        else if nargs == $$.PARSER
            result = pformat('%s ...', get_metavar(1))
        else
            if not isFinite(nargs)  # other integer test?, '1' passes
              throw new Error("nargs '#{nargs}' not a valid string or integer")
            # formats = ('%s' for i in [0...action.nargs]).join(' ')
            # formats = Array(action.nargs+1).join('%s')
            if nargs>0
              formats = ('%s' for i in [0...nargs]).join(' ')
            else if nargs<0
              throw new Error("nargs '#{nargs}' less than 0")
            else
              formats = ''
            try
              result = pformat(formats ,get_metavar(nargs))
            catch error
              throw new Error("length of metavar tuple does not match nargs")
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
    ###
    Help message formatter which retains any formatting in descriptions.

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
    ###
    Help message formatter which retains formatting of all help text.

    Only the name of this class is considered a public API. All the methods
    provided by the class are considered an implementation detail.
    ###

    _split_lines: (text, width) ->
        return text.split('\n')  # text.splitlines()



class ArgumentDefaultsHelpFormatter extends HelpFormatter
    ###
    Help message formatter which adds default values to argument help.

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

# =====================
# Options and Arguments
# =====================

class ArgumentTypeError extends Error
  ### An error from trying to convert a command line string to a type. ###
  constructor: (msg) ->
    Error.captureStackTrace(@, @)
    @.message = msg || 'Argument Error'
    @name = 'ArgumentTypeError'

###
An error from creating or using an argument (optional or positional).

The string value of this exception is the message, augmented with
information about the argument that caused it.
###
class ArgumentError extends Error
  constructor: (@argument=null, @message="") ->
    @name = "ArgumentError"
    Error.captureStackTrace(@, @)
    try
      @argument_name = @argument.getName() # action.getName
    catch err
      @argument_name = _get_action_name(@argument)
    #console.log @argument.getName()
    #console.log _get_action_name(@argument)
  toString: () ->
    if @argument_name?
      astr = "argument \"#{@argument_name}\": #{@message}"
    else
      astr = ""+@message
    astr = @name + ': ' + astr

_get_action_name = (argument) ->
    if argument is null
        return null
    else if argument.isOptional()
        return  argument.option_strings.join('/')
    else if argument.metavar not in [null, $$.SUPPRESS]
        return argument.metavar
    else if argument.dest not in [null, $$.SUPPRESS]
        return argument.dest
    else
        return null

# ==============
# Action classes
# ==============

class Action
    ###
    Information about how to convert command line strings to Python objects.

    Action objects are used by an ArgumentParser to represent the information
    needed to parse a single argument from one or more strings from the
    command line. The keyword arguments to the Action constructor are also
    all attributes of Action instances.

    Keyword Arguments:

        - option_strings -- A list of command-line option strings which
            should be associated with this action.

        - dest -- The name of the attribute to hold the created object(s)

        - nargs -- The number of command-line arguments that should be
            consumed. By default, one argument will be consumed and a single
            value will be produced.  Other values include:
                - N (an integer) consumes N arguments (and produces a list)
                - '?' consumes zero or one arguments
                - '*' consumes zero or more arguments (and produces a list)
                - '+' consumes one or more arguments (and produces a list)
            Note that the difference between the default and nargs=1 is that
            with the default, a single value will be produced, while with
            nargs=1, a list containing a single value will be produced.

        - constant -- The value to be produced if the option is specified and the
            option uses an action that takes no values.

        - defaultValue -- The value to be produced if the option is not specified.

        - type -- The type which the command-line arguments should be converted
            to, should be one of 'string', 'int', 'float', 'complex' or a
            callable object that accepts a single string argument. If null,
            'string' is assumed.

        - choices -- A container of values that should be allowed. If not null,
            after a command-line argument has been converted to the appropriate
            type, an exception will be raised if it is not a member of this
            collection.

        - required -- True if the action must always be specified at the
            command line. This is only meaningful for optional command-line
            arguments.

        - help -- The help string describing the argument.

        - metavar -- The name to be used for the options argument with the
            help string. If null, the 'dest' value will be used as the name.
    ###

    constructor: (options) ->
        @option_strings = options.option_strings ? []
        @dest = options.dest ? ''
        @nargs = options.nargs ? null
        @constant = options.constant ? null
        @defaultValue = options. defaultValue ? null
        @type = options.type ? null
        @choices = options.choices ? null
        @required = options.required ? false
        @help = options.help ? null
        @metavar = options.metavar ? null

    repr: () ->
        # compact representation of the Action's values
        # skip container, since that makes the display too long
        arglist = (key for own key, value of @ when key != 'container' and value?)
        return __repr__(@, arglist)
    toString: @::repr

    __call__: (parser, namespace, values, option_string=null) ->
        throw new Error(_('.__call__() not defined'))
    call: (parser, namespace, values, option_string=null) ->
        @__call__(parser, namespace, values, option_string=null)

    getName: () ->
        # not in py, but used by the JS version that this was built on
        # is this unique enough to use as hash key?
        if @option_strings.length>0
            @.option_strings.join('/')
        else if @metavar ? @.metavar != $$.SUPPRESS
            @.metavar
        else if @dest ? @dest != $$.SUPPRESS
            @.dest

    getName: () ->
        # essentially the same as _get_action_name
        if @option_strings.length > 0
            return @option_strings.join('/')
        else if @metavar != null and @metavar != $$.SUPPRESS
            return @metavar
        else if @dest? and @dest != $$.SUPPRESS
            return @dest;
        else
            return null


    isOptional: () ->
        # convenience used by argparse
        not @isPositional()

    isPositional: () ->
        @option_strings.length == 0

class _StoreAction extends Action

    constructor: (options) ->
        if options.nargs == 0
            throw new Error('nargs for store actions must be > 0; if you ' +\
                             'have nothing to store, actions such as store ' +\
                             'true or store constant may be more appropriate')
        if options.constant? and options.nargs != $$.OPTIONAL
            throw new Error("nargs must be #{$$.OPTIONAL} to supply constant")
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        namespace.set(@dest, values)

class _StoreConstAction extends Action

    constructor: (options) ->
        options.nargs = 0
        options.constant ?= options.const
        # const is a JS keyword
        if not options.constant?
            throw new Error('StoreConstAction needs a constant parameter')
        # type, choices ignored (error if given?)
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        namespace.set(@dest, @constant)

class _StoreTrueAction extends _StoreConstAction

    constructor: (options) ->
        options.constant = true
        options.defaultValue ?= false
        super(options)

class _StoreFalseAction extends _StoreConstAction

    constructor: (options) ->
        options.constant = false
        options.defaultValue ?= true
        super(options)

class _AppendAction extends Action

    constructor: (options) ->
        if options.nargs == 0
            throw new Error('nargs for append actions must be > 0; if arg ' + \
                             'strings are not supplying the value to append, ' + \
                             'the append constant action may be more appropriate')
        if options.constant? and options.nargs != $$.OPTIONAL
            throw new Error("nargs must be #{$$.OPTIONAL} to supply constant")
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        #DEBUG namespace
        #DEBUG _ensure_value(namespace, @dest, [])
        items = _.clone(_ensure_value(namespace, @dest, []))
        items.push(values)
        namespace.set(@dest, items)


class _AppendConstAction extends Action

    constructor: (options) ->
        options.nargs = 0
        options.constant ?= options.const
        if options.constant?
            super(options)
        else
            throw new Error('constant required for AppendConstAction')

    __call__: (parser, namespace, values, option_string=null) ->
        items = _.clone(_ensure_value(namespace, @dest, []))
        items.push(@constant)
        namespace.set(@dest, items)


class _CountAction extends Action

    constructor: (options) ->
        # nargs ignored
        options.nargs = 0
        # constant, type, choices ignmored
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        new_count = _ensure_value(namespace, @dest, 0) + 1
        namespace.set(@dest, new_count)


class _HelpAction extends Action

    constructor: (options) ->
        options.dest ?= $$.SUPPRESS
        options.defaultValue ?= $$.SUPPRESS
        options.nargs = 0
        super(options)

    __call__: (parser, namespace, values, option_string=null) ->
        parser.print_help()
        if parser.debug
            console.log 'Help pseudo exit'
            parser.exit()
        else
            parser.exit()


class _VersionAction extends Action

    constructor: (options) ->
        options.version ?=null
        options.dest ?= $$.SUPPRESS
        options.defaultValue ?= $$.SUPPRESS
        options.help ?="show program's version number and exit"
        super(options)
        @version = options.version

    __call__: (parser, namespace, values, option_string=null) ->
        version = @version
        version ?= parser.version
        formatter = parser._get_formatter()
        formatter.add_text(version)
        parser.exit(formatter.format_help())


class _SubParsersAction extends Action

    class _ChoicesPseudoAction extends Action

        constructor: (name, aliases, help) ->
            metavar = dest = name
            if aliases.length>0
              metavar += " (#{aliases.join(', ')})"
            options = {option_strings:[], dest:name, help:help, metavar:metavar}
            super(options)

    constructor: (options) ->
        @_prog_prefix = options.prog
        @_parser_class = options.parser_class ? options.parserClass
        @_name_parser_map = {} # _collections.OrderedDict()
        @_choices_actions = []

        options.dest = options.dest ? $$.SUPPRESS
        options.nargs = $$.PARSER
        options.choices = @_name_parser_map
        # normal positional required test does not apply to subparsers
        options.required = options.required ? true
        super(options)
        @debug = options.debug

    add_parser: (name, options) ->
        # set prog from the existing prefix
        options ?= {}
        options.prog ?= "#{@_prog_prefix} #{name}"
        if options.aliases?
            aliases = options.aliases
            delete options.aliases
        else
            aliases = []
        options.debug ?= @debug # passed via group

        # create a pseudo-action to hold the choice help
        if options.help?
            help = options.help
            delete options.help
            choice_action = new _ChoicesPseudoAction(name, aliases, help)
            @_choices_actions.push(choice_action)

        # create the parser and add it to the map
        parser = new @_parser_class(options)
        @_name_parser_map[name] = parser

        # make parser available under aliases also
        for alias in aliases
            @._name_parser_map[alias] = parser

        return parser
    addParser: (name, options) -> @add_parser(name, options)

    _get_subactions: () =>
        @_choices_actions  # a list
    _getSubactions: () => @_get_subactions() # for formatter.js

    __call__: (parser, namespace, values, option_string=null) ->
        parser_name = values[0]
        arg_strings = values[1..]

        # set the parser name if requested
        if @dest != $$.SUPPRESS
            namespace.set(@dest, parser_name)

        # select the parser
        parser = @_name_parser_map[parser_name] ? null
        if parser == null
            choices = _.keys(@_name_parser_map).join(', ')
            # we get an invalid choices error first
            msg = "unknown parser #{parser_name} (choices: #{choices})"
            # throw new Error(msg)
            throw new ArgumentError(@, msg)

        # parse all the remaining options into the namespace
        # store any unrecognized options on the object, so that the top
        # level parser can decide what to do with them
        [namespace, arg_strings] = parser.parse_known_args(arg_strings, namespace)
        if arg_strings.length>0
            if not namespace[$$._UNRECOGNIZED_ARGS_ATTR]?
              namespace[$$._UNRECOGNIZED_ARGS_ATTR] = []
            for astring in arg_strings
              namespace[$$._UNRECOGNIZED_ARGS_ATTR].push(astring)
    getName: () ->
        # essentially the same as _get_action_name
        # custom for subparser, list choices if other name not give
        if @metavar != null and @metavar != $$.SUPPRESS
            return @metavar
        else if @dest? and @dest != $$.SUPPRESS
            return @dest;
        else
            choices = _.keys(@_name_parser_map).join('/')
            return "{#{choices}}"



action = {}
action.ActionHelp = _HelpAction
action.ActionAppend = _AppendAction
action.ActionAppendConstant = _AppendConstAction
action.ActionCount = _CountAction
action.ActionStore = _StoreAction
action.ActionStoreConstant = _StoreConstAction
action.ActionStoreTrue = _StoreTrueAction
action.ActionStoreFalse = _StoreFalseAction
action.ActionVersion = _VersionAction
action.ActionSubparsers = _SubParsersAction

# ==============
# Type classes
# ==============


class FileClass # Type
    ###Factory for creating file object types

    Instances of FileType are typically passed as type= arguments to the
    ArgumentParser add_argument() method.

    Keyword Arguments:
        - mode -- A string indicating how the file is to be opened. Accepts the
            same values as the builtin open() function.
        - bufsize -- The files desired buffer size. Accepts the same values as
            the builtin open() function.
    Python uses mode, nodejs uses 'flags'
    ###
    fs = require('fs') # nodejs
    constructor: (options) ->
        if _.isString(options)
          options = {flags:options}
        @options = options

    call: (filename) ->
        # the special argument "-" means sys.std{in,out}
        flags = @options.flags
        # console.log @options, flags
        if filename == '-'
            if 'r' in flags
                return process.stdin
            else if 'w' in flags
                return process.stdout
            else
                msg = "argument '-' with flags #{flags}"
                throw new TypeError(msg)
                # @error(msg) # raise ValueError(msg)
        if flags == 'r'
          createStream = fs.createReadStream
        else if flags == 'w'
          createStream = fs.createWriteStream
        else
          throw new TypeError('Unknown file flag')
          # don't try to handle more complicated flags like r+
        try
          # open file before creating stream
          # and capture any errors
          fd = fs.openSync(filename, flags)
          @options.fd = fd
          stream = createStream(filename, @options)
        catch error
          throw new ArgumentTypeError(error.message)
        return stream


FileType = (options={flags:'r'}) ->
    # callable function that can be used by Action store
    ft = new FileClass(options)
    fn = (string) ->
        ft.call(string)
    fn.displayName = 'FileType' # name to use in error messages
    return fn

# don't need a class; just return a function that takes the string argument
# and returns a file (here a stream) or throws an error
fileType = (options={flags:'r'}) ->
    # callable function that can be used by _get_value
    fs = require('fs')
    fn = (filename) ->
        # the special argument "-" means sys.std{in,out}
        flags = options.flags
        # console.log @options, flags
        if filename == '-'
            if 'r' in flags
                return process.stdin
            else if 'w' in flags
                return process.stdout
            else
                msg = "argument '-' with flags #{flags}"
                throw new Error(msg)
        if flags == 'r'
          createStream = fs.createReadStream
        else if flags == 'w'
          createStream = fs.createWriteStream
        else
          throw new TypeError('Unknown file flag')
          # don't try to handle more complicated flags like r+
        try
          # open file before creating stream
          # and capture any errors
          fd = fs.openSync(filename, flags)
          options.fd = fd
          stream = createStream(filename, options)
        catch error
          throw error
        return stream
    fn.displayName = 'FileType' # name to use in error messages
    return fn

fileType = (options={flags:'r'}) ->
    # callable function that can be used by _get_value
    # or a more compact form
    fs = require('fs')
    if _.isString(options)
      flags = options
    else
      {flags} = options
    if flags == 'r'
      [std, createStream] = [process.stdin, fs.createReadStream]
    else if flags == 'w'
      [std, createStream] = [process.stdout, fs.createWriteStream]
    else
      msg = "argument '-' with flag #{flags}"
      throw new TypeError(msg)
    fn = (filename) ->
      if filename == '-'
        stream = std
      else
        # open file before creating stream
        # and capture any errors
        try
          fd = fs.openSync(filename, flags)
          options.fd = fd
          stream = createStream(filename, options)
        catch err
          msg = "can't open #{filename}: #{err.message}"
          throw ArgumentTypeError(msg)
      return stream
    fn.displayName = 'FileType' # name to use in error messages
    return fn

# use: parser.add_argument('--outfile',{type:ap.FileType('w')})
# args.outfile should then be a writable filehandle

# ===========================
# Optional and Positional Parsing
# ===========================

# basic methods in Python, used to access Namespace
# with these do we need a special Namespace class?
getattr = (obj, key, defaultValue) ->
    obj[key] ? defaultValue
setattr = (obj, key, value) ->
    obj[key] = value
hasattr = (obj, key) ->
    obj[key]?

_ensure_value = (namespace, name, value) ->
    if getattr(namespace, name, null) is null
        setattr(namespace, name, value)
    return getattr(namespace, name)

if true
  # in effect, a name change
  ActionHelp = action.ActionHelp
  ActionAppend = action.ActionAppend
  ActionAppendConstant = action.ActionAppendConstant
  ActionCount = action.ActionCount
  ActionStore = action.ActionStore
  ActionStoreConstant = action.ActionStoreConstant
  ActionStoreTrue = action.ActionStoreTrue
  ActionStoreFalse = action.ActionStoreFalse
  ActionVersion = action.ActionVersion
  ActionSubparsers = action.ActionSubparsers

class _ActionsContainer
  constructor: (options={}) ->
    # description, prefixChars, argument_default, conflict_handler):
    # super(_ActionsContainer, self).__init__()

        @description = options.description
        @argument_default = options.argument_default
        @prefix_chars = options.prefixChars ? options.prefix_chars
        @conflict_handler = options.conflict_handler

        # set up registries
        @_registries = {}

        # register actions
        @register('action', null, ActionStore);
        @register('action', 'store', ActionStore);
        @register('action', 'storeConst', ActionStoreConstant);
        @register('action', 'store_const', ActionStoreConstant);
        @register('action', 'storeTrue', ActionStoreTrue);
        @register('action', 'store_true', ActionStoreTrue);
        @register('action', 'storeFalse', ActionStoreFalse);
        @register('action', 'store_false', ActionStoreFalse);
        @register('action', 'append', ActionAppend);
        @register('action', 'appendConst', ActionAppendConstant);
        @register('action', 'append_const', ActionAppendConstant);
        @register('action', 'count', ActionCount);
        @register('action', 'help', ActionHelp);
        @register('action', 'version', ActionVersion);
        @register('action', 'parsers', ActionSubparsers);

        # raise an exception if the conflict handler is invalid
        @_get_handler()

        # action storage
        @_actions = []
        @_option_string_actions = {}

        # groups
        @_action_groups = []
        @_mutually_exclusive_groups = []

        # defaults storage
        @_defaults = {}

        # determines whether an "option" looks like a negative number
        @_negative_number_matcher = /^-\d+$|^-\d*\.\d+$/
        # @_negative_number_matcher = /^-(\d+\.?|\d*\.\d+)([eE][+\-]?\d+)?$/

        # whether or not there are any optionals that look like negative
        # numbers -- uses a list so it can be shared and edited
        @_hasNegativeNumberOptionals = []
        @

    # ====================
    # Registration methods
    # ====================
  register: (registry_name, value, object) ->
        if not _.has(@_registries, registry_name)
          @_registries[registry_name] = {}
        registry = @_registries[registry_name]
        # registry = @_registries.setdefault(registry_name, {})
        registry[value] = object

  _registry_get:  (registry_name, value, defaultValue=null)->
        # return @_registries[registry_name].get(value, defaultValue)
        return @_registries[registry_name][value] ? defaultValue
  _registryGet: (arg1,arg2,arg3) -> @_registry_get(arg1,arg2,arg3)
    # ==================================
    # Namespace default accessor methods
    # ==================================
  set_defaults: (options) ->
        #@_defaults.update(options)
        _.extend(@_defaults, options)

        # if these defaults match any existing arguments, replace
        # the previous default on the object with the new one
        for action in @_actions
            if action.dest of options
                action.default = options[action.dest]
  setDefaults: (options) -> @set_defaults(options)

  get_default: (dest) ->
        for action in @_actions
            if action.dest == dest and action.defaultValue != null
                return action.defaultValue
        #return @_defaults.get(dest, null)
        return @_defaults[dest] ? null
  getDefault: (dest) -> @get_default(dest)

    # =======================
    # Adding argument actions
    # =======================

  add_argument:  (args..., options) ->
        """
        add_argument(dest, ..., name=value, ...)
        add_argument(option_string, option_string, ..., name=value, ...)
        """
        if _.isString(options)
          # assume
          args.push(options)
          options = {}
        if not options?
          options = {}
        # at this point, args is list of strings (possibly empty)
        # options is an object (py dict)
        #DEBUG 'args, options: ', args, options
        # if no positional args are supplied or only one is supplied and
        # it doesn't look like an option string, parse a positional
        # argument

        chars = @prefix_chars
        if args.length==0 or (args.length==1 and args[0][0] not in chars)
            #if not args or len(args) == 1 and args[0][0] not in chars
            if args.length>0 and 'dest' of options
                throw new Error('dest supplied twice for positional argument')
            options = @_get_positional_options(args, options)

        # otherwise, we're adding an optional argument
        else
            options = @_get_optional_options(args, options)

        #DEBUG options
        # here options has an option_strings attribute
        # rest of this class expects that
        # but Action expects and returns (empty) option_strings
        # temp fix: duplicate the attribute in options
        # and always use action.option_strings
        # leave options_strings else where
        # positional has [], optional [...]

        # if no default was supplied, use the parser-level default
        if 'defaultValue' not of options
            dest = options.dest
            if dest of @_defaults
                options.defaultValue = @_defaults[dest]
            else if @argument_default != null
                options.defaultValue = @argument_default
            else
                options.defaultValue = null

        # create the action object, and add it to the parser
        action_class = @_pop_action_class(options)
        # if not _callable(action_class)
        if not _.isFunction(action_class)
            throw new Error("unknown action '#{action_class}'")
        action = new action_class(options)

        # raise an error if the action type is not callable
        type_func = @_registry_get('type', action.type, action.type)
        if not _.isFunction(type_func) # _callable(type_func)
            throw new Error("#{type_func} is not callable")

        if @_check_argument?
            @_check_argument(action)
        ###
        # raise an error if the metavar does not match the type
        # replaced by above check_argument
        if @_get_formatter?
            try
                @_get_formatter()._format_args(action, null)
            catch error
                throw new Error("length of metavar tuple does not match nargs")
        ###
        return @_add_action(action)
  addArgument: (args, options) -> @add_argument(args..., options)

  add_argument_group: (options) ->
        group = new _ArgumentGroup(this, options)
        @_action_groups.push(group)
        return group
  addArgumentGroup: (options) -> @add_argument_group(options)

  add_mutually_exclusive_group: (options={}) ->
        group = new _MutuallyExclusiveGroup(this, options)
        @_mutually_exclusive_groups.push(group)
        return group
  addMutuallyExclusiveGroup: (options) -> @add_mutually_exclusive_group(options)

  _add_action: (action) ->
        # resolve any conflicts
        @_check_conflict(action)

        # add to actions list
        @_actions.push(action)
        action.container = this

        # index the action by any option strings it has
        for option_string in action.option_strings
            @_option_string_actions[option_string] = action

        # set the flag if any option strings look like negative numbers
        for option_string in action.option_strings
            if option_string.match(@_negative_number_matcher)
                if not _.any(@_hasNegativeNumberOptionals)
                    @_hasNegativeNumberOptionals.push(true)

        # return the created action
        return action

  _remove_action: (action) ->
        # @_actions.remove(action)
        i = @_actions.indexOf(action)
        if i>=0
          @_actions.splice(i,1)


  _add_container_actions: (container) =>
        # collect groups by titles
        title_group_map = {}
        #DEBUG @
        for group in @_action_groups
            if group.title of title_group_map
                msg = "cannot merge actions - two groups are named #{group.title}"
                throw new Error(msg)
            title_group_map[group.title] = group

        # map each action to its group
        group_map = {}
        actionHash = (action) ->
            return action.getName()
        for group in container._action_groups

            # if a group with the title exists, use that, otherwise
            # create a new group matching the container's group
            if group.title not of title_group_map
                title_group_map[group.title] = @add_argument_group({
                    title:group.title,
                    description:group.description,
                    conflict_handler:group.conflict_handler})

            # map the actions to their new group
            for action in group._group_actions
                group_map[actionHash(action)] = title_group_map[group.title]

        # TODO - fix 'get' below; is group_map[action] right?
        # it is in dev

        # add container's mutually exclusive groups
        # NOTE: if add_mutually_exclusive_group ever gains title= and
        # description= then this code will need to be expanded as above
        for group in container._mutually_exclusive_groups
            mutex_group = @add_mutually_exclusive_group(
                {required:group.required})

            # map the actions to their new mutex group
            for action in group._group_actions
                group_map[actionHash(action)] = mutex_group

        # add all actions to this container or their group
        for action in container._actions
            # group_map.get(action, self)._add_action(action)
            ctr = group_map[action.getName()] ? this
            ctr._add_action(action)

  _get_positional_options:  (dest, options) ->
        # make sure required is not specified
        if 'required' of options
            msg = "'required' is an invalid argument for positionals"
            throw new TypeError(msg)

        if _.isArray(dest)
          if dest.length==0
            dest = null
          else
            dest = dest[0]

        #DEBUG 'in pos', dest, options

        # mark positional arguments as required if at least one is
        # always required
        ###
        if options.get('nargs') not in [$$.OPTIONAL, $$.ZERO_OR_MORE]
            options.required = True
        if options.get('nargs') == $$.ZERO_OR_MORE and 'defaultValue' not of options
            options.required = True
        ###

        if options.nargs not in [$$.OPTIONAL, $$.ZERO_OR_MORE]
          options.required = true
        else if options.nargs == $$.ZERO_OR_MORE and not options.defaultValue?
          options.required = true
        else
          options.required = false

        # return the keyword arguments with no option strings
        # return dict(options, dest=dest, option_strings=[])
        result = _.clone(options)
        if dest?
          result.dest = dest
        result.option_strings = []
        return result

  _get_optional_options: (args, options) ->
        # determine short and long option strings
        option_strings = []
        long_option_strings = []
        for option_string in args
            # error on strings that don't start with an appropriate prefix
            firstchar = option_string[0]
            secondchar = option_string[1]
            if firstchar not in @prefix_chars
                msg = "invalid option string #{option_string}: " +
                      "must start with a character #{@prefix_chars}"
                throw new Error(msg)

            # strings starting with two prefix characters are long options
            option_strings.push(option_string)
            if firstchar in @prefix_chars
                if option_string.length > 1
                    if secondchar in @prefix_chars
                        long_option_strings.push(option_string)

        # infer destination, '--foo-bar' -> 'foo_bar' and '-x' -> 'x'
        # dest = options.pop('dest', null)
        if options.dest?
          dest = options.dest
          delete options.dest
        else
          dest = null
        if dest is null
            if long_option_strings.length>0
                dest_option_string = long_option_strings[0]
            else
                dest_option_string = option_strings[0]
            dest = _.str.lstrip(dest_option_string, @prefix_chars)
            if not dest
                msg = "dest= is required for options like #{option_string}"
                throw new Error(msg)
            # dest = dest.replace('-', '_')
            dest = dest.replace(/-/g, '_');

        # return the updated keyword arguments
        # return dict(options, dest=dest, option_strings=option_strings)
        result = _.clone(options)
        result.dest = dest
        result.option_strings = option_strings
        return result

  _pop_action_class: (options, defaultValue=null) ->
        # action = options.pop('action', defaultValue)
        if options.action?
          action = options.action
          delete options.action
        else
          action = defaultValue
        return @_registry_get('action', action, action)

  _get_handler: () ->
        # determine function from conflict handler string
        handler_func_name = "_handle_conflict_#{@conflict_handler}"
        func = @[handler_func_name]

        if func?
          return func
        else
            msg = "invalid conflict resolution value: #{@conflict_handler}"
            throw new Error(msg)

  _check_conflict: (action) ->
        # find all options that conflict with this option
        confl_optionals = []
        for option_string in action.option_strings
            if option_string of @_option_string_actions
                confl_optional = @_option_string_actions[option_string]
                confl_optionals.push([option_string, confl_optional])

        # resolve any conflicts
        if confl_optionals.length>0
            conflict_handler = @_get_handler()
            conflict_handler(action, confl_optionals)

    _handle_conflict_error: (action, conflicting_actions) ->
        conflict_string = (tpl[0] for tpl in conflicting_actions).join(', ')
        message = "Conflicting option string(s): "+ conflict_string
        # throw new Error(action.getName() + message )
        throw new ArgumentError(action, message)

    _handle_conflict_resolve: (action, conflicting_actions) =>
        # remove all conflicting options
        for [option_string, action] in conflicting_actions
          # remove the conflicting option
          i = action.option_strings.indexOf(option_string)
          if i>=0
            action.option_strings.splice(i,1)
            # array delete is wrong here
          delete @_option_string_actions[option_string]
          # if the option now has no option string, remove it from the
          # container holding it
          if action.option_strings.length==0
            action.container._remove_action(action)

class _ArgumentGroup extends _ActionsContainer

    constructor: (container, options={}) ->
        # def __init__(self, container, title=None, description=None, **kwargs):
        # add any missing keyword arguments by checking the container
        options.prefix_chars = options.prefixChars ? container.prefix_chars
        options.argument_default = options.argument_default ? container.argument_default
        options.conflict_handler = options.conflict_handler ? container.conflict_handler


        # super_init = super(_ArgumentGroup, self).__init__
        # _ActionsContainer.call(this, options)
        # super_init(description=description, **kwargs)
        super(options)
        # group attributes
        @title = options.title
        @_group_actions = []
        # share most attributes with the container
        @_registries = container._registries
        @_actions = container._actions
        @_option_string_actions = container._option_string_actions
        @_defaults = container._defaults
        @_hasNegativeNumberOptionals = container._hasNegativeNumberOptionals
        @_mutually_exclusive_groups = container._mutually_exclusive_groups
        @_check_argument = container._check_argument
        @_container = container;

    _add_action: (action) ->
        #action = super(_ArgumentGroup, self)._add_action(action)
        action = super(action)
        @_group_actions.push(action)
        return action

    _remove_action: (action) ->
        #super(_ArgumentGroup, self)._remove_action(action)
        super(action)
        # delete @_group_actions[action] # TODO, [].remove not valid JS
        i = @_group_actions.indexOf(action)
        if i>=0
          @_group_actions.splice(i,1)


class _MutuallyExclusiveGroup extends _ArgumentGroup

    constructor: (container, options) ->
        # def __init__(self, container, required=False):
        # _ArgumentGroup.call(this, acoptions)
        super(container, options)
        # super(_MutuallyExclusiveGroup, self).__init__(container)
        @required = options.required
        # @_container = container

    _add_action: (action) ->
        if action.required
            msg = 'mutually exclusive arguments must be optional'
            throw new Error(msg)
        # action = super(action)
        # super doesn't work here because an exclusive group is simply a
        # variation on group; an action can be in both an xgroup and a group
        # like optionals; where as an action cannot be in 2 regular groups
        action = @_container._add_action(action)
        @_group_actions.push(action)
        return action

    _remove_action: (action) ->
        # super(action)
        @_container._remove_action(action)
        @_group_actions.remove(action) # TODO

###
 * class ArgumentParser
 *
 * Object for parsing command line strings into js objects.
 *
 * Inherited from [[ActionContainer]]
###

# Zip together multiple lists into a single array -- elements that share
# an index go together.
_.zipShortest = ->
  length =  _.min(_.pluck(arguments, 'length'))
  results = new Array(length)
  for i in [0...length]
    results[i] = _.pluck(arguments, String(i))
  results

class Namespace
  isset: (key) -> @[key]?
  get: (key, defaultValue) -> @[key] ? defaultValue
  set: (key, value) -> @[key] = value
  repr: () -> 'Namespace'+ util.inspect(@)


class ArgumentParser extends _ActionsContainer
    constructor: (options={}) ->
        @prog=options.prog ? path.basename(process.argv[1])
        @usage=options.usage ? null
        @epilog=options.epilog ? null
        @parents=options.parents ? []
        @formatter_class=options.formatter_class ? options.formatterClass ? HelpFormatter
        @fromfile_prefix_chars = options.fromfile_prefix_chars ? options.fromfilePrefixChars ? null
        @add_help = options.addHelp ? options.add_help ? true
        @debug = options.debug ? false

        @description=options.description ? null
        @prefix_chars=options.prefixChars ? options.prefix_chars ? '-'
        @argument_default=options.argumentDefault ? options.argument_default ? null
        @conflict_handler=options.conflict_handler ? options.conflictHandler ? 'error'

        # re python issue9334
        @args_default_to_positional = options.args_default_to_positional ? false

        acoptions = {
            description: @description,
            prefixChars: @prefix_chars,
            argument_default: @argument_default,
            conflict_handler: @conflict_handler}
        _ActionsContainer.call(this, acoptions)
        @_positionals = @add_argument_group({title: 'Positional arguments'})
        @_optionals = @add_argument_group({title: 'Optional arguments'})
        @_subparsers = null

        # type can be any fn that takes string and returns a value, or throws an error
        # Python int, float, etc work
        # JS parseInt, parseFloat return NaN instead of an error
        # type can be user supplied, but these are a few convenience types

        # register types
        @register('type', null, (o)->o)  # identity
        @register('type', 'auto', (o)->o)
        @register('type', 'int', (x) ->
            result = parseInt(x, 10)
            if isNaN(result)
                throw new TypeError("#{x} is not a valid integer.")
            return result)
        @register('type', 'float', (x) ->
            result = parseFloat(x, 10)
            if isNaN(result)
                throw new TypeError("#{x} is not a valid float.")
            return result)
        @register('type', 'string', (x) ->
            return '' + x)

        # add help and version arguments if necessary
        # (using explicit default to override global argument_default)
        default_prefix = if '-' in @prefix_chars then '-' else @prefix_chars[0]
        if @add_help
            @addArgument([default_prefix+'h', default_prefix+default_prefix+'help'],\
                {action:'help',
                defaultValue:$$.SUPPRESS, # of default of the action already
                help:'Show this help message and exit'
            })

        if @version
            @addArgument([default_prefix+'v', default_prefix+default_prefix+'version'],\
                {action:'version', default:$$.SUPPRESS, \
                version:@version,\
                help:"show program's version number and exit"
            })

        for parent in @parents
            @_add_container_actions(parent)
            if parent._defaults?
                for defaultKey of parent._defaults
                    if parent._defaults[defaultKey]? # has defaultKey # own?
                        @_defaults[defaultKey] = parent._defaults[defaultKey]
        @

    # =======================
    # Pretty toString method
    # =======================

    repr: () ->
        # compact display of the parser's key parameters
        # list from py, could add others
        names = [
            'prog',
            'usage',
            'description',
            'formatter_class',
            'conflict_handler',
            'add_help',
            'debug',
        ]
        return __repr__(@, names)

    toString: @::repr

    print_actions: () ->
        # compact display of the actions
        return (a+"" for a in @._actions).join('\n')

    # ==================================
    # Optional/Positional adding methods
    # ==================================

    add_subparsers: (options={}) ->
        if @_subparsers?
            @error('cannot have multiple subparser arguments')
        options.defaultValue = null
        options.debug = @debug
        options.option_strings = []
        options.parserClass = (options.parserClass || ArgumentParser)

        # add the parser class to the arguments if it's not present
        #?options.setdefault('parser_class', type(self))

        if options.title? or options.description?
            title = options.title ?  'subcommands'
            description = options.description ? null
            delete options.title
            delete options.description
            @_subparsers = @add_argument_group({title: title, description: description})
        else
            @_subparsers = @_positionals

        # prog defaults to the usage message of this parser, skipping
        # optional arguments and with no "usage:" prefix
        if not options.prog?
            formatter = @_get_formatter()
            positionals = @_get_positional_actions()
            groups = @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
            formatter.addUsage(@usage, positionals, groups, '')
            options.prog = _.str.strip(formatter.formatHelp())

        # create the parsers action and add it to the positionals list
        # ParsersClass = (@_popActionClass ? @_pop_action_class)(options, 'parsers')
        if @_popActionClass?
          ParsersClass = @_popActionClass(options, 'parsers')
        else
          ParsersClass = @_pop_action_class(options, 'parsers')

        action = new ParsersClass(options)
        #DEBUG action.nargs
        #DEBUG @_subparsers.__super__
        if @_subparsers._add_action?
          @_subparsers._add_action(action)
        else
          @_subparsers._add_action(action)

        # return the created parsers action
        return action

    _add_action: (action) ->
        if action.isOptional()
            assert(action.option_strings)
            @_optionals._add_action(action)
        else
            # DEBUG 'pos action:',action.dest
            @_positionals._add_action(action)
        return action

    _get_optional_actions: () ->
        return (action for action in @_actions when action.isOptional())

    _get_positional_actions: () ->
        return (action for action in @_actions when action.isPositional())

    _check_argument: (action) =>
        # check action arguments
        # focus on the arguments that the parent container does not know about
        # check nargs and metavar tuple
        # use 'bind' so a group can use its container's method
        try
            @_get_formatter()._format_args(action, null)
        catch error
            throw new ArgumentError(action, error.message)

    # =====================================
    # Command line argument parsing methods
    # =====================================
    parse_args: (args=null, namespace=null) ->
        [args, argv] = @parse_known_args(args, namespace)
        if argv.length>0
            msg = "unrecognized arguments: #{argv.join(' ')}"
            @error(msg)
        return args

    parse_known_args: (args=null, namespace=null) ->
        # args default to system args
        args = args || process.argv[2...]

        # default Namespace built from parser defaults
        namespace = namespace ? new Namespace()
        #DEBUG "parse_known_args: '#{@prog}'"
        #DEBUG 'namespace:', namespace.repr()

        # add any action defaults that aren't present
        for action in @_actions
            #DEBUG 'action default: ',action.dest,action.defaultValue
            if action.dest != $$.SUPPRESS
                if not namespace.isset(action.dest)
                    if action.defaultValue != $$.SUPPRESS
                        _default = action.defaultValue
                        #if _.isString(_default)
                        #    _default = @_get_value(action, _default)
                        # correction in python to prevent calling action
                        # on default if not needed
                        # rev/62b5667ef2f4
                        namespace.set(action.dest, _default)

        #DEBUG 'with defaults:',namespace.repr()
        # add any parser defaults that aren't present
        for dest of @_defaults
            if not namespace.isset(dest)
                namespace.set(dest, @_defaults[dest])

        # parse the arguments and exit if there are any errors
        try # if true
            #DEBUG 'initial args', args, namespace.repr()
            [namespace, args] = @_parse_known_args(args, namespace)
            if namespace.isset($$._UNRECOGNIZED_ARGS_ATTR)
                args.push(namespace.get($$._UNRECOGNIZED_ARGS_ATTR))
                delete namespace[$$._UNRECOGNIZED_ARGS_ATTR]
            return [namespace, args]

        catch error
            if error instanceof ArgumentError
                #DEBUG 'pna: passing ArgumentError to @error'
                @error(error)
            else
                #DEBUG 'pna: rethrowing error'
                throw error

        argv = []
        return [args, argv]

    _parse_known_args: (arg_strings, namespace) ->
        # replace arg strings that are file references
        if @fromfile_prefix_chars?
            arg_strings = @_read_args_from_files1(arg_strings)
            #DEBUG 'from files', arg_strings

        # map all mutually exclusive arguments to the other arguments
        # they can't occur with
        actionConflicts = {}
        actionHash = (action) ->
            return action.getName()
        mxgroups = @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
        for mutex_group in mxgroups
            group_actions = mutex_group._groupActions ? mutex_group._group_actions
            for mutex_action, i in group_actions
                key =  actionHash(mutex_action)
                if not actionConflicts[key]?
                    actionConflicts[key] = []
                conflicts = actionConflicts[key]
                conflicts.push(group_actions[...i]...)
                conflicts.push(group_actions[i + 1..]...)

        # find all option indices, and determine the arg_string_pattern
        # which has an 'O' if there is an option at an index,
        # an 'A' if there is an argument, or a '-' if there is a '--'
        option_string_indices = {}
        arg_string_pattern_parts = []
        for arg_string, i in arg_strings
            # Py uses iter() to iter over the rest after --
            # all args after -- are non-options
            if arg_string == '--'
                arg_string_pattern_parts.push('-')
                # for arg_string in arg_strings_iter:
                for arg_string in arg_strings[(i+1)...]
                    # iterate over the rest of arg_strings
                    arg_string_pattern_parts.push('A')
                break
            # otherwise, add the arg to the arg strings
            # and note the index if it was an option
            else
                option_tuple = @_parse_optional(arg_string)
                if option_tuple is null
                    pattern = 'A'
                else
                    option_string_indices[i] = option_tuple
                    pattern = 'O'
                arg_string_pattern_parts.push(pattern)
        # join the pieces together to form the pattern
        arg_string_pattern = arg_string_pattern_parts.join('')
        DEBUG 'pattern:',arg_string_pattern, _.keys(option_string_indices)
        assert((x for x in arg_string_pattern when x=='-').length<2)
        # converts arg strings to the appropriate and then takes the action
        seen_actions = []  # py uses set()
        seen_non_default_actions = []

        take_action = (action, argument_strings, option_string=null) =>
            seen_actions.push(action)
            argument_values = @_get_values(action, argument_strings)
            #DEBUG 'take_action, _get values:', argument_strings, argument_values
            # error if this argument is not allowed with other previously
            # seen arguments, assuming that actions that use the default
            # value don't really count as "present"
            if argument_values != action.defaultValue
                seen_non_default_actions.push(action)
                key = actionHash(action)
                if actionConflicts[key]?
                    for actionConflict in actionConflicts[key]
                        if actionConflict in seen_non_default_actions
                            msg = "not allowed with argument #{actionConflict.getName()}"
                            # @error(action.getName() + ': ' + msg)
                            throw new ArgumentError(action, msg)

            # take the action if we didn't receive a SUPPRESS value
            # (e.g. from a default)
            if argument_values != $$.SUPPRESS
                action.call(@, namespace, argument_values, option_string)
                #DEBUG 'taken_action:',action.dest,namespace.repr()
                #DEBUG '    ', argument_values, option_string

        consume_optional = (start_index, no_action=false, penult=-1) =>
            # get the optional identified at this index
            option_tuple = option_string_indices[start_index]
            [action, option_string, explicit_arg] = option_tuple
            # if action? then DEBUG 'option tuple:', [action.dest, option_string, explicit_arg]
            # identify additional optionals in the same arg string
            # (e.g. -xyz is the same as -x -y -z if no args are required)
            match_argument = @_match_argument
            action_tuples = []
            while true

                # if we found no optional action, skip it
                if action is null
                    extras.push(arg_strings[start_index])
                    return start_index + 1

                # if there is an explicit argument, try to match the
                # optional's string arguments to only this
                if explicit_arg?
                    arg_count = match_argument(action, 'A')

                    # if the action is a single-dash option and takes no
                    # arguments, try to parse more single-dash options out
                    # of the tail of the option string
                    chars = @prefix_chars
                    if arg_count == 0 and option_string[1] not in chars
                        #DEBUG "explicit arg: '#{explicit_arg}', '#{option_string}'"
                        action_tuples.push([action, [], option_string])
                        option_string = option_string[0] + explicit_arg[0]
                        new_explicit_arg = explicit_arg[1...] || null
                        optionals_map = @_option_string_actions
                        if optionals_map[option_string]?
                            action = optionals_map[option_string]
                            explicit_arg = new_explicit_arg
                        else
                            if false
                                msg = "ignored explicit argument #{explicit_arg}"
                                #@error(action.getName() + ': ' + msg)
                                throw new ArgumentError(action, msg)
                            else
                                # alt handling of unknown explicit_arg
                                # http://bugs.python.org/issue16142
                                extras.push(option_string)
                                explicit_arg = new_explicit_arg

                    # if the action expect exactly one argument, we've
                    # successfully matched the option; exit the loop
                    else if arg_count == 1
                        stop = start_index + 1
                        args = [explicit_arg]
                        action_tuples.push([action, args, option_string])
                        break

                    # error if a double-dash option did not use the
                    # explicit argument
                    else
                        msg = "ignored explicit argument #{explicit_arg}"
                        @error(action.getName() + ': ' + msg)

                # if there is no explicit argument, try to match the
                # optional's string arguments with the following strings
                # if successful, exit the loop
                else
                    #DEBUG 'consume optional, push action tuple'
                    start = start_index + 1
                    selected_patterns = arg_string_pattern[start...]
                    DEBUG '    ', start, arg_string_pattern, action.dest
                    arg_count = match_argument(action, selected_patterns)

                    # if action takes a variable number of arguments, see
                    # if it needs to share any with remaining positionals
                    DEBUG action.dest, arg_count, selected_patterns, _.str.count(selected_patterns, 'O')
                    if @_is_nargs_variable(action)
                        # variable range of args for this action
                        slots = @_match_arguments_partial([action].concat(positionals), selected_patterns)
                        DEBUG '    opt+pos slots',slots
                        shared_count = slots[0]
                    else
                        shared_count = null

                    # penult controls whether this uses this shared_count
                    # the last optional (ultimate) usually can share
                    # but earlier ones (penult) might also
                    if shared_count? and _.str.count(selected_patterns,'O')<=penult
                        DEBUG '    COUNTS:',arg_count, shared_count
                        if arg_count>shared_count
                            DEBUG "    changing arg_count #{arg_count} to shared_count #{shared_count}"
                            arg_count = shared_count

                    stop = start + arg_count
                    args = arg_strings[start...stop]
                    action_tuples.push([action, args, option_string])
                    break

            # add the Optional to the list and return the index at which
            # the Optional's string args stopped
            # assert action_tuples
            #for [action, args, option_string] in action_tuples
            #    take_action(action, args, option_string)
            if no_action
                return stop
            take_action(tuple...) for tuple in action_tuples
            return stop

        # the list of Positionals left to be parsed; this is modified
        # by consume_positionals()
        positionals = @_get_positional_actions()

        # function to convert arg_strings into positional actions
        consume_positionals = (start_index, no_action=false) =>
            # match as many Positionals as possible
            match_partial = @_match_arguments_partial
            selected_pattern = arg_string_pattern[start_index...]
            #DEBUG 'cp', selected_pattern
            arg_counts = match_partial(positionals, selected_pattern)

            # issue 14191, intermixing optionals and positionals
            # partial fix here, preventing a '*' from being consumed by 1st
            # positional block of arguments

            # lop off the last match if count is 0 and there's an 'O' in remaining pattern
            # e.g.  'AOAA',[1,0],[null,'*']
            if 'O' in arg_string_pattern[start_index..]
                # if there is an optional after this, remove
                # 'empty' positionals from the current match
                while arg_counts.length>1 and arg_counts[arg_counts.length-1]==0
                    DEBUG('mixed o&p:', arg_counts, arg_string_pattern)
                    arg_counts.pop()

            # slice off the appropriate arg strings for each Positional
            # and add the Positional and its args to the list
            DEBUG 'arg count:',arg_counts
            # py zip stops w/ shortest. _ zip goes with the longest
            # in subparser case there is a subcommand name
            # js version tests for arg_count.length
            #if arg_counts.length
            for [action, arg_count] in _.zipShortest(positionals, arg_counts)
                args = arg_strings[start_index...start_index + arg_count]
                if action.nargs not in [$$.PARSER, $$.REMAINDER]
                    pats = arg_string_pattern[start_index...start_index + arg_count]
                    DEBUG 'take action:',action.dest, args, pats
                    # remove a '--' corresponding to a '-' in pats
                    ii = pats.indexOf('-')
                    if ii>-1
                        assert(args[ii]=='--')
                        args[ii..ii] = []
                        DEBUG 'take action:',action.dest, args
                start_index += arg_count
                #if not no_action
                take_action(action, args)

            # slice off the Positionals that we just parsed and return the
            # index at which the Positionals' string args stopped
            positionals[..] = positionals[arg_counts.length...]
            return start_index

        consume_loop = (no_action=false, penult=-1) =>
            # consume Positionals and Optionals alternately, until we have
            # passed the last option string
            start_index = 0
            index_keys = (+x for x in _.keys(option_string_indices))
            if index_keys.length>0
                max_option_string_index = Math.max(index_keys...)
            else
                max_option_string_index = -1
            foo = (start_index) ->
                (index for index in index_keys when index >= start_index)
            while start_index <= max_option_string_index
                # consume any Positionals preceding the next option
                #next_option_string_index = Math.min((index for index in index_keys when index >= start_index)...)
                next_option_string_index = Math.min(foo(start_index)...)
                if start_index != next_option_string_index
                    positionals_end_index = consume_positionals(start_index, no_action)

                    # only try to parse the next optional if we didn't consume
                    # the option string during the positionals parsing
                    if positionals_end_index > start_index
                        start_index = positionals_end_index
                        continue
                    else
                        start_index = positionals_end_index

                # if we consumed all the positionals we could and we're not
                # at the index of an option string, there were extra arguments
                if start_index not in index_keys
                    strings = arg_strings[start_index...next_option_string_index]
                    extras.push(strings...)
                    start_index = next_option_string_index

                # consume the next optional and any arguments for it
                start_index = consume_optional(start_index, no_action, penult)

            # consume any positionals following the last Optional
            stop_index = consume_positionals(start_index, no_action)

            # if we didn't consume all the argument strings, there were extras
            extras.push(arg_strings[stop_index..]...)
            return extras

        penult = _.str.count(arg_string_pattern, 'O') # # of 'O' in 'AOAA' patttern
        opt_actions = [v[0] for k,v of option_string_indices when v[0]]
        _cnt = 0
        if @_is_nargs_variable(opt_actions) and positionals and penult>1
            # if there are positionals and one or more 'variable' optionals
            # do test loops to see when to start sharing
            # test loops
            for ii in [0...penult]
                extras = []
                positionals = @_get_positional_actions()
                extras = consume_loop(true, ii)
                _cnt += 1
                if positionals.length==0
                    break

        else
            # don't need a test run; but do use action+positionals parsing
            ii = 0
        # now the real parsing loop, that takes action
        extras = []
        positionals = @_get_positional_actions()
        extras = consume_loop(false, ii)

        # if we didn't use all the Positional objects, there were too few
        # arg strings supplied.
        # removed in latest py: see http://bugs.python.org/issue9253
        #if positionals.length>0
        #    @error('too few arguments')

        # make sure all required actions were present
        required_actions = []
        for action in @_actions
            ###
            if action.required
                if action not in seen_actions
                    @error("argument #{action.getName()} is required")
            ###
            #DEBUG action.dest, _.pluck(seen_actions,'dest')
            if action not in seen_actions
                if action.required
                    required_actions.push(action.getName())
                    #@error("argument #{action.getName()} is required")
                    ## modification in dev python that can show multiple missing actions
                else
                    # Convert action default now instead of doing it before
                    # parsing arguments to avoid calling convert functions
                    # twice (which may fail) if the argument was given, but
                    # only if it was defined already in the namespace
                    # http://hg.python.org/cpython/rev/62b5667ef2f4
                    # python checks defaultValue is not None
                    # but here the isString test takes care of that
                    if _.isString(action.defaultValue) and \
                            namespace[action.dest]? \
                            and action.defaultValue == namespace[action.dest]
                        namespace[action.dest] = @_get_value(action, action.defaultValue)

        if required_actions.length>0
            # py had problems with action names that are None
            # also subparsers didn't return a meaningful name
            required_actions = required_actions.join(',')
            msg = "the following argument(s) are required: #{required_actions}"
            @error(msg)

        # make sure all required groups had one option present
        action_used = false
        for group in @_mutuallyExclusiveGroups ? @_mutually_exclusive_groups
            if group.required
                #DEBUG 'group required'
                gactions = group._groupActions ? group._group_actions
                for action in gactions
                    if action in seen_non_default_actions
                        action_used = true
                        break

                # if no actions were used, report the error
                if not action_used
                    #DEBUG 'not action used'
                    names = (action.getName() for action in gactions \
                        when action.help != $$.SUPPRESS)
                    msg = "one of the arguments #{names.join(' ')} is required"
                    @error(msg)

        #DEBUG 'known:',[namespace.repr(), extras]
        return [namespace, extras]

    _read_args_from_files: (arg_strings) ->
        # expand arguments referencing files
        fs = require('fs')
        new_arg_strings = []
        for arg_string in arg_strings
            # for regular arguments, just add them back into the list
            firstchar = arg_string[0]
            if firstchar not in @fromfile_prefix_chars
                new_arg_strings.push(arg_string)
            # replace arguments referencing files with the file content
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  content = fs.readFileSync(filename, 'utf8')
                  content = content.trim().split('\n')
                  #DEBUG filename, content
                  for arg_line in content
                    for arg in @convert_arg_line_to_args(arg_line)
                      argstrs.push(arg)
                    argstrs = @_read_args_from_files(argstrs)
                  new_arg_strings.push(argstrs...)
                catch error
                  #DEBUG error.message
                  @error(error.message)
        return new_arg_strings

    _read_args_from_files1: (arg_strings) =>
        ### expand arguments referencing files
        adding ,@ context to forEach takes care of binding problems
        ###
        prefix_chars = @fromfile_prefix_chars
        convert_line = @convert_arg_line_to_args
        read_args = @_read_args_from_files
        #console.log prefix_chars, convert_line, read_args
        fs = require('fs')
        new_arg_strings = []
        arg_strings.forEach( (arg_string) ->
            ### for regular arguments, just add them back into the list ###
            if @fromfile_prefix_chars.indexOf(arg_string[0])<0
                new_arg_strings.push(arg_string)
                ### replace arguments referencing files with the file content ###
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  content = fs.readFileSync(filename, 'utf8')
                  content = content.trim().split('\n')
                  #DEBUG filename, content
                  content.forEach((arg_line) ->
                    @convert_arg_line_to_args(arg_line).forEach( (arg) ->
                      argstrs.push(arg)
                    )
                    argstrs = @_read_args_from_files1(argstrs) # recursive call
                  , @)
                  new_arg_strings.push(argstrs...)
                catch error
                  #DEBUG error.message
                  @error(error.message)
        , @)
        return new_arg_strings

    _read_args_from_files2: (arg_strings) =>
        ### expand arguments referencing files
        try to use the async form of readfile;
        it doesnt wait for the read to finish
        ###
        prefix_chars = @fromfile_prefix_chars
        convert_line = @convert_arg_line_to_args
        read_args = @_read_args_from_files
        #console.log prefix_chars, convert_line, read_args
        fs = require('fs')
        new_arg_strings = []
        arg_strings.forEach( (arg_string) =>
            ### for regular arguments, just add them back into the list ###
            if @fromfile_prefix_chars.indexOf(arg_string[0])<0
                new_arg_strings.push(arg_string)
                ### replace arguments referencing files with the file content ###
            else
                try
                  argstrs = []
                  filename = arg_string[1...] # w/o the prefix
                  fs.readFile(filename, 'utf8', (err, data) ->
                    if err
                      throw err
                    data = data.trim().split('\n')
                    #DEBUG filename, data
                    content.forEach((arg_line) ->
                      @convert_arg_line_to_args(arg_line).forEach( (arg) ->
                        argstrs.push(arg)
                      )
                      argstrs = @_read_args_from_files2(argstrs) # recursive call
                    )
                    new_arg_strings.push(argstrs...)
                  )
                  # shouldn't proceed until this read is done
                catch error
                  #DEBUG error.message
                  @error(error.message)
        )
        return new_arg_strings

    convert_arg_line_to_args: (arg_line) ->
        return [arg_line]

    _match_argument: (action, arg_strings_pattern) =>
        # match the pattern for this action to the arg strings
        nargs_pattern = @_get_nargs_pattern(action)
        nargs_pattern = '^' + nargs_pattern
        # py looks for match from start
        matches = arg_strings_pattern.match(nargs_pattern)
        #DEBUG 'match_argument', arg_strings_pattern, nargs_pattern, matches
        # raise an exception if we weren't able to find a match
        if not matches?
            args_errors = {null: 'expected one argument'}
            args_errors[$$.OPTIONAL] = 'expected at most one argument'
            args_errors[$$.ONE_OR_MORE] = 'expected at least one argument'
            msg = args_errors[action.nargs] ? "expected #{action.nargs} argument(s)"
            #msg = "#{msg} for action #{action.dest}"
            #@error(action.getName() + ': ' + msg)
            throw new ArgumentError(action, msg)

        # return the number of arguments matched
        return matches[1].length

    _match_arguments_partial: (actions, arg_strings_pattern) =>
        # progressively shorten the actions list by slicing off the
        # final actions until we find a match
        result = []
        #foo = get_nargs_pattern # @_get... not found
        #DEBUG 'actions:',(a.dest for a in actions)
        #DEBUG 'arg strings pattern:',arg_strings_pattern
        foo = @_get_nargs_pattern
        strlength = (string) -> string.length
        for i in [actions.length..0]
            actions_slice = actions[...i]
            pattern = actions_slice.map(foo).join('')
            m = arg_strings_pattern.match('^'+pattern)
            #DEBUG 'pattern:',pattern
            #DEBUG 'matches:',m
            if m?
                # m = m[1...]
                result.push(m[1...].map(strlength)...)
                break
        # return the list of arg string counts
        #DEBUG 'match arguments partial:',result
        return result

    _parse_optional: (arg_string) ->
        # if it's an empty string, it was meant to be a positional
        assert(@prefix_chars?)
        #DEBUG 'parse opt:',arg_string, @prefix_chars
        if not arg_string
            return null

        # if it doesn't start with a prefix, it was meant to be positional
        if not (arg_string[0] in @prefix_chars)
            return null

        # if the option string is present in the parser, return the action
        actions = @_option_string_actions
        if actions[arg_string]?
            action = actions[arg_string]
            return [action, arg_string, null]

        # if it's just a single character, it was meant to be positional
        if arg_string.length == 1
            return null

        # if the option string before the "=" is present, return the action
        if '=' in arg_string
            [option_string, explicit_arg] = arg_string.split('=')
            # may be a difference in 'split limit' between languages
            if actions[option_string]?
                action = actions[option_string]
                return [action, option_string, explicit_arg]

        # search through all possible prefixes of the option string
        # and all actions in the parser for possible interpretations
        option_tuples = @_get_option_tuples(arg_string)
        #DEBUG 'get opt tuples',arg_string,option_tuples.length
        # if multiple actions match, the option string was ambiguous
        if option_tuples.length > 1
            options = (option_string for [action, option_string, explicit_arg] in option_tuples)
            options = options.join(', ')
            tup = [arg_string, options]
            @error("ambiguous option: #{arg_string} could match #{options}")

        # if exactly one action matched, this segmentation is good,
        # so return the parsed action
        else if option_tuples.length == 1
            option_tuple = option_tuples[0]
            return option_tuple

        # option to make parser more like optparse
        if @args_default_to_positional
            return null

        # if it was not found as an option, but it looks like a negative
        # number, it was meant to be positional
        # unless there are negative-number-like options
        #if arg_string.match(@_negative_number_matcher)
        #    if not _.any(@_hasNegativeNumberOptionals)
        #        return null
        if not _.any(@_hasNegativeNumberOptionals) and not isNaN(arg_string)
            return null

        # if it contains a space, it was meant to be a positional
        if ' ' in arg_string
            return null

        # it was meant to be an optional but there is no such option
        # in this parser (though it might be a valid option in a subparser)
        return [null, arg_string, null]

    _get_option_tuples: (option_string) ->
        result = []

        # option strings starting with two prefix characters are only
        # split at the '='
        chars = @prefix_chars
        if option_string[0] in chars and option_string[1] in chars
            if '=' in option_string
                [option_prefix, explicit_arg] = option_string.split('=') # ,)
            else
                option_prefix = option_string
                explicit_arg = null
            actions = @_option_string_actions
            for option_string of actions
                if _.str.startsWith(option_string, option_prefix)
                    action = actions[option_string]
                    tup = [action, option_string, explicit_arg]
                    result.push(tup)

        # single character options can be concatenated with their arguments
        # but multiple character options always have to have their argument
        # separate
        else if option_string[0] in chars and option_string[1] not in chars
            option_prefix = option_string
            explicit_arg = null
            short_option_prefix = option_string[...2]
            short_explicit_arg = option_string[2..]

            actions = @_option_string_actions
            for option_string of actions
                if option_string == short_option_prefix
                    action = actions[option_string]
                    tup = [action, option_string, short_explicit_arg]
                    result.push(tup)
                else if _.str.startsWith(option_string,option_prefix)
                    action = actions[option_string]
                    tup = [action, option_string, explicit_arg]
                    result.push(tup)

        # shouldn't ever get here
        else
            #throw new Error("unexpected option string: #{option_string}")
            @error("unexpected option string: #{option_string}")

        # return the collected option tuples
        return result

    _get_nargs_pattern: (action) ->
        # in all examples below, we have to allow for '--' args
        # which are represented as '-' in the pattern
        nargs = action.nargs

        # the default (null) is assumed to be a single argument
        if nargs is null
            nargs_pattern = '(-*A-*)'

        # allow zero or one arguments
        else if nargs == $$.OPTIONAL
            nargs_pattern = '(-*A?-*)'

        # allow zero or more arguments
        else if nargs == $$.ZERO_OR_MORE
            nargs_pattern = '(-*[A-]*)'

        # allow one or more arguments
        else if nargs == $$.ONE_OR_MORE
            nargs_pattern = '(-*A[A-]*)'

        # allow any number of options or arguments
        else if nargs == $$.REMAINDER
            nargs_pattern = '([-AO]*)'

        # allow one argument followed by any number of options or arguments
        else if nargs == $$.PARSER
            nargs_pattern = '(-*A[-AO]*)'

        # all others should be integers
        else
            # nargs_pattern = '(-*%s-*)' % '-*'.join('A' * nargs)
            # nargs_pattern = "(-*#{('A' for i in [0...nargs]).join('')}-*)"
            # nargs_pattern = "(-*#{new Array(nargs+1).join('A')}-*)"
            nargs_pattern = "(-*#{_.str.repeat('-*A', nargs)}-*)"
        # if this is an optional action, -- is not allowed
        if action.isOptional()
            nargs_pattern = nargs_pattern.replace(/-\*/g, '')
            nargs_pattern = nargs_pattern.replace(/-/g, '')

        # return the pattern
        #DEBUG nargs, nargs_pattern
        return nargs_pattern

    _is_nargs_variable: (action) ->
        # return true if action, or any action in a list, takes variable number of args
        if _.isArray(action)
            return _.any(@_is_nargs_variable(a) for a in action)
        else
            if action.nargs in [$$.OPTIONAL, $$.ZERO_OR_MORE, $$.ONE_OR_MORE, $$.REMAINDER, $$.PARSER]
                return true
            #if _is_mnrep(action.nargs):
            #     return True
            return false

    # ========================
    # Value conversion methods
    # ========================
    _get_values: (action, arg_strings) ->
        # for everything but PARSER args, strip out '--'
        #DEBUG '_get_values:'
        if action.nargs not in [$$.PARSER, $$.REMAINDER]
            switch 'none'
                when 'all'
                    arg_strings = (s for s in arg_strings when s != '--')
                    # arg_strings = arg_strings.filter((s)->s != '--')
                when 'first'
                    # but python http://bugs.python.org/issue13922, removes just the first '--'
                    # not all, with guarded "arg_strings.remove('--')"
                    ii = arg_strings.indexOf('--')
                    if ii>=0 then console.log 'WITH -- ', arg_strings, action.dest
                    arg_strings = arg_strings.filter((s,i) -> i != ii)
                when 'none'
                    # do nothing
                else ''
        #DEBUG arg_strings.length, action.nargs, action.option_strings, action.defaultValue
        # optional argument produces a default when not present
        if arg_strings.length==0 and action.nargs == $$.OPTIONAL
            #DEBUG 'doing ?'
            if action.isOptional()
                value = action.constant
            else
                value = action.defaultValue
            if _.isString(value)
                value = @_get_value(action, value)
                @_check_value(action, value)

        # when nargs='*' on a positional, if there were no command-line
        # args, use the default if it is anything other than null
        else if (arg_strings.length==0 and action.nargs == $$.ZERO_OR_MORE and action.isPositional())
            #DEBUG 'doing *'
            if action.defaultValue?
                value = action.defaultValue
            else
                value = arg_strings
                #DEBUG value
            @_check_value(action, value)

        # single argument or optional argument produces a single value
        else if arg_strings.length == 1 and action.nargs in [null, $$.OPTIONAL]
            arg_string = arg_strings[0]
            value = @_get_value(action, arg_string)
            @_check_value(action, value)

        # REMAINDER arguments convert all values, checking null
        else if action.nargs == $$.REMAINDER
            value = (@_get_value(action, v) for v in arg_strings)

        # PARSER arguments convert all values, but check only the first
        else if action.nargs == $$.PARSER
            value = (@_get_value(action, v) for v in arg_strings)
            #DEBUG 'value from subparse', value
            @_check_value(action, value[0])

        # all other types of nargs produce a list
        else
            value = (@_get_value(action, v) for v in arg_strings)
            for v in value
                @_check_value(action, v)

        # return the converted value
        return value

    _get_value: (action, arg_string) ->
        type_func = @_registryGet('type', action.type, action.type)
        if not _.isFunction(type_func) # _callable(type_func):
            msg = "#{type_func} is not callable"
            @error(action.getName() + ': ' + msg)

        # convert the value to the appropriate type
        try
            result = type_func(arg_string)
        catch error
            if _.isString(action.type)
                name = action.type
            else
                name = action.type.name || action.type.displayName || '<function>'
            #msg = "Invalid #{name} value: #{arg_string}"
            #msg = action.getName() + ': ' + msg
            if error instanceof TypeError
              msg = "Invalid #{name} value: #{arg_string}"
              throw new ArgumentError(action, msg)
            else if error instanceof ArgumentTypeError
              #@error(msg + '\n' + error.message)
              throw new ArgumentError(action, error.message)
            else
              throw error
        return result

    _check_value: (action, value) ->
        # converted value must be one of the choices (if specified)
        # py test for 'value not in choices', which works for string, list, dict keys
        if action.choices?
          if _.isString(action.choices)
            choices = action.choices
            choices = choices.split(/\W+/) # 'white space' separators
            if choices.length==1
              choices = choices[0].split('') # individual letters
          else if _.isArray(action.choices)
            choices = action.choices
          else if _.isObject(action.choices)
            choices = _.keys(action.choices)
          if value not in choices
            msg = "invalid choice: #{value} (choose from #{choices})"
            # @error(action.getName() + ': ' + msg)
            throw new ArgumentError(action, msg)

    # ===============
    # Help formatting methods
    # ===============
    # adapt from javascript version

    format_usage: () ->
        formatter = @_get_formatter()
        formatter.addUsage(@usage, @_actions, @_mutually_exclusive_groups)
        return formatter.formatHelp()
    #formatUsage: () -> @format_usage()
    formatUsage: @::format_usage

    format_help: () ->
        formatter = @_get_formatter()
        # usage
        formatter.addUsage(@usage, @_actions, @_mutually_exclusive_groups)
        formatter.addText(@description)
        for actionGroup in (@_actionGroups ? @_action_groups)
            formatter.startSection(actionGroup.title)
            formatter.addText(actionGroup.description)
            formatter.addArguments(actionGroup._groupActions ? actionGroup._group_actions)
            formatter.endSection()
        formatter.addText(@epilog)
        return formatter.formatHelp()
    formatHelp: @::format_help

    _get_formatter: () ->
        FormatterClass = @formatter_class
        formatter = new FormatterClass({prog: @prog})

    printUsage: () ->
        @_printMessage(@format_usage())
    print_usage: @::printUsage
    printHelp: () ->
        @_printMessage(@format_help())
    print_help: @::printHelp

    #_printMessage: (message, stream) ->
    #    stream = stream ? process.stdout
    #    stream.write('' + message)


    # ===============
    # Exiting methods
    # ===============
    error: (err) ->
        assert(@debug?,'@ error in @error')
        if (err instanceof Error)
            if @debug
                #DEBUG '@error debug error'
                throw err
            message = err.message
        else
            message = err
        msg = "#{@prog}: error: #{message}#{$$.EOL}"
        if @debug
            #DEBUG '@error debug message'
            throw new Error(msg)
        @print_usage(process.stderr)
        return @exit(2,msg)

    exit: (status, message) ->
        if message?
            if status==0
                @_printMessage(message)
            else
                @_printMessage(message, process.stderr)
        if @debug
            # capture exit, such as from action help
            throw new Error('Exit captured')
        else
            process.exit(status)

    _printMessage: (message, stream=process.stdout) ->
        if message
            stream.write('' + message)

    # ===============
    # CamelCase Aliases
    # ===============
    # parseArgs: (args, namespace=null) -> @parse_args(args, namespace)
    parseArgs: @::parse_args
    # parseKnownArgs: (args, namespace=null) -> @parse_known_args(args, namespace)
    parseKnownArgs: @::parse_known_args
    # addSubparsers: (args) -> @add_subparsers(args)
    addSubparsers: @::add_subparsers
    if not @::add_argument?
      add_argument: (args..., options) ->
          # Python like arguments;
          # if last arg is a string, assume it is one of the 'args'
          # and options is an empty object
          if _.isString(options)
            # assume
            args.push(options)
            options = {}
          @addArgument(args, options)


###
values py exports
__all__ = [
    'ArgumentParser',
    'ArgumentError',
    'ArgumentTypeError',
    'FileType',
    'HelpFormatter',
    'ArgumentDefaultsHelpFormatter',
    'RawDescriptionHelpFormatter',
    'RawTextHelpFormatter',
    'Namespace',
    'Action',
    'ONE_OR_MORE',
    'OPTIONAL',
    'PARSER',
    'REMAINDER',
    'SUPPRESS',
    'ZERO_OR_MORE',
]
###
exports.ArgumentParser = ArgumentParser
exports.ArgumentError = ArgumentError
exports.ArgumentTypeError = ArgumentTypeError
exports.FileType = FileType
exports.fileType = fileType
exports.HelpFormatter = HelpFormatter
exports.ArgumentDefaultsHelpFormatter = ArgumentDefaultsHelpFormatter
exports.RawDescriptionHelpFormatter = RawDescriptionHelpFormatter
exports.RawTextHelpFormatter = RawTextHelpFormatter
exports.Namespace = Namespace
exports.Action = Action
exports.Const = $$



exports.newParser = (options={}) ->
  # convenience function
  if not options.debug then options.debug = true
  new ArgumentParser(options)

#============================================
# Testing - leave the ArgumentParser testing for now
#============================================
TEST = not module.parent?

if not module.parent? and (!process.argv[2]? or process.argv[2]!='nodebug')
    DEBUG = (arg...) ->
      arg.unshift('==> ')
      console.log arg...

    #DEBUG = (arg...) -> util.debug(arg)
    # how is util.debug diff from console.log?
else
    DEBUG = () ->

if TEST
  do() ->
    testparse = (args) ->
      console.log args
      if _.isString(args)
        args = args.split(' ')
      console.log (
        try
          parser.parseArgs(args)
        catch error
          console.log 'parseArgs error'
          error + ''
        )
    if 0
        parser = new ArgumentParser()
        #console.log 'obj:',util.inspect(parser,false,0)
        #console.log parser._action_groups[0]
        console.log parser.format_help()
        parser.add_subparsers({})
        console.log 'class:',
        console.log ArgumentParser
        console.log 'proto'
        console.log ArgumentParser.prototype
        console.log ArgumentParser.prototype.constructor.super_
        console.log ArgumentParser.prototype.constructor.__super__
        console.log '====================================='
        console.log parser.formatHelp()

    if 1
        parentParser = new ArgumentParser({add_help: false, description: 'parent'})
        parentParser.addArgument(['--x'])
        parentParser._defaults = {x:true} # test the propagation to child

        childParser = new ArgumentParser({description:'child',parents:[parentParser]})
        childParser.addArgument(['--y'])
        childParser.addArgument(['xxx'])
        console.log childParser.formatHelp()
        if 1
            console.log 'parent:'
            console.log parentParser+"" # ,util.inspect(parentParser,false,0)
            console.log 'child:'
            console.log childParser+"" # ,util.inspect(childParser,false,0)
            console.log "child actions:\n", childParser.print_actions()
            console.log 'child optional actions: ',(action.dest for action in     childParser._optionals._group_actions)
            console.log 'child positional actions: ',(action.dest for action in   childParser._positionals._group_actions)

        console.log '====================================='
    if TEST and 1
        parser = new ArgumentParser({debug: true});
        #parser.add_argument('-x', {action:'storeTrue'})
        #parser.add_argument('foobar')
        subparsers = parser.addSubparsers({
            title: 'subcommands',
            dest: 'subcommand_name'
        });
        c1 = subparsers.addParser('c1', {aliases: ['co']});
        c1.addArgument([ '-f', '--foo' ], {});
        c1.addArgument([ '-b', '--bar' ], {});
        c2 = subparsers.addParser('c2', {});
        c2.addArgument([ '--baz' ], {});
        try
          Nsp = new Namespace()
          Nsp.set('dummy','foobar')
          args = parser.parse_args('c1 --foo 5'.split(' '), Nsp)
          args = parser.parseArgs('c1 --foo 5'.split(' '), Nsp);
          # args = parser.parseArgs('-x c2'.split(' '))
          console.log args
        catch error

        parser.printHelp()
        testparse(['-h'])
        testparse(['c1','-h'])
        testparse(['c2','-h'])
        console.log '====================================='
    if TEST and 1
        parser = new ArgumentParser({debug: true});
        parser.addArgument(['-1'], {dest: 'one'});
        parser.addArgument(['foo'], {nargs: '?'});
        # negative number options present, so -1 is an option
        testparse(['-h'])
        args = parser.parseArgs(['-1', 'X']);
        # Namespace(foo=None, one='X')
        assert.equal(args.one, 'X');
        # negative number options present, so -2 is an option
        testparse(['FOO'])
        testparse(['-z'])
        testparse(['-2'])

        console.log '====================================='
    if TEST and 0
      parser = new ArgumentParser({debug: true});
      parser.addArgument(['-x'],{type:'float'});
      parser.addArgument(['-3'],{type:'float', dest:'y'})
      parser.addArgument(['z'],{nargs:'*'})
      args = parser.parse_args(['-2'])
      console.log args

    if TEST and 1
      console.log '====================================='
      console.log 'should be ok with scientific notation'
      parser = new ArgumentParser({debug:true});
      parser.addArgument(['--xlim'], {nargs: 2, type: 'float'});
      testparse(['--xlim', '-.002', '1e4']);
      testparse(['--xlim', '-0.002', '1e4']);
      testparse(['--xlim', '2.e3', '-1e4'])
      testparse(['--xlim', '-2.12e3', '-1e4'])
      testparse(['--xlim', '-0xff', '0x123'])  # hex ok, -hex not

    if TEST and 1
        console.log '====================================='
        console.log 'option-like positionals not accepted'
        parser = new ArgumentParser({debug:true});
        parser.addArgument(['--onetwo'], {nargs: 2});
        testparse(['--onetwo', 'one', 'two']);
        testparse(['--onetwo', 'one', '-two'])
        testparse(['--onetwo', 'one', '--', '-two'])

        parser = new ArgumentParser({debug:true});
        parser.addArgument(['--one'],{nargs:1});
        parser.addArgument(['two'],{nargs:'?'})
        testparse(['--one', 'one', 'two']);
        testparse(['--one', 'one','--', '-two'])
        testparse(['--one=-one', '-two'])
        #parser._negative_number_matcher = /^-.+$/
        #testparse(['--one', '-one', '-two']);
        #testparse(['-two', '--one', '-one'])


        console.log '\nargs_default_to_positional:true'
        parser = new ArgumentParser({debug:true, args_default_to_positional:true});
        parser.addArgument(['--onetwo'], {nargs: 2});
        testparse(['--onetwo', 'one', 'two']);
        testparse(['--onetwo', 'one', '-two'])
        testparse(['--onetwo', 'one', '--', 'two'])

        parser = new ArgumentParser({debug:true, args_default_to_positional:true});
        parser.addArgument(['--one'],{nargs:1});
        parser.addArgument(['two'],{nargs:'?'})
        testparse(['--one', 'one', 'two']);
        testparse(['--one', 'one','--', '-two'])
        testparse(['--one=-one', '-two'])

        console.log parser+"\n"
        console.log parser.print_actions()
    if TEST and 1
        console.log '====================================='
        console.log 'test --'
        parser = exports.newParser()
        parser.add_argument('foo')
        parser.add_argument('bar',{nargs:'*'})
        testparse('1 2 3 4')
        # expect { foo: '1', bar: [ '2', '3', '4' ] }
        testparse('-- 1 2 3 4')
        testparse('1 -- 2 3 4')
        testparse('1 2 -- 3 4')
        testparse('-- 1 2 -- 3 4')
        testparse('1 -- -- 2 3 4')
        testparse('-- -- 1 -- 2 -- 3 4')

        parser = exports.newParser()
        parser.addArgument([ '-x' ], { nargs: '*' });
        parser.addArgument([ 'y' ], { nargs: '*' });

        args = parser.parseArgs([]);
        assert.deepEqual(args, { y: [], x: null });
        args = parser.parseArgs([ '-x' ]);
        assert.deepEqual(args, { y: [], x: [] });
        args = parser.parseArgs([ '-x', 'a' ]);
        assert.deepEqual(args, { y: [], x: [ 'a' ] });
        args = parser.parseArgs([ '-x', 'a', '--', 'b' ]);
        assert.deepEqual(args, { y: [ 'b' ], x: [ 'a' ] });
        # WITH ALT -- GETTING: {"x":["a","b"],"y":[]}
        # ie removing --, but classing A as positional
        # 'OAA' v 'OA-A'

    if TEST and 1
        console.log '====================================='
        console.log 'TestAddSubparsers'
        parser = exports.newParser()
        parser.add_argument('--foo', {action:'store_true', help:'foo help'})
        parser.add_argument('bar', {type:'float', help:'bar help'})
        subparsers = parser.add_subparsers({title:'commands',help:'command help'})
        parser2 = subparsers.add_parser('2')
        parser2.add_argument('-y', {choices:'123', help:'y help'})
        parser2.add_argument('z', {nargs:'*', help:'z help',type:'float'})
        testparse('0.25 --foo 2 -y 2 3e3 -1e1')
        testparse('0.25 --foo 2 -y 2 3e3 -- -1e1') # -- should operate at subparser level, to allow 'neg' arg
