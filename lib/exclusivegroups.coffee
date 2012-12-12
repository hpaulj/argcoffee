###
 mutually exclusive groups stub
_format_actions_usage -
        # clean up separators for mutually exclusive groups
        open = r'[\[(]'
        close = r'[\])]'
        text = _re.sub(r'(%s) ' % open, r'\1', text)
        text = _re.sub(r' (%s)' % close, r'\1', text)
        text = _re.sub(r'%s *%s' % (open, close), r'', text)
        text = _re.sub(r'\(([^|]*)\)', r'\1', text)
        text = text.strip()
action container init
        self._mutually_exclusive_groups = []
        # adding this from outside may be tricky
action container
    #def add_argument_group(self, *args, **kwargs):
    #    group = _ArgumentGroup(self, *args, **kwargs)
    #    self._action_groups.append(group)
    #    return group
    #def add_mutually_exclusive_group(self, **kwargs):
    #    group = _MutuallyExclusiveGroup(self, **kwargs)
    #    self._mutually_exclusive_groups.append(group)
    #    return group
            
    # add to AP proto, or the AC class defined in AP
    add_argument_group:: (args...) ->
        group = _ArgumentGroup(@, args)
        @_action_groups.push(group)
        group
    add_mutually_exclusive_group:: (options) ->
        group = _MutuallyExclusiveGroup(options)
        if @_mutually_exclusive_groups?
            # allow for possibility that this argument is not defined yet
            @_mutually_exclusive_groups.push(group)
        else
            @_mutually_exclusive_groups = [group]
            
_add_container_actions
        # add container's mutually exclusive groups
        # NOTE: if add_mutually_exclusive_group ever gains title= and
        # description= then this code will need to be expanded as above
        for group in container._mutually_exclusive_groups:
            mutex_group = self.add_mutually_exclusive_group(
                required=group.required)

            # map the actions to their new mutex group
            for action in group._group_actions:
                group_map[action] = mutex_group
                
        if container._mutually_exclusive_groups?
            for group in container._mutually_exclusive_groups
                mutex_group = @add_mutually_exclusive_group({required:group.required})
                # map the actions to their new mutex group
                for action in group._group_actions:
                    group_map[action] = mutex_group
            
class _MutuallyExclusiveGroup(_ArgumentGroup):
arg parser
add subparsers
parse known args
        # map all mutually exclusive arguments to the other arguments
        # they can't occur with
        action_conflicts = {}
        for mutex_group in @_mutually_exclusive_groups
            group_actions = mutex_group._group_actions
            for mutex_action,i in mutex_group._group_actions
                conflicts = action_conflicts.setdefault(mutex_action, [])
                conflicts.push(group_actions[...i]...)
                conflicts.push(group_actions[i + 1...]...)
    ...
        # make sure all required groups had one option present
        for group in self._mutually_exclusive_groups
            if group.required
                for action in group._group_actions
                    if action in seen_non_default_actions
                        break

                # if no actions were used, report the error
                else
                    names = [_get_action_name(action)
                             for action in group._group_actions
                             when action.help is not $$.SUPPRESS]
                    msg = "one of the arguments #{names.join(' ')} is required"
                                        self.error msg
                    
            groups = @mutually_exclusive_groups

        
###


class _ArgumentGroup(_ActionsContainer):

    def __init__(self, container, title=None, description=None, **kwargs):
        # add any missing keyword arguments by checking the container
        update = kwargs.setdefault
        update('conflict_handler', container.conflict_handler)
        update('prefix_chars', container.prefix_chars)
        update('argument_default', container.argument_default)
        super_init = super(_ArgumentGroup, self).__init__
        super_init(description=description, **kwargs)

        # group attributes
        self.title = title
        self._group_actions = []

        # share most attributes with the container
        self._registries = container._registries
        self._actions = container._actions
        self._option_string_actions = container._option_string_actions
        self._defaults = container._defaults
        self._has_negative_number_optionals = \
            container._has_negative_number_optionals

    def _add_action(self, action):
        action = super(_ArgumentGroup, self)._add_action(action)
        self._group_actions.append(action)
        return action

    def _remove_action(self, action):
        super(_ArgumentGroup, self)._remove_action(action)
        self._group_actions.remove(action)



class _MutuallyExclusiveGroup(_ArgumentGroup):

    def __init__(self, container, required=False):
        super(_MutuallyExclusiveGroup, self).__init__(container)
        self.required = required
        self._container = container

    def _add_action(self, action):
        if action.required:
            msg = _('mutually exclusive arguments must be optional')
            raise ValueError(msg)
        action = self._container._add_action(action)
        self._group_actions.append(action)
        return action

    def _remove_action(self, action):
        self._container._remove_action(action)
        self._group_actions.remove(action)

