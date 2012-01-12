package MusicBrainz::Server::Controller::WS::js::ReleaseGroup;
use Moose;
BEGIN { extends 'MusicBrainz::Server::ControllerBase::WS::js' }

with 'MusicBrainz::Server::Controller::WS::js::Role::Autocompletion::WithArtistCredits';

my $ws_defs = Data::OptList::mkopt([
    "release-group" => {
        method   => 'GET',
        required => [ qw(q) ],
        optional => [ qw(direct limit page timestamp) ]
    }
]);

with 'MusicBrainz::Server::WebService::Validator' =>
{
     defs => $ws_defs,
     version => 'js',
     default_serialization_type => 'json',
};

sub type { 'release_group' }

sub serialization_routine { 'autocomplete_release_group' }

sub search : Path('/ws/js/release-group') {
    my ($self, $c) = @_;
    $self->dispatch_search($c);
}

after _load_entities => sub {
    my ($self, $c, @entities) = @_;
    $c->model ('ReleaseGroupType')->load (@entities);
};

1;

