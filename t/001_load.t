#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More ();

require Test::DataDriven;
require Test::DataDriven::Plugin;

Test::More::plan( tests => 1 );
Test::More::isnt( "I hate", "Side effects",
    "You are in a twisty maze of subroutine redefinitions, all alike" );
