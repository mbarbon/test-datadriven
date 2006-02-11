package DummyT;

use strict;
use warnings;

use Test::DataDriven::Plugin -base;
use Test::Differences;

use Dummy;
use File::Path;

BEGIN {
    rmtree( 't/dummy' );
    mkpath( 't/dummy' );
}

__PACKAGE__->register( 'Test::DataDriven' );

sub run_mkpath : Run(mkpath) {
    my( $block, $section, @v ) = @_;

    Dummy::mkpath( @v );
}

sub run_touch : Run(touch) {
    my( $block, $section, @v ) = @_;

    Dummy::touch( @v );
}

my @orig;
my $directory;

sub pre_directory : Begin(directory) {
    my( $block, $section, @v ) = @_;
    $directory = $v[0];
}

sub pre_created : Begin(created) {
    my( $block, $section, @v ) = @_;
    @orig = Dummy::ls( $directory . '/*' );
}

sub _lsd {
    my( $block, $section, @v ) = @_;
    my %final = map { ( $_ => 1 ) } Dummy::ls( $directory . '/*' );

    delete $final{$_} foreach @orig;

    my @final = map { s{^$directory/}//; $_ } keys %final;
}

sub post_created : End(created) {
    my( $block, $section, @v ) = @_;

    my @final = _lsd( @_ );
    eq_or_diff( \@final, \@v, test_name );
}

sub post_createdc : Endc(created) {
    my( $block, $section, @v ) = @_;

    my @final = _lsd( @_ );
    $block->original_values->{$section} = join "\n", @final, '';
}

1;
