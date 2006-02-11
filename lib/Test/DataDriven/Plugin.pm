package Test::DataDriven::Plugin;

=head1 NAME

Test::DataDriven::Plugin - when Test::Base is not enough

=head1 SYNOPSIS

See C<Test::DataDriven>

=cut

use strict;
use warnings;

use Class::Spiffy -base;
use Test::DataDriven ();

our @EXPORT = qw(test_name);

my %attributes;
my %dispatch;

=head1 METHODS

=cut

sub MODIFY_CODE_ATTRIBUTES {
    my( $class, $code, @attrs ) = @_;
    my( @known, @unknown );

    foreach ( @attrs ) {
        /^(?:Begin|Run|End|Endc)\s*(?:$|\()/ ?
          push @known, $_ : push @unknown, $_;
    }

    $attributes{$class}{$code} = [ $code, \@known ];

    return @unknown;
}

=pod

sub FETCH_CODE_ATTRIBUTES {
    return @{$attributes{ref( $_[0] ) || $_[0]}{$_[1]}[1] || []};
}

=cut

our $test_name;

sub test_name() { $test_name }

sub _parse {
    my( @attributes ) = @_;

    return map  { m/^(\w+)\(\s*(\w+)\s*\)/ or die $_;
                  [ lc( $1 ), $2 ]
                  }
                @attributes;
}

=head2 register

    __PACKAGE__->register;

This method must be called by every C<Test::DataDriven::Plugin>
subclass in order to register the section handlers with
C<Test::DataDriven>.

=cut

sub register {
    my( $self, $pluggable ) = @_;
    my $class = ref( $self ) || $self;
    my @attributes = values %{$attributes{$class}};
    my %keys;

    foreach my $attr ( @attributes ) {
        my( $sub, $attrs ) = @$attr;
        foreach my $h ( _parse @$attrs ) {
            $keys{$h->[1]} = 1;
            push @{$dispatch{$class}{$h->[0]}{$h->[1]}}, $sub;
        }
    }

    $pluggable ||= 'Test::DataDriven';
    foreach my $key ( keys %keys ) {
        $pluggable->register( plugin => $self,
                              tag    => $key,
                              );
    }
}

sub _dispatch {
    my( $act, $self, $block, $section, @a ) = @_;
    my $class = ref( $self ) || $self;

    return unless    exists $dispatch{$class}
                  && exists $dispatch{$class}{$act}
                  && exists $dispatch{$class}{$act}{$section};

    local $Test::Builder::Level = 1;
    local $test_name = join ' - ', $block->name, $act, $section;

    my $run_one = 0;
    foreach my $sub ( @{$dispatch{$class}{$act}{$section}} ) {
        &$sub( $block, $section, @a );
        $run_one = 1;
    }

    return $run_one;
}

sub begin { _dispatch( 'begin', @_ ); }
sub run { _dispatch( 'run', @_ ); }
sub end { _dispatch( 'end', @_ ); }

sub endc {
    my( $self, $block, $section, @v ) = @_;

    _dispatch( 'endc', @_ );
    _serialize_back( @_ );
}

my %started;

sub _serialize_back {
    my( $self, $block, $section, @v ) = @_;
    my $create_fh = Test::DataDriven->create_fh;

    print $create_fh "=== ", $block->name, "\n" unless $started{$block};
    if( defined $block->description && $block->description ne $block->name ) {
        print $create_fh $block->description , "\n" ;
    }
    print $create_fh "--- ", $section;
    my $filters = $block->_section_map->{$section}{filters};
    if( $filters ) {
        print $create_fh ' ', $filters;
    }
    print $create_fh "\n";
    print $create_fh $block->original_values->{$section};

    $started{$block} = 1;
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
