package MusicBrainz::Server::Controller::WS::2::Label;
use Moose;
BEGIN { extends 'MusicBrainz::Server::ControllerBase::WS::2' }

use aliased 'MusicBrainz::Server::WebService::WebServiceStash';
use MusicBrainz::Server::Data::Utils qw( partial_date_from_string partial_date_to_hash );
use Carp;
use Readonly;
use Try::Tiny;

my $ws_defs = Data::OptList::mkopt([
     label => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     label => {
                         method   => 'GET',
                         linked   => [ qw(release) ],
                         inc      => [ qw(aliases
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ],
     },
     label => {
                         method   => 'GET',
                         inc      => [ qw(releases aliases
                                          _relations tags user-tags ratings user-ratings) ],
     },
     label => {
                         method   => 'PUT',
                         optional => [ qw(client) ],
     },
]);

with 'MusicBrainz::Server::WebService::Validator' =>
{
     defs => $ws_defs,
};

with 'MusicBrainz::Server::Controller::Role::Load' => {
    model => 'Label'
};

Readonly our $MAX_ITEMS => 25;

sub base : Chained('root') PathPart('label') CaptureArgs(0) { }

sub label_toplevel
{
    my ($self, $c, $stash, $label) = @_;

    my $opts = $stash->store ($label);

    $self->linked_labels ($c, $stash, [ $label ]);

    $c->model('LabelType')->load($label);
    $c->model('Country')->load($label);

    if ($c->stash->{inc}->aliases)
    {
        my $aliases = $c->model('Label')->alias->find_by_entity_id($label->id);
        $opts->{aliases} = $aliases;
    }

    if ($c->stash->{inc}->releases)
    {
        my @results = $c->model('Release')->find_by_label(
            $label->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        $opts->{releases} = $self->make_list (@results);

        $self->linked_releases ($c, $stash, $opts->{releases}->{items});
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $label);
    }
}

sub label : Chained('load') PathPart('')
{
    my ($self, $c) = @_;

    $c->detach('label_edit') if $c->request->method eq 'PUT';

    my $label = $c->stash->{entity};

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($label);

    $self->label_toplevel ($c, $stash, $label);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('label', $label, $c->stash->{inc}, $stash));
}

sub label_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $labels;
    my $total;
    if ($resource eq 'release')
    {
        my $release = $c->model('Release')->get_by_gid($id);
        $c->detach('not_found') unless ($release);

        my @tmp = $c->model('Label')->find_by_release ($release->id, $limit, $offset);
        $labels = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $labels->{items} })
    {
        $self->label_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('label-list', $labels, $c->stash->{inc}, $stash));
}

sub label_search : Chained('root') PathPart('label') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('label_browse') if ($c->stash->{linked});
    $self->_search ($c, 'label');
}

sub no_changes : Private
{
    my ($self, $c) = @_;

    $c->response->status(409);
    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body(
        $c->stash->{serializer}->output_error(
            "The document you submitted is identical to the entity in the database."));
    $c->detach;
}

sub label_edit : Private
{
    my ($self, $c) = @_;

    my $label = $c->stash->{entity};

    use Data::TreeValidator::Sugar qw( branch leaf );
    use Data::TreeValidator::Constraints qw( required );
    use MusicBrainz::Data::TreeValidator::Constraints qw( integer partial_date );
    use MusicBrainz::Data::TreeValidator::Transformations qw( collapse_whitespace );

    my $label_validator = branch {
        name => leaf( constraints => [ required ], transformations => [ collapse_whitespace ] ),
        sort_name => leaf( constraints => [ required ], transformations => [ collapse_whitespace ] ),
        lifespan => branch {
            begin => leaf( constraints => [ partial_date ] ),
            end =>  leaf( constraints => [ partial_date ] ),
        }
    };


    use JSON::Any;
    use Data::Dumper;
    use MusicBrainz::Server::Constants qw( $EDIT_LABEL_EDIT );

    my $json = JSON::Any->new;
    my $fh = $c->req->body;
    my $body = $json->decode (do { local $/ = undef; <$fh> });

    my $result = $label_validator->process($body);
    if (!$result->valid) {
        $c->response->status(400); # hm, is there a more specific code which is appropriate here?
        $c->res->body($c->stash->{serializer}->serialize_validation_errors ($result));
        $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
        $c->detach;
    }

    my %options = (
        name => $body->{name},
        sort_name => $body->{sort_name},
    );

    if ($body->{lifespan})
    {
        $options{begin_date} = partial_date_to_hash (
            partial_date_from_string ($body->{lifespan}->{begin})) if $body->{lifespan}->{begin};
        $options{end_date}  = partial_date_to_hash (
            partial_date_from_string ($body->{lifespan}->{end})) if $body->{lifespan}->{end};
    }

    my $edit;
    try {
        $edit = $c->model('Edit')->create(
            edit_type => $EDIT_LABEL_EDIT,
            editor_id => $c->user->id,
            privileges => $c->user->privileges,
            to_edit => $label,
            %options
        );
    }
    catch {
        if (ref($_) eq 'MusicBrainz::Server::Edit::Exceptions::NoChanges') {
            $c->detach('no_changes');
        }
        else {
            use Data::Dumper;
            croak "The edit could not be created.\n" .
                "Submitted document: " . Dumper($body) . "\n" .
                "Exception:" . Dumper($_);
        }
    };

    die "krak" unless $edit;

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body("created edit: http://localhost:3000/edit/".$edit->id."\n");
}

__PACKAGE__->meta->make_immutable;
1;

