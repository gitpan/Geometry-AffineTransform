package Geometry::AffineTransform;

use strict;
use warnings;

use Carp;
use Hash::Util;
use Data::Dumper;
use Math::Trig;

our $VERSION = '1.0';


=head1 NAME

Geometry::AffineTransform - Maps 2D coordinates to other 2D coordinates

=head1 SYNOPSIS

	use Geometry::AffineTransform;
	
	my $t = Geometry::AffineTransform->new();
	$t->translate($delta_x, $delta_y);
	$t->rotate($degrees);
	my $t2 = Geometry::AffineTransform->new()->scale(3.1, 2.3);
	$t->concatenate($t2);
	my ($x1, $y1, $x2, $y2, ...) = $t->transform($x1, $y1, $x2, $y2, ...);
	
=head1 DESCRIPTION

Geometry::AffineTransform instances represent 2D affine transformations
that map 2D coordinates to other 2D coordinates. The references in
L</SEE ALSO> provide more information about affine transformations.

You create a new instance with L</new>, configure it to perform the desired transformation
with a combination of L</scale>, L</rotate> and L</translate> and then perform the actual
transformation on one or more x/y coordinate pairs with L</transform>.

The state of a newly created instance represents the identity transform,
that is, it transforms all input coordinates to the same output coordinates.

Most methods return the instance so that you can chain several calls:

    my $t = Geometry::AffineTransform->new();
    $t->scale(...)->translate(...)->rotate(...);
    
    ($x, $y) = Geometry::AffineTransform->new()->rotate(..)->transform($x, $y);

=cut


=head1 METHODS

=head2 new

Constructor, returns a new instance configured with an identity transform.

=head3 Parameters

You can optionally supply any of the six specifiable parts of the transformation matrix
if you want an initial state different from the identity transform:

    [ m11 m21 0 ]
    [ m21 m22 0 ]
    [ tx  ty  1 ]

The six values in the first two colums are the specifiable values. You can initialize
them with key/value parameters:

    my $t = Geometry::AffineTransform->new(tx => 10, ty => 15);

By default, the identity transform represented by this matrix is used:

    [ 1 0 0 ]
    [ 0 1 0 ]
    [ 0 0 1 ]

=cut

sub new {
	my $self = shift @_;
	my (%args) = @_;
	
	my $class = ref($self) || $self;
	$self = bless {m11 => 1, m12 => 0, m21 => 0, m22 => 1, tx => 0, ty => 0, %args}, $class;
	Hash::Util::lock_keys(%$self);
	
	return $self;
}




=head2 transform

Transform one or more coordinate pairs according to the current state.

=head3 Parameters

This method expects an even number of positional parameters, each pair
representing the x and y coordinates of a point.

=head3 Result

Returns the transformed list of coordinates in the same form as the input list.

=cut

sub transform {
	my $self = shift;
	my (@pairs) = @_;
	
	my @result;
	while (my ($x, $y) = splice(@pairs, 0, 2)) {
		my $x2 = $self->{m11} * $x + $self->{m21} * $y + $self->{tx};
		my $y2 = $self->{m12} * $x + $self->{m22} * $y + $self->{ty};
		push @result, $x2, $y2;
	}
	
	return @result;
}




# concatenate another transformation matrix to the current state.
# Takes the six specifiable parts of the 3x3 transformation matrix.
sub concatenate_matrix_2x3 {
	my $self = shift;
	my ($m11, $m12, $m21, $m22, $tx, $ty) = @_;
	my $a = [$self->matrix_2x3()];
	my $b = [$m11, $m12, $m21, $m22, $tx, $ty];
	return $self->set_matrix_2x3($self->matrix_multiply($a, $b));
}


=head2 concatenate

Combine the receiver's state with that of another transformation instance.

=head3 Parameters

This method expects a list of one or more C<Geometry::AffineTransform>
instances and combines the transformation of each one with the receiver's
in the given order.

=head3 Result

Returns C<$self>.

=cut

