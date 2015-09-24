package Mojo::PDF;

use Mojo::Base -base;

# VERSION

use Carp qw/croak/;
$Carp::Internal{ (__PACKAGE__) }++;
use PDF::Reuse 0.36;
use Graphics::Color::RGB;
use List::AllUtils qw/sum/;
use Mojo::PDF::Primitive::Table;
use namespace::clean;

$SIG{'__WARN__'} = sub { warn @_ unless caller eq 'PDF::Reuse'; };

has [qw/_x _y _line_height/] => 0;
has [qw/_cur_font  _cur_size  _cur_color/];
has _fonts => sub { +{} };

my $PAGE_SIZE_Y = 792;
my $PAGE_SIZE_X = 612;
my %STD_FONTS = (
    'Times-Roman'           => 'Times-Roman',
    'Times-Bold'            => 'Times-Bold',
    'Times-Italic'          => 'Times-Italic',
    'Times-BoldItalic'      => 'Times-BoldItalic',
    'Courier'               => 'Courier',
    'Courier-Bold'          => 'Courier-Bold',
    'Courier-Oblique'       => 'Courier-Oblique',
    'Courier-BoldOblique'   => 'Courier-BoldOblique',
    'Helvetica'             => 'Helvetica',
    'Helvetica-Bold'        => 'Helvetica-Bold',
    'Helvetica-Oblique'     => 'Helvetica-Oblique',
    'Helvetica-BoldOblique' => 'Helvetica-BoldOblique',
    'Symbol'                => 'Symbol',
    'ZapfDingbats'          => 'ZapfDingbats',
    'TR'  => 'Times-Roman',
    'TB'  => 'Times-Bold',
    'TI'  => 'Times-Italic',
    'TBI' => 'Times-BoldItalic',
    'C'   => 'Courier',
    'CB'  => 'Courier-Bold',
    'CO'  => 'Courier-Oblique',
    'CBO' => 'Courier-BoldOblique',
    'H'   => 'Helvetica',
    'HB'  => 'Helvetica-Bold',
    'HO'  => 'Helvetica-Oblique',
    'HBO' => 'Helvetica-BoldOblique',
    'S'   => 'Symbol',
    'Z'   => 'ZapfDingbats'
);

sub new {
    my ( $class, $filename ) = @_;
    my $self = bless {}, $class;

    prFile $filename;
    # use US-Letter pages
    prMbox ( 0, 0, $PAGE_SIZE_X, $PAGE_SIZE_Y );
    $self->size;

    $self;
}

