NAME
====

`AttrX::Mooish` - extend attributes with ideas from Moo/Moose (laziness!)

SYNOPSIS
========

    use AttrX::Mooish;
    class Foo {
        has $.bar1 is mooish(:lazy, :clearer, :predicate) is rw;
        has $!bar2 is mooish(:lazy, :clearer, :predicate, :trigger);
        has Num $.bar3 is rw is mooish(:lazy, :filter);

        method build-bar1 {
            "lazy init value"
        }
        
        method !build-bar2 {
            "this is private mana!"
        }

        method !trigger-bar2 ( $value ) {
            # do something after attribute changed.
        }

        method build-bar3 {
            rand;
        }

        method filter-bar3 ( $value, *%params ) {
            if %params<old-value>:exists {
                # Only allow the value to grow
                return ( !%params<old-value>.defined || $value > %params<old-value> ) ?? $value !! %params<old-value>;
            }
            # Only allow inital values from 0.5 and higher
            return $value < 0.5 ?? Nil !! $value;
        }

        method baz {
            # Yes, works with private too! Isn't it magical? ;)
            "Take a look at the magic: «{ $!bar2 }»";
        }
    }

    my $foo = Foo.new;

    say $foo.bar1;
    say $foo.bar3.defined ?? "DEF" !! "UNDEF";
    for 1..10 { $foo.bar3 = rand; say $foo.bar3 }

The above would generate a output similar to the following:

    lazy init value
    UNDEF
    0.08662089602505263
    0.49049512098324255
    0.49049512098324255
    0.5983833081770437
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302
    0.9367804461546302

DESCRIPTION
===========

This module is aiming at providing some functionality we're all missing from Moo/Moose. For now it implements laziness with accompanying methods. But more may come in the future.

