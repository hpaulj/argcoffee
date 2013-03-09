argcoffee
=========

This is a JavaScript translation of the Python argparse module, written primarily in CoffeeScript.

http://coffeescript.org/

http://docs.python.org/2.7/library/argparse.html

It is similar to nodeca/argparse
https://github.com/nodeca/argparse

But since CoffeeScript has a syntax that is similar to Python (and Ruby), this code
is closer in structure to the Python original.  I also kept the underscore style
of variable and function names.  However to facilitate the use of test files written
for the nodeca version, I have included camelcase aliases for many of the public
functions and attributes.

plac
----

In addition, plac.coffee/js, implements part of the Python plac package
https://code.google.com/p/plac/
Specifically it is a coffee translation of the plac_core.py file.

Plac is a front end to argparse.py, designed to provide the arguments required by a
specified function.  To the extent possible it deduces the nature of those
arguments from the calling signature of the function.  Where needed annotations
can be added.  In Python3 those annotations can be part of the function definition.
In Python2 these are added as an `.__attributions` attribute of the function. Plac
provides a decorator to facilitate this.  Additionally Plac takes advantage of the
4 types of function arguments, positional args, keyword args with default values,
`*args`, and `**kwargs`.

I have replaced the Python `getargspec()` with a function that parses the javascript function's
toString(), identifying the function name, args, and first comment line.  Argument
names like vargs and kwarg stand in for the python `*arg`, `**kwarg` names.  Defaults
can be provided with a f.defaults attribute.

This version of plac includes the commands, or subparser feature of the Python.

At its most suscinct,
`plac.call(main)`
parses function `main()` to indentify its arguments, creates an `ArgumentParser`,
adds those arguments to the parser, parses the process.argv to get values,
invokes `main` with those values, and returns the result from `main`.