sub mixin {
    my $self = shift;
    my ( $doc, $page ) = @_;
    prForm { file => $doc, page => $page//1 };

    $self;
}

sub add_fonts {
    my $self = shift;
    my %fonts = @_;

    for ( keys %fonts ) {
        $STD_FONTS{$_} and croak "Font name '$_' conflicts with one of the "
            . 'standard font names. Please choose another one';
        $self->_fonts->{$_} = $fonts{ $_ };
    };

    $self;
}

sub font {
    my $self = shift;
    my $name = shift;

    $STD_FONTS{$name} or $self->_fonts->{$name}
        or croak "Unknown font '$name'";

    $STD_FONTS{$name} ? prFont($name) : prTTFont( $self->_fonts->{$name} );
    $self->_cur_font($name);

    $self;
}

sub size {
    my $self = shift;
    my $size = shift // 12;

    $self->_cur_size( $size );
    prFontSize $size;
    $self->_line_height( $size*1.4 );

    $self;
}

sub color {
    my $self = shift;
    @_ = @{$_[0]} if @_ == 1 and ref $_[0] eq 'ARRAY';

    my ( $r, $g, $b )
        = @_ == 0 ? (0, 0, 0) # default to black
            : @_ == 1
            ? __hex2rgb( $_[0] ) # hex color
                : @_; # rgb tuple

    $self->_cur_color([$r, $g, $b]);
    prAdd "n $r $g $b RG $r $g $b rg\n";

    $self;
}

sub __hex2rgb {
    my $hex = shift;
    my $c = Graphics::Color::RGB->from_hex_string( $hex )
        or croak "Could not interpret color '$hex' as hex";

    return $c->as_array;
}

sub table {
    my $self = shift;
    my %conf = @_;

    $conf{row_height} ||= $self->_line_height;

    my $t = Mojo::PDF::Primitive::Table->new(
        pdf => $self,
        %conf,
    );

    my @overflow = $t->draw;
    return \@overflow if $conf{max_height};

    $self;
}

sub _stroke {
    my $self = shift;
    my $weight = shift;
    prAdd "$weight w";

    $self;
}

sub text {
    my $self = shift;
    my ( $string, $x, $y, $align, $rotation ) = @_;

    $x //= $self->_x;

    # Don't switch to new line, if neither X nor Y were given;
    $y //= $self->_y + ( @_ > 1 ? $self->_line_height : 0 );
    $self->_y( $y );
    $self->_x( (prText($x, __inv_y($y), $string, $align, $rotation))[1] );

    $self;
}

sub page {
    my $self = shift;
    prPage;

    $self;
}

sub end {
    my $self = shift;
    prEnd;
}

sub __inv_y { $_ = $PAGE_SIZE_Y - $_ for @_; $_[0] }

sub _line {
    my $self = shift;
    my ( $x1, $y1, $x2, $y2 ) = @_;
    __inv_y($y1, $y2);
    prAdd "$x1 $y1 m $x2 $y2 l S";

    $self;
}

sub _str_width {
    my $self = shift;
    my $str = shift;

    return prStrWidth(
        $str,
        $self->_cur_font//'Helvetica',
        $self->_cur_size//12
    ) // 0;
}

q|
There are only two hard problems in distributed systems:
2. Exactly-once delivery
1. Guaranteed order of messages 2. Exactly-once delivery
|;

__END__

=encoding utf8

=for stopwords Znet Zoffix Mojotastic PDFs RGB TTF

=head1 NAME

Mojo::PDF - Generate PDFs with the goodness of Mojo!

=head1 SYNOPSIS

=for pod_spiffy start code section

    # Just render text. Be sure to call ->end to save your document
    Mojo::PDF->new('mypdf.pdf')->text('Viva la Mojo!', 306, 396)->end;

    # Let's get fancy pants:
    Mojo::PDF->new('myawesome.pdf')

        ->mixin('_template.pdf')   # add a pre-made PDF page from a template

        # Render text with standard fonts
        ->font('Times-Bold')->size(24)->color(0, 0, .7)
            ->text('Mojo loves PDFs', 612/2, 500, 'center')

        # Render text with custom TTF fonts
        ->add_fonts(
            galaxie    => 'fonts/GalaxiePolaris-Book.ttf',
            galaxie_it => 'fonts/GalaxiePolaris-BookItalic.ttf',
        )
        ->font('galaxie')->size(24)->color('#353C8C')
            ->text( 'Weeee', 20.4, 75 )
            ->text( 'eeee continuing same line!')
            ->text( 'Started a new line!', 20.4 )

        # Render a table
        ->font('galaxie_it')->size(8)->color
        ->table(
            at        => [20.4, 268],
            data      => [
                [ qw{Product  Description Qty  Price  U/M} ],
                @data,
            ],
        )

        ->end;

=for pod_spiffy end code section

=head1 DESCRIPTION

Mojotastic, no-nonsense PDF generation.

=head1 WARNING

=for pod_spiffy start warning section

This module is currently experimental. Things will change.

=for pod_spiffy end warning section

=head1 METHODS

Unless otherwise indicated, all methods return their invocant.

=head2 C<new>

    my $pdf = Mojo::PDF->new('myawesome.pdf');

Creates a new C<Mojo::PDF> object. Takes one mandatory argument: the filename
of the PDF you want to generate.

=head2 C<end>

    $p->end;

Finish rendering your PDF and save it.

=head2 C<add_fonts>

    $pdf->add_fonts(
        galaxie    => 'fonts/GalaxiePolaris-Book.ttf',
        galaxie_it => 'fonts/GalaxiePolaris-BookItalic.ttf',
    );

Adds TTF fonts to the document. Key/value pairs specify the arbitrary name
of the font (for you to use with L</font>) and the path to the TTF file.

You cannot use any of the names of the L</DEFAULT FONTS> for your custom fonts.

=head2 C<color>

    $pdf->color(.5, .5, .3);
    $pdf->color('#abcdef');
    $pdf->color('#abc');   # same as #aabbcc
    $pdf->color;           # same as #000

Specifies active color. Takes either an RGB tuple or a hex colour. Defaults
to black.

=head2 C<font>

    $pdf->font('Times-Bold');

    $pdf->font('galaxie');

Sets active font family. Takes the name of either one of the L</DEFAULT FONTS>
or one of the custom fonts included with L</add_fonts>

=head2 C<mixin>

    $pdf->mixin('template.pdf');

    $pdf->mixin('template.pdf', 3);

Adds a page from an existing PDF to your currently active page, so you
can use it as a template and render additional things on it. Takes one
mandatory argument, the filename of the PDF to include. An optional second
argument specifies the page number to include (starting from 1),
which defaults to the first page.

=head2 C<page>

    $pdf->page;

Add a new blank page to your document and sets it as the currently active page.

=head2 C<size>

    $pdf->size(24);

    $pdf->size; # set to 12

Specifies active font size in points. Defaults to C<12> points.

=head2 C<table>

    $pdf->table(
        at        => [20.4, 268],
        data      => [
            [ qw{Product  Description Qty  Price  U/M} ],
            @$data,
        ],

        #Optional:
        border         => [.5, '#CFE3EF'],
        header         => 'galaxie_bold',
        max_height     => 744,
        min_width      => 571.2,
        row_height     => 24,
        str_width_mult => 1.1,
    );

Render a table on the current page. Takes these arguments:

=head3 C<at>

    at => [20.4, 268],

An arrayref with X and Y point values of the table's top, left corner.

=head3 C<data>

    data => [
        [ qw{Product  Description Qty  Price  U/M} ],
        @$data,
    ],

An arrayref of rows, each of which is an arrayref of strings representing
table cell values. Setting L</header> will render first row as a table header.
Cells that are C<undef>/empty string will not be rendered.

=head3 C<border>

    border => [.5, '#CFE3EF'],

B<Optional>. Takes an arrayref with the width (in points) and colour of
the table's borders. Color allows the same values as L</color> method.
B<Defaults to:> C<[.5, '#ccc']>

=head3 C<header>

    header => 'galaxie_bold',

B<Optional>. Takes the same value as L</font>. If set, the first row
of C</data> will be used as table header, rendered centered using
C<header> font. B<Not set by default.>

=head3 C<max_height>

    {
        $data = $pdf->table(
            max_height => 744,
            data       => $data,
            at         => [20.4, 50],
        );

        @$data and $pdf->page and redo;
    }

B<Optional>. B<ALTERS RETURN VALUE OF C<table> METHOD>. Specifies the maximum
height of the table. Specifying this option makes C<table> method return
an arrayref of rows that did not fit into the table. You can use that to
add a new page and continue rendering the overflown data.

=head3 C<min_width>

    min_width => 571.2,

B<Optional>. Table's minimum width in points (zero by default).
The largest column will be widened to make the table at least this wide.

=head3 C<row_height>

    row_height => 24,

B<Optional>. Specifies the height of a row, in points. Defaults to
1.4 times the current L<font size|/size>.

=head3 C<str_width_mult>

    str_width_mult => 1.1,

B<Optional>. Cell widths will be automatically computed based on the
width of the strings they contain. On some fonts, the detection is a bit
imperfect. For those cases, use C<str_width_mult> as a multiplier for the
detected character width.

=head2 C<text>

    $p->text($text_string, $x, $y, $alignment, $rotation);

    $p->text('Mojo loves PDFs', 612/2, 500, 'center', 90);
    $p->text('Lorem ipsum dolor sit amet, ', 20 );
    $p->text('consectetur adipiscing elit!');

Render text with the currently active L</font>, L</size>, and L</color>.
C<$alignment> specifies how to align the string horizontally on the C<$x>
point; valid values are C<left> (default), C<center>, and C<right>.
C<$rotation> is the rotation of the text in degrees.

Subsequent calls to C<text> can omit C<$x> and C<$y> values with
these effects: omit both to continue rendering where previous C<text>
finished; omit just C<$y>, to render on the next line from previous call
to C<text>.

=head1 DEFAULT FONTS

These fonts are available by default:

    Times-Roman
    Times-Bold
    Times-Italic
    Times-BoldItalic

    Courier
    Courier-Bold
    Courier-Oblique
    Courier-BoldOblique

    Helvetica
    Helvetica-Bold
    Helvetica-Oblique
    Helvetica-BoldOblique

    Symbol
    ZapfDingbats

You can use their abbreviated names:

    TR
    TB
    TI
    TBI

    C
    CB
    CO
    CBO

    H
    HB
    HO
    HBO

    S
    Z

=head1 SEE ALSO

L<PDF::Reuse>, L<PDF::Create>, and L<PDF::WebKit>

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/Mojo-PDF>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/Mojo-PDF/issues>

If you can't access GitHub, you can email your request
to C<bug-Mojo-PDF at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut