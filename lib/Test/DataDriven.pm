package Test::DataDriven;

=head1 NAME

Test::DataDriven - when Test::Base is not enough

=head1 SYNOPSIS

In the test module:

    # t/lib/MyTest.pm
    package MyTest;

    use Test::DataDriven::Plugin -base;
    __PACKAGE__->register( 'Test::DataDriven' );

    my $time;
    my $result;

    sub check_first : Begin(add1) {
        my( $block, $section_name, @data ) = @_;
        $time = time();
    }

    sub do_that : Run(add1) {
        my( $block, $section_name, @data ) = @_;
        $result = add_1( $data[0] );
    }

    sub check_it_up : End(result) {
        my( $block, $section_name, @data ) = @_;
        is( $result, $data[0] );
        ok( time() - $time < 1 ); # check side effects
    }

In the test file:

   use MyTest;
   use Test::More tests => 4;

   Test::DataDriven->run;

   __END__

   === Test 1
   --- add1 chomp
   3
   --- result
   4

   === Test 1
   --- add1 chomp
   7
   --- result
   8

=head1 DESCRIPTION

C<Test::Base> is great for writing data driven tests, but sometimes you
need to test things that cannot easily be expressed using the
filter-and-compare-output approach.

C<Test::DataDriven> builds upon C<Test::Base> adding the ability to
declare actions to be run for each section of each test block. In
particular, the processing of each block is divided in three phases:
"begin", "run" and "end".

=cut

use strict;
use warnings;

use Test::Base -base, '!run';
use Fatal qw(open close);

our $VERSION = '0.01';

my( @plugins, %tags, @tags_re, $stop_run );

=head1 METHODS

=head2 register

    Test::DataDriven->register
      ( plugin   => $plugin
        tag      => 'section_name'
        tag_re   => qr/match/ );

Registers a plugin whose C<begin>, C<run> and C<end> methods will be
called for each section whose name equals the one specified with 'tag'
or matches the regular expression specified with 'tag_re'.

=cut

sub register {
    my( $class, %args ) = @_;
    my( $plugin, $tag, $tag_re ) = @args{qw(plugin tag tag_re)};

    push @plugins, $plugin;
    push @{$tags{$tag}}, $plugin if $tag;
    push @tags_re, [ $tag_re, $plugin ] if $tag_re;
}

=head2 run

    Test::DataDriven->run;

Iterates over the C<Test::Base> blocks calling the plugins that match
the block sections.

=cut

sub _plugins_for {
    my( $class, $tag ) = @_;
    my @plugins =
      ( ( exists $tags{$tag} ? @{$tags{$tag}} : () ),
        ( map { my( $re, $plugin ) = $_->[0];
                $tag =~ /$re/ ? ( $plugin ) : () }
              @tags_re ) );

    return @plugins;
}

sub _run_plugins {
    my( $self, $block, $action ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 2;

    my $section_order = $block->_section_order;

    foreach my $section_name ( @$section_order ) {
        my @value = $block->$section_name;

        foreach my $plugin ( $self->_plugins_for( $section_name ) ) {
            next unless $plugin->can( $action );
            $plugin->$action( $block, $section_name, @value );
        }
    }
}

my $create;
my $create_fh;

# do not use this
sub create {
    $create = $_[1] if @_ > 1;
    return $create;
}

sub create_fh { $create_fh }

sub run {
    my( $self ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $stop_run = 0;
    filters_delay;

    my $end = $create ? 'endc' : 'end';
    if( $create ) {
        open $create_fh, '>', $create;
    }
    for my $block ( blocks ) {
        last if $stop_run;

        $block->run_filters;
        foreach my $action ( qw(begin run), $end ) {
            last if $stop_run;

            $self->_run_plugins( $block, $action );
        }
    }

    close $create_fh if $create_fh;
}

=head1 BUGS

Needs more documentation and examples.

=head1 AUTHOR

Mattia Barbon <mbarbon@cpan.org>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;
