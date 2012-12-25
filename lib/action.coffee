# ==============
# Action classes
# ==============

class Action(_AttributeHolder):
    """Information about how to convert command line strings to Python objects.

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

        - const -- The value to be produced if the option is specified and the
            option uses an action that takes no values.

        - default -- The value to be produced if the option is not specified.

        - type -- The type which the command-line arguments should be converted
            to, should be one of 'string', 'int', 'float', 'complex' or a
            callable object that accepts a single string argument. If None,
            'string' is assumed.

        - choices -- A container of values that should be allowed. If not None,
            after a command-line argument has been converted to the appropriate
            type, an exception will be raised if it is not a member of this
            collection.

        - required -- True if the action must always be specified at the
            command line. This is only meaningful for optional command-line
            arguments.

        - help -- The help string describing the argument.

        - metavar -- The name to be used for the option's argument with the
            help string. If None, the 'dest' value will be used as the name.
    """

    def __init__(self,
                 option_strings,
                 dest,
                 nargs=None,
                 const=None,
                 default=None,
                 type=None,
                 choices=None,
                 required=False,
                 help=None,
                 metavar=None):
        self.option_strings = option_strings
        self.dest = dest
        self.nargs = nargs
        self.const = const
        self.default = default
        self.type = type
        self.choices = choices
        self.required = required
        self.help = help
        self.metavar = metavar

    def _get_kwargs(self):
        names = [
            'option_strings',
            'dest',
            'nargs',
            'const',
            'default',
            'type',
            'choices',
            'help',
            'metavar',
        ]
        return [(name, getattr(self, name)) for name in names]

    def __call__(self, parser, namespace, values, option_string=None):
        raise NotImplementedError(_('.__call__() not defined'))


class _StoreAction(Action):

    def __init__(self,
                 option_strings,
                 dest,
                 nargs=None,
                 const=None,
                 default=None,
                 type=None,
                 choices=None,
                 required=False,
                 help=None,
                 metavar=None):
        if nargs == 0:
            raise ValueError('nargs for store actions must be > 0; if you '
                             'have nothing to store, actions such as store '
                             'true or store const may be more appropriate')
        if const is not None and nargs != OPTIONAL:
            raise ValueError('nargs must be %r to supply const' % OPTIONAL)
        super(_StoreAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=nargs,
            const=const,
            default=default,
            type=type,
            choices=choices,
            required=required,
            help=help,
            metavar=metavar)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values)


class _StoreConstAction(Action):

    def __init__(self,
                 option_strings,
                 dest,
                 const,
                 default=None,
                 required=False,
                 help=None,
                 metavar=None):
        super(_StoreConstAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=0,
            const=const,
            default=default,
            required=required,
            help=help)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, self.const)


class _StoreTrueAction(_StoreConstAction):

    def __init__(self,
                 option_strings,
                 dest,
                 default=False,
                 required=False,
                 help=None):
        super(_StoreTrueAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            const=True,
            default=default,
            required=required,
            help=help)


class _StoreFalseAction(_StoreConstAction):

    def __init__(self,
                 option_strings,
                 dest,
                 default=True,
                 required=False,
                 help=None):
        super(_StoreFalseAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            const=False,
            default=default,
            required=required,
            help=help)


class _AppendAction(Action):

    def __init__(self,
                 option_strings,
                 dest,
                 nargs=None,
                 const=None,
                 default=None,
                 type=None,
                 choices=None,
                 required=False,
                 help=None,
                 metavar=None):
        if nargs == 0:
            raise ValueError('nargs for append actions must be > 0; if arg '
                             'strings are not supplying the value to append, '
                             'the append const action may be more appropriate')
        if const is not None and nargs != OPTIONAL:
            raise ValueError('nargs must be %r to supply const' % OPTIONAL)
        super(_AppendAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=nargs,
            const=const,
            default=default,
            type=type,
            choices=choices,
            required=required,
            help=help,
            metavar=metavar)

    def __call__(self, parser, namespace, values, option_string=None):
        items = _copy.copy(_ensure_value(namespace, self.dest, []))
        items.append(values)
        setattr(namespace, self.dest, items)


