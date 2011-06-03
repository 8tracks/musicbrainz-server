package MusicBrainz::Server::Controller::WS::js::Label;
use Moose;
BEGIN { extends 'MusicBrainz::Server::ControllerBase::WS::js' }

with 'MusicBrainz::Server::Controller::WS::js::Role::AliasAutocompletion';

my $ws_defs = Data::OptList::mkopt([
    "label" => {
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

sub type { 'label' }

sub search : Path('/ws/js/label') {
    my ($self, $c) = @_;
    $self->dispatch_search($c);
}

1;

