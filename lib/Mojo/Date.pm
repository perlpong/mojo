package Mojo::Date;
use Mojo::Base -base;
use overload bool => sub {1}, '""' => sub { shift->to_string }, fallback => 1;

use Time::Local 'timegm';

has 'epoch';

my $RFC3339_RE = qr/
  ^
  (\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)(?:\.\d+)?   # Date and time
  (?:Z|([+-])(\d+):(\d+))?                        # Offset
  $
/xi;

my @DAYS   = qw(Sun Mon Tue Wed Thu Fri Sat);
my @MONTHS = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %MONTHS;
@MONTHS{@MONTHS} = (0 .. 11);

sub new { @_ > 1 ? shift->SUPER::new->parse(@_) : shift->SUPER::new }

sub parse {
  my ($self, $date) = @_;

  # epoch (784111777)
  return $self->epoch($date) if $date =~ /^\d+$/;

  # RFC 822/1123 (Sun, 06 Nov 1994 08:49:37 GMT)
  my $offset = 0;
  my ($day, $month, $year, $h, $m, $s);
  if ($date =~ /^\w+\,\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+GMT$/) {
    ($day, $month, $year, $h, $m, $s) = ($1, $MONTHS{$2}, $3, $4, $5, $6);
  }

  # RFC 3339
  elsif ($date =~ $RFC3339_RE) {
    ($year, $month, $day, $h, $m, $s) = ($1, $2 - 1, $3, $4, $5, $6);
    $offset = (($8 * 3600) + ($9 * 60)) * ($7 eq '-' ? -1 : 1) if $7;
  }

  # RFC 850/1036 (Sunday, 06-Nov-94 08:49:37 GMT)
  elsif ($date =~ /^\w+\,\s+(\d+)-(\w+)-(\d+)\s+(\d+):(\d+):(\d+)\s+GMT$/) {
    ($day, $month, $year, $h, $m, $s) = ($1, $MONTHS{$2}, $3, $4, $5, $6);
  }

  # ANSI C asctime() (Sun Nov  6 08:49:37 1994)
  elsif ($date =~ /^\w+\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)$/) {
    ($month, $day, $h, $m, $s, $year) = ($MONTHS{$1}, $2, $3, $4, $5, $6);
  }

  # Invalid
  else { return $self }

  # Prevent crash
  my $epoch = eval { timegm($s, $m, $h, $day, $month, $year) };
  return
    defined $epoch && ($epoch += $offset) >= 0 ? $self->epoch($epoch) : $self;
}

sub to_datetime {

  # RFC 3339 (1994-11-06T08:49:37Z)
  my ($s, $m, $h, $day, $month, $year) = gmtime(shift->epoch // time);
  return sprintf '%04d-%02d-%02dT%02d:%02d:%02dZ', $year + 1900, $month + 1,
    $day, $h, $m, $s;
}

sub to_string {

  # RFC 7231 (Sun, 06 Nov 1994 08:49:37 GMT)
  my ($s, $m, $h, $mday, $month, $year, $wday) = gmtime(shift->epoch // time);
  return sprintf '%s, %02d %s %04d %02d:%02d:%02d GMT', $DAYS[$wday], $mday,
    $MONTHS[$month], $year + 1900, $h, $m, $s;
}

1;

=encoding utf8

=head1 NAME

Mojo::Date - HTTP date

=head1 SYNOPSIS

  use Mojo::Date;

  # Parse
  my $date = Mojo::Date->new('Sun, 06 Nov 1994 08:49:37 GMT');
  say $date->epoch;

  # Build
  my $date = Mojo::Date->new(time);
  say "$date";

=head1 DESCRIPTION

L<Mojo::Date> implements HTTP date and time functions based on
L<RFC 7230|http://tools.ietf.org/html/rfc7230>,
L<RFC 7231|http://tools.ietf.org/html/rfc7231> and
L<RFC 3339|http://tools.ietf.org/html/rfc3339>.

  Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
  Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036
  Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format
  1994-11-06T08:49:37Z           ; RFC 3339

=head1 ATTRIBUTES

L<Mojo::Date> implements the following attributes.

=head2 epoch

  my $epoch = $date->epoch;
  $date     = $date->epoch(784111777);

Epoch seconds.

=head1 METHODS

L<Mojo::Date> inherits all methods from L<Mojo::Base> and implements the
following new ones.

=head2 new

  my $date = Mojo::Date->new;
  my $date = Mojo::Date->new('Sun Nov  6 08:49:37 1994');

Construct a new L<Mojo::Date> object and L</"parse"> date if necessary.

=head2 parse

  $date = $date->parse('Sun Nov  6 08:49:37 1994');

Parse date.

  # Epoch
  say Mojo::Date->new('784111777')->epoch;

  # RFC 822/1123
  say Mojo::Date->new('Sun, 06 Nov 1994 08:49:37 GMT')->epoch;

  # RFC 850/1036
  say Mojo::Date->new('Sunday, 06-Nov-94 08:49:37 GMT')->epoch;

  # Ansi C asctime()
  say Mojo::Date->new('Sun Nov  6 08:49:37 1994')->epoch;

  # RFC 3339
  say Mojo::Date->new('1994-11-06T08:49:37Z')->epoch;

=head2 to_datetime

  my $str = $date->to_datetime;

Render L<RFC 3339|http://tools.ietf.org/html/rfc3339> date and time.

  # "1994-11-06T08:49:37Z"
  Mojo::Date->new(784111777)->to_datetime;

=head2 to_string

  my $str = $date->to_string;

Render date suitable for HTTP messages.

  # "Sun, 06 Nov 1994 08:49:37 GMT"
  Mojo::Date->new(784111777)->to_string;

=head1 OPERATORS

L<Mojo::Date> overloads the following operators.

=head2 bool

  my $bool = !!$date;

Always true.

=head2 stringify

  my $str = "$date";

Alias for L</to_string>.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
