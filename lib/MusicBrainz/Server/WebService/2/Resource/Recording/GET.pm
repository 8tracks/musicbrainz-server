package MusicBrainz::Server::WebService::2::Resource::Recording::GET;
use Moose;
use namespace::clean;

use Data::TreeValidator::Sugar qw( branch leaf );
use HTTP::Throwable::Factory qw( http_throw );
use MusicBrainz::Server::WebService::Validation qw( gid inc );

with 'Sloth::Method';

has request_data_validator => (
    is => 'ro',
    default => sub {
        branch {
            gid => gid,
            inc => inc(
                qw( isrcs puids ),
                artists => [qw( aliases )],
                releases => [qw( discids media )]
            )
        }
    }
);

sub execute {
    my ($self, $input) = @_;
    my $recording = $self->c->model('Recording')->get_by_gid($input->{gid})
        or http_throw('NotFound');

    my %ret = (
        entity => $recording,
        inline => []
    );

    my @load_ac = $recording;

    if ($input->{inc}{releases}) {
        my ($releases) = $self->c->model('Release')->find_by_recording(
            $recording->id, 25, 0
        );

        push @{ $ret{inline} },
            bless($releases, 'MusicBrainz::Server::Entity::ReleaseList');

        push @load_ac, @$releases if $input->{inc}{artists};
    }

    if ($input->{inc}{artists}) {
        $self->c->model('ArtistCredit')->load(@load_ac);
    }

    if ($input->{inc}{isrcs}) {
        push @{ $ret{inline} }, bless [
            $self->c->model('ISRC')->find_by_recording($recording->id)
        ], 'MusicBrainz::Server::Entity::ISRCList';
    }

    return \%ret;
}

1;