class _AppendConstAction(Action):

    def __init__(self,
                 option_strings,
                 dest,
                 const,
                 default=None,
                 required=False,
                 help=None,
                 metavar=None):
        super(_AppendConstAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=0,
            const=const,
            default=default,
            required=required,
            help=help,
            metavar=metavar)

    def __call__(self, parser, namespace, values, option_string=None):
        items = _copy.copy(_ensure_value(namespace, self.dest, []))
        items.append(self.const)
        setattr(namespace, self.dest, items)


class _CountAction(Action):

    def __init__(self,
                 option_strings,
                 dest,
                 default=None,
                 required=False,
                 help=None):
        super(_CountAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=0,
            default=default,
            required=required,
            help=help)

    def __call__(self, parser, namespace, values, option_string=None):
        new_count = _ensure_value(namespace, self.dest, 0) + 1
        setattr(namespace, self.dest, new_count)


class _HelpAction(Action):

    def __init__(self,
                 option_strings,
                 dest=SUPPRESS,
                 default=SUPPRESS,
                 help=None):
        super(_HelpAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            default=default,
            nargs=0,
            help=help)

    def __call__(self, parser, namespace, values, option_string=None):
        parser.print_help()
        parser.exit()


class _VersionAction(Action):

    def __init__(self,
                 option_strings,
                 version=None,
                 dest=SUPPRESS,
                 default=SUPPRESS,
                 help="show program's version number and exit"):
        super(_VersionAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            default=default,
            nargs=0,
            help=help)
        self.version = version

    def __call__(self, parser, namespace, values, option_string=None):
        version = self.version
        if version is None:
            version = parser.version
        formatter = parser._get_formatter()
        formatter.add_text(version)
        parser.exit(message=formatter.format_help())


class _SubParsersAction(Action):

    class _ChoicesPseudoAction(Action):

        def __init__(self, name, help):
            sup = super(_SubParsersAction._ChoicesPseudoAction, self)
            sup.__init__(option_strings=[], dest=name, help=help)

    def __init__(self,
                 option_strings,
                 prog,
                 parser_class,
                 dest=SUPPRESS,
                 help=None,
                 metavar=None):

        self._prog_prefix = prog
        self._parser_class = parser_class
        self._name_parser_map = _collections.OrderedDict()
        self._choices_actions = []

        super(_SubParsersAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            nargs=PARSER,
            choices=self._name_parser_map,
            help=help,
            metavar=metavar)

    def add_parser(self, name, **kwargs):
        # set prog from the existing prefix
        if kwargs.get('prog') is None:
            kwargs['prog'] = '%s %s' % (self._prog_prefix, name)

        # create a pseudo-action to hold the choice help
        if 'help' in kwargs:
            help = kwargs.pop('help')
            choice_action = self._ChoicesPseudoAction(name, help)
            self._choices_actions.append(choice_action)

        # create the parser and add it to the map
        parser = self._parser_class(**kwargs)
        self._name_parser_map[name] = parser
        return parser

    def _get_subactions(self):
        return self._choices_actions

    def __call__(self, parser, namespace, values, option_string=None):
        parser_name = values[0]
        arg_strings = values[1:]

        # set the parser name if requested
        if self.dest is not SUPPRESS:
            setattr(namespace, self.dest, parser_name)

        # select the parser
        try:
            parser = self._name_parser_map[parser_name]
        except KeyError:
            tup = parser_name, ', '.join(self._name_parser_map)
            msg = _('unknown parser %r (choices: %s)') % tup
            raise ArgumentError(self, msg)

        # parse all the remaining options into the namespace
        # store any unrecognized options on the object, so that the top
        # level parser can decide what to do with them
        namespace, arg_strings = parser.parse_known_args(arg_strings, namespace)
        if arg_strings:
            vars(namespace).setdefault(_UNRECOGNIZED_ARGS_ATTR, [])
            getattr(namespace, _UNRECOGNIZED_ARGS_ATTR).extend(arg_strings)