What makes this module different from previous versions one could find in the Perl6 modules repository is that it implements true laziness allowing *Nil* to be a first-class value of a lazy attribute. In other words, if you look at the [#SYNOPSIS](#SYNOPSIS) section, `$.bar3` value could randomly be either undefined or 3.1415926.

Laziness for beginners
----------------------

This section is inteded for beginners and could be skipped by experienced lazybones.

### What is "lazy attribute"

As always, more information could be found by Google. In few simple words: a lazy attribute is the one which gets its first value on demand, i.e. – on first read operation. Consider the following code:

    class Foo {
        has $.bar is mooish(:lazy, :predicate);

        method build-bar { π }
    }

    my $foo = Foo.new
    say $foo.has-bar; # False
    say $foo.bar;     # 3.1415926...
    say $foo.has-bar; # True

### When is it useful?

Laziness becomes very handy in cases where intializing an attribute is very expensive operation yet it is not certain if attribute is gonna be used later or not. For example, imagine a monitoring code which raises an alert when a failure is detected:

    class Monitor {
        has $.notifier;
        has $!failed-object;
       
        submethod BUILD {
            $!notifier = Notifier.new;
        }

        method report-failure {
            $.notifier.alert( :$!failed-object );
        }

        ...
    }

Now, imagine that notifier is a memory-consuming object, which is capable of sending notification over different kinds of media (SMTP, SMS, messengers, etc...). Besides, preparing handlers for all those media takes time. Yet, failures are rare and we may need the object, say, once in 10000 times. So, here is the solution:

    class Monitor {
        has $.notifier is mooish(:lazy);
        has $!failed-object;

        method build-notifier { Notifier.new( :$!failed-object ) }

        method report-failure {
            $.notifier.alert;
        }

        ...
    }

Now, it would only be created when we really need it.

Such approach also works well in interactive code where many wuch objects are created only the moment a user action requires them. This way overall responsiveness of a program could be significally incresed so that instead of waiting long once a user would experience many short delays which sometimes are even hard to impossible to be aware of.

Laziness has another interesting application in the area of taking care of attribute dependency. Say, `$.bar1` value depend on `$.bar2`, which, in turn, depends either on `$.bar3` or `$.bar4`. In this case instead of manually defining the order of initialization in a `BUILD` submethod, we just have the following code in our attribute builders:

    method build-bar2 {
        if $some-condition {
            return self.prepare( $.bar3 );
        }
        self.prepare( $.bar4 );
    }

This module would take care of the rest.

USAGE
=====

The [#SYNOPSIS](#SYNOPSIS) is a very good example of how to use the trait `mooish`.

Trait parameters
----------------

  * *`lazy`*

    `Bool`, defines wether attribute is lazy. Can have `Bool`, `Str`, or `Callable` value. The later two have the same meaning, as for *`builder`* parameter.

  * *`builder`*

    Defines builder method for a lazy attribute. The value returned by the method will be used to initialize the attribute.

    This parameter can have `Str` or `Callable` values or be not defined at all. In the latter case we expect a method with a name composed of "*build-*" prefix followed by attribute name to be defined in our class. For example, for a attribute named `$!bar` the method name is expected to be *build-bar*.

    A string value defines builder's method name.

    A callable value is used as-is and invoked as an object method. For example:

        class Foo {
            has $.bar is mooish(:lazy, :builder( -> $,*% {"in-place"} );
        }

        $inst = Foo.new;
        say $inst.bar;

    This would output '*in-place*'.

    *Note* the use of slurpy `*%` in the pointy block. Read about callback parameters below.

  * *`predicate`*

    Could be `Bool` or `Str`. When defined trait will add a method to determine if attribute is set or not. Note that it doesn't matter wether it was set with a builder or by an assignment.

    If parameter is `Bool` *True* then method name is made of attribute name prefixed with _has-_. See [#What is "lazy attribute"](#What is "lazy attribute") section for example.

    If parameter is `Str` then the string contains predicate method name:

                has $.bar is mooish(:lazy, :predicate<bar-is-ready>);
                ...
                method baz {
                    if self.bar-is-ready {
                        ...
                    }
                }

  * *`clearer`*

    Could be `Bool` or `Str`. When defined trait will add a method to reset the attribute to uninitialzed state. This is not equivalent to *undefined* because, as was stated above, *Nil* is a valid value of initialized attribute.

    Similarly to *`predicate`*, when *True* the method name is formed with _clear-_ prefix followed by attribute's name. A `Str` value defines method name:

                has $.bar is mooish(:lazy, :clearer<reset-bar>, :predicate);
                ...
                method baz {
                    $.bar = "a value";
                    say self.has-bar;  # True
                    self.reset-bar;
                    say self.has-bar;  # False
                }

  * *`filter`*

    A filter is a method which is executed right before storing a value to an attribute. What is returned by the method will actually be stored into the attribute. This allows us to manipulate with a user-supplied value in any necessary way.

    The parameter can have values of `Bool`, `Str`, `Callable`. All values are treated similarly to the `builder` parameter except that prefix '*filter-*' is used when value is *True*.

    The filter method is passed with user-supplied value and two named parameters: `attribute` with full attribute name; and optional `old-value` which could omitted if attribute has not been initialized yet. Otherwise `old-value` contains attribute value before the assignment.

    **Note** that it is not recommended for a filter method to use the corresponding attribute directly as it may cause unforseen side-effects like deep recursion. The `old-value` parameter is the right way to do it.

  * *`trigger`*

    A trigger is a method which is executed when a value is being written into an attribute. It gets passed with the stored value as first positional parameter and named parameter `attribute` with full attribute name. Allowed values for this parameter are `Bool`, `Str`, `Callable`. All values are treated similarly to the `builder` parameter except that prefix '*trigger-*' is used when value is *True*.

    Trigger method is being executed right after changing the attribute value. If there is a `filter` defined for the attribute then value will be the filtered one, not the initial.

  * *`composer`*

    This is a very specific option mostly useful until role `COMPOSE` phaser is implemented. Method of this option is called upon class composition time.

Public/Private
--------------

For all the trait parameters, if it is applied to a private attribute then all auto-generated methods will be private too. 

The call-back style options such as `builder`, `trigger`, `filter` are expected to share the privace mode of their respective attribute:

        class Foo {
            has $!bar is rw is mooish(:lazy, :clearer<reset-bar>, :predicate, :filter<wrap-filter>);

            method !build-bar { "a private value" }
            method baz {
                if self!has-bar {
                    self!reset-bar;
                }
            }
            method !wrap-filter ( $value, :$attribute ) {
                "filtered $attribute: ($value)"
            }
        }

Though if a callback option is defined with method name instead of `Bool` *True* then if method wit the same privacy mode is not found then opposite mode would be tried before failing:

        class Foo {
            has $.bar is mooish( :trigger<on_change> );
            has $!baz is mooish( :trigger<on_change> );
            has $!fubar is mooish( :lazy<set-fubar> );

            method !on_change ( $val ) { say "changed! ({$val})"; }
            method set-baz { $!baz = "new pvt" }
            method use-fubar { $!fubar }
        }

        $inst = Foo.new;
        $inst.bar = "new";  # changed! (new)
        $inst.set-baz;      # changed! (new pvt)
        $inst.use-fubar;    # Dies with "No such private method '!set-fubar' for invocant of type 'Foo'" message

User method's (callbacks) options
---------------------------------

User defined (callback-type) methods receive additional named parameters (options) to help them understand their context. For example, a class might have a couple of attributes for which it's ok to have same trigger method if only it knows what attribute it is applied to:

        class Foo {
            has $.foo is rw is mooish(:trigger('on_fubar'));
            has $.bar is rw is mooish(:trigger('on_fubar'));

            method on_fubar ( $value, *%opt ) {
                say "Triggered for {%opt<attribute>} with {$value}";
            }
        }

        my $inst = Foo.new;
        $inst.foo = "ABC";
        $inst.bar = "123";

    The expected output would be:

        Triggered for $!foo with with ABC
        Triggered for $!bar with with 123

**NOTE:** If a method doesn't care about named parameters it may only have positional arguments in its signature. This doesn't work for pointy blocks where anonymous slurpy hash would be required:

        class Foo {
            has $.bar is rw is mooish(:trigger(-> $, $val, *% {...})); 
        }

### Options

  * *`attribute`*

    Full attribute name with twigil. Passed to all callbacks.

  * *`builder`*

    Only set to *True* for `filter` and `trigger` methods when attribute value is generated by lazy builder. Otherwise no this parameter is not passed to the method.

  * *`old-value`*

    Set for `filter` only. See its description above.

Some magic
----------

Note that use of this trait doesn't change attribute accessors. More than that, accessors are not required for private attributes. Consider the `$!bar2` attribute from [#SYNOPSIS](#SYNOPSIS).

CAVEATS
=======

This module is using manual type checking for attributes with constraints. This could result in outcome different from default Perl6 behaviour.

Due to the magical nature of attribute behaviour conflicts with other traits are possible. None is known to the author yet.

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

