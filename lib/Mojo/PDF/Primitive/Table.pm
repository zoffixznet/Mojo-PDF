package Mojo::PDF::Primitive::Table;

# VERSION

use List::AllUtils qw/sum/;
use Types::Standard qw/ArrayRef  Tuple  InstanceOf  StrictNum  Str/;
use Types::Common::Numeric qw/PositiveInt  PositiveOrZeroNum  PositiveNum/;
use Moo 2.000002;
use namespace::clean;

$Carp::Internal{ (__PACKAGE__) }++;
my $CELL_PADDING_X = 12;
my $CELL_PADDING_Y = 6;

has at             => ( is => 'ro',   required => 1,
    isa => Tuple[ StrictNum, StrictNum ],
);
has data           => ( is => 'ro',   required => 1,  isa => ArrayRef,       );
has pdf            => ( is => 'ro',   required => 1,
    isa => InstanceOf['Mojo::PDF'],
);

has min_width      => ( is => 'ro',   default  => 0,  isa =>PositiveOrZeroNum);
has row_height     => ( is => 'ro',   default  => 12, isa => PositiveNum,    );
has str_width_mult => ( is => 'ro',   default  => 1,  isa => StrictNum       );
has header         => ( is => 'ro',   default  => 0,  isa => Str             );
has border         => ( is => 'ro',   default  => sub { [.5, '#ccc'] },
    isa => ArrayRef,
);

has _border_color  => ( is => 'lazy',                                        );
has _border_width  => ( is => 'lazy', builder  => sub { shift->border->[0]  });
has _col_widths    => ( is => 'lazy',                                        );
has _cols          => ( is => 'lazy',                                        );
has _rows          => ( is => 'lazy', builder  => sub {scalar @{shift->data}});
has _x             => ( is => 'lazy', builder  => sub { shift->at->[0]      });
has _y             => ( is => 'lazy', builder  => sub { shift->at->[1]      });

sub _build__border_color {
    my $border = shift->border;
    shift @$border; # get rid of border width
    return $border;
}

sub _build__cols {
    my $data = shift->data;
    my $col_num = 0;
    @$_ > $col_num and $col_num = @$_ for @$data;
    return $col_num;
}

sub _build__col_widths {
    my $self = shift;
    my $data = $self->data;
    my $col_num = $self->_cols;

    my @col_widths = (0) x $col_num;
    my $w_mult = $self->str_width_mult;
    for my $row ( @$data ) {
        for ( 0 .. $col_num - 1 ) {
            next unless defined $row->[$_];
            my $w = $w_mult * $self->pdf->_str_width( $row->[$_] );
            $col_widths[$_] = $w if $w > $col_widths[$_];
        }
    }

    $_ += 2*$CELL_PADDING_X for @col_widths; # cell padding

    # Stretch largest column to fill table to its min_width
    if ( $self->min_width > sum @col_widths ) {
        my $idx = 0;
        for ( 0 .. $#col_widths ) {
           $idx = $_ if $col_widths[$_] > $col_widths[0]
        }
        $col_widths[$idx] += $self->min_width - sum @col_widths;
    }

    return \@col_widths;
}

####
#### METHODS
####

sub draw {
    my $self = shift;
    my $data = $self->data;

    $self->pdf->_stroke( $self->_border_width );

    for my $row ( 1 .. $self->_rows ) {
        $self->_draw_row( $row, $data->[$row-1] );
    }
}

sub _draw_row {
    my ( $self, $r_num, $cells ) = @_;

    for my $cell ( 1 .. @$cells ) {
        $self->_draw_cell( $r_num, $cell, $cells->[$cell-1] );
    }
}

sub _draw_cell {
    my ( $self, $r_num, $c_num, $text ) = @_;
    my $pdf = $self->pdf;

    my $x1 = $self->_x;
    $x1   += $self->_col_widths->[$_] for 0 .. $c_num - 2;
    my $y1 = $self->_y + ($self->row_height + 2*$CELL_PADDING_Y)*($r_num-1);

    my $x2 = $x1 + $self->_col_widths->[$c_num-1];
    my $y2 = $y1 + $self->row_height + 2*$CELL_PADDING_Y;

    my $saved_color = $pdf->_cur_color;
    $pdf->color( $self->_border_color );
    $pdf->_line( $x1, $y1, $x2, $y1 );
    $pdf->_line( $x2, $y1, $x2, $y2 );
    $pdf->_line( $x2, $y2, $x1, $y2 );
    $pdf->_line( $x1, $y2, $x1, $y1 );
    $pdf->color( @$saved_color );

    # Render table header
    if ( $r_num == 1 and $self->header ) {
        my $saved_font = $pdf->_cur_font;
        $pdf->font( $self->header );
        $pdf->text(
            $text,
            $x1 + ( .5*$self->_col_widths->[$c_num-1] ),
            $y1 + $self->row_height + $CELL_PADDING_Y - 2,
            'center',
        );
        $pdf->font( $saved_font );

        return;
    }

    $pdf->text(
        $text,
        $x1 + $CELL_PADDING_X,
        $y1 + $self->row_height + $CELL_PADDING_Y - 2
    );
}

1;

__END__

=encoding utf8

=for stopwords Znet Zoffix

=for Pod::Coverage *EVERYTHING*

=head1 NAME

Mojo::PDF::Primitive::Table - table primitive for Mojo::PDF

=head1 DESCRIPTION

Class implementing a table primitive. See L<Mojo::PDF/"table">

=cut

