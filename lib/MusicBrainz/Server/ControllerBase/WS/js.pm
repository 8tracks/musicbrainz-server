package MusicBrainz::Server::ControllerBase::WS::js;
use Moose;
use MusicBrainz::Server::WebService::AcceptHeader;
use MusicBrainz::Server::WebService::JSONSerializer;

BEGIN { extends 'MusicBrainz::Server::Controller' }

with 'MusicBrainz::Server::WebService::AcceptHeader' =>
{
    serializers => [ 'MusicBrainz::Server::WebService::JSONSerializer' ]
};

sub bad_req : Private
{
    my ($self, $c) = @_;
    $c->res->status(400);
    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->output_error($c->stash->{error}));
}

sub begin : Private {
    my ($self, $c) = @_;
    $self->validate($c) or $c->detach('bad_req');
}

# Don't render with TT
sub end : Private { }

1;
