# MiniMud

Conceived as a school game this multi-user text-quest has simple web-interface,
optimized for mobile devices, but also has
a command-line client to facilitate testing. Work in progress for now.

### World description syntax

Currently syntax is not very consistent, parts of the commands are separated by
spaces (the last part could contain spaces itself - usually description) and
somewhere "pipes" and semicolons etc. Backslash allows for line continuation.

Empty lines and lines starting with semicolons are to be skipped, i.e. considered
comments. This is how `cli.pl` and `webfill.pl` should behave, especially when
bulk-loading lengthy world setup from file.

Firstly it makes sense to create some rooms.

    !room roomid Room title|Longer description

Users start in the room with id `start` (it makes sense to create this early).

    !cmd roomid cmd action1; ...; action2

Commands could be added to specific room or globally (with `*` instead of roomid).
Here "cmd" part could be simple word, like `look` or contain arguments. Overall
syntax of "cmd" is regexp and arguments are captured as regexp groups. Initially
it makes sense to add commands for looking and walking around, e.g.

    !cmd * look @look
    !cmd * (n|s|w|e) @walk $1
    !cmd * get\s+(\S+) @get $1
    !cmd * giggle You giggled
    !cmd pond kiss\s+frog Frog gave you an arrow; @grant arrow
    !cmd palace give\s+arrow\s+(?:to\s+)?king @~drop arrow; King smiled and blessed you
    !cmd gates use\s+passkey [haveObj passkey] You applied the passkey and went through the gates; @teleport yard
    !cmd gates use\s+passkey @haveObj passkey teleport yard

Symbol `@` in the action means that internal command with given name should be called,
perhaps passing arguments (i.e. captured groups) to it. Otherwise action is treated as
a message to be printed. Tilde symbol allows to "hush" the command output - e.g. in the last
example we want the object to disappear from inventory, but user shouldn't see message like
"arrow falls on the ground and disappeared".

Predicate `[...]` in square brackets allows to call suitable internal function,
e.g. checking whether character has certain object, certain gender etc. If
predicate function evaluates to false the corresponding command is not activated
and search for suitable command falls down to next ones in list.

Seemingly we have functionality similar to predicates with chaining commands
(as in the last example) but this is probably more limited remnant.

Language is selected by `MUD_LANG` env variable.

Now we can add ways between the rooms. Path is something respected by `walk` internal command.

    !way room dir where
    !way room dir|obj where
    !way room dir|obj|state where
    !way room dir|obj|state where|message
    !way room dir |message

In the simplest form you specify two room ids (`room` and `where`) while `dir` is some direction
word which we allowed to be passed into `walk` command somewhere above. E.g. if we enter `se` for
south-east and in the `addcmd ... @walk` above we haven't mentioned such abbreviation, we'll get
"unknown command" response. If we give known direction but there is no way in that direction then
message corresponding to "no way" is printed.

If `dir` is suffixed by some object-id, then this way only will work if the user has such object
or such object is present in given room. It could be further suffixed by the specific state
(in state `0` in both cases - e.g. we can pass if door is in the state "open" or if user has
passcard and it is not "broken").

Further we can suffix target room (`where`) with message - it will be printed on traversing this way.
If the message (with preceding pipe) is given, but target room is empty, then no move happens but
the message is printed (generally, explaining why user can't go that way).

It allows to chain several commands for the same direction, like this:

    !way gates n|passcard mainhall|You used passcard to enter Main Hall
    !way gates n|passcard|1 |You can't enter as your passcard is broken
    !way gates n |You need a passcard to pass here!
    !way park e?haveGender|m bog1

Quetion mark after `dir` allows to put predicate function with its arguments
here similarly to how it is done in commands.

_to be continued_
