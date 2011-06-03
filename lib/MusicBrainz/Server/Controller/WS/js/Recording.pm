package MusicBrainz::Server::Controller::WS::js::Recording;
use Moose;
BEGIN { extends 'MusicBrainz::Server::ControllerBase::WS::js' }

with 'MusicBrainz::Server::Controller::WS::js::Role::Autocompletion::WithArtistCredits';

my $ws_defs = Data::OptList::mkopt([
    "recording" => {
        method   => 'GET',
        required => [ qw(q) ],
        optional => [ qw(a r direct limit page timestamp) ]
    }
]);

with 'MusicBrainz::Server::WebService::Validator' =>
{
     defs => $ws_defs,
     version => 'js',
     default_serialization_type => 'json',
};

sub type { 'recording' }

sub search : Path('/ws/js/work') {
    my ($self, $c) = @_;
    $self->dispatch_search($c);
}

sub _do_direct_search {
    my ($self, $c, $query, $offset, $limit) = @_;

    my $where = {};
    if (my $artist = $c->req->query_params->{artist}) {
        $where->{artist} = $artist;
    }

    return $c->model ('Search')->search ('recording', $query, $limit, $offset, $where);
}

after _load_entities => sub {
    my ($self, $c, @recordings) = @_;
    $c->model('ISRC')->load_for_recordings (@recordings);
};

sub _format_output {
    my ($self, $c, @entities) = @_;
    my %appears_on = $c->model('Recording')->appears_on (\@entities, 3);

    return map {
        {
            recording => $_,
            appears_on => $appears_on{$_->id}
        }
    } @entities;
}

around _form_indexed_query => sub {
    my ($orig, $self) = splice(@_, 0, 2);
    my ($query, $c) = @_;
    $query = $self->$orig(@_);

    my $lucene_query = "recording:($query*)";
    if (my $artist = $c->req->query_params->{a}) {
        $lucene_query .= " AND artist:($artist)";
    }

    return $lucene_query;
};

1;