sub concatenate {
	my $self = shift;
	my ($t) = @_;
	croak "Expecting argument of type Geometry::AffineTransform" unless (ref $t);
	return $self->concatenate_matrix_2x3($t->matrix_2x3());
}


=head2 scale

Adds a scaling transformation.

=head3 Parameters

This method expects positional parameters.

=over

=item sx

The scaling factor for the x dimension.

=item sy

The scaling factor for the y dimension.

=back

=head3 Result

Returns C<$self>.

=cut

sub scale {
	my $self = shift;
	my ($sx, $sy) = @_;
	return $self->concatenate_matrix_2x3($sx, 0, 0, $sy, 0, 0);
}


=head2 scale

Adds a translation transformation, i.e. the transformation shifts
the input coordinates by a constant amount.

=head3 Parameters

This method expects positional parameters.

=over

=item tx

The offset for the x dimension.

=item ty

The offset for the y dimension.

=back

=head3 Result

Returns C<$self>.

=cut

sub translate {
	my $self = shift;
	my ($tx, $ty) = @_;
	return $self->concatenate_matrix_2x3(1, 0, 0, 1, $tx, $ty);
}




=head2 rotate

Adds a rotation transformation.

=head3 Parameters

This method expects positional parameters.

=over

=item angle

The rotation angle in degrees. With no other transformation active,
positive values rotate counterclockwise.

=back

=head3 Result

Returns C<$self>.

=cut

sub rotate {
	my $self = shift;
	my ($degrees) = @_;
	my $rad = deg2rad($degrees);
	return $self->concatenate_matrix_2x3(cos($rad), sin($rad), -sin($rad), cos($rad), 0, 0);
}



# returns the 6 specifiable parts of the transformation matrix
sub matrix_2x3 {
	my $self = shift;
	return $self->{m11}, $self->{m12}, $self->{m21}, $self->{m22}, $self->{tx}, $self->{ty};
}

# sets the 6 specifiable parts of the transformation matrix
sub set_matrix_2x3 {
	my $self = shift;
	($self->{m11}, $self->{m12},
	 $self->{m21}, $self->{m22},
	 $self->{tx}, $self->{ty}) = @_;
	return $self;
}


=head2 matrix

Returns the current value of the 3 x 3 transformation matrix, including the
third, fixed column, as a 9-element list:

    my ($m11, $m12, undef,
        $m21, $m22, undef,
        $tx,  $ty,  undef) = $t->matrix();

=cut

sub matrix {
	my $self = shift;
	return $self->{m11}, $self->{m12}, 0, $self->{m21}, $self->{m22}, 0, $self->{tx}, $self->{ty}, 1;
}




# a simplified multiply that assumes the fixed 0 0 1 third column
sub matrix_multiply {
	my $self = shift;
	my ($a, $b) = @_;
	
# 	a11 a12 0
# 	a21 a22 0
# 	a31 a32 1
# 	
# 	b11 b12 0
# 	b21 b22 0
# 	b31 b32 1

	my ($a11, $a12, $a21, $a22, $a31, $a32) = @$a;
	my ($b11, $b12, $b21, $b22, $b31, $b32) = @$b;
	
	return
		($a11 * $b11 + $a12 * $b21),        ($a11 * $b12 + $a12 * $b22),
		($a21 * $b11 + $a22 * $b21),        ($a21 * $b12 + $a22 * $b22),
		($a31 * $b11 + $a32 * $b21 + $b31), ($a31 * $b12 + $a32 * $b22 + $b32),
	;

}








1;

=head1 SEE ALSO

=over

=item Apple Quartz 2D Programming Guide - The Math Behind the Matrices

http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_affine/chapter_6_section_7.html

=item Sun Java java.awt.geom.AffineTransform

http://java.sun.com/j2se/1.4.2/docs/api/java/awt/geom/AffineTransform.html

=item Wikipedia - Matrix Multiplication

http://en.wikipedia.org/wiki/Matrix_(mathematics)#Matrix_multiplication

=back





=head1 COPYRIGHT AND LICENSE

Copyright 2008 Marc Liyanage.

=cut
