# signed int64
package Parse::Evtx2::VariantType::Type0x09;
use base qw( Parse::Evtx2::VariantType );

use Carp::Assert;
use Math::BigInt;

sub parse_self {
	my $self = shift;
	
	assert($self->{'Length'} >= 8);
	my ($low, $high) = unpack("Ll", 
		$self->{'Chunk'}->get_data($self->{'Start'}, 8));
	my $int64 = Math::BigInt->new($high)->blsft(32)->bxor($low);
	$self->{'String'} = $int64->bstr();
	$self->{'Length'} = 8;
};


sub release {
	my $self = shift;
	
	undef $self->{'String'};
	$self->SUPER::release();
}

1;
