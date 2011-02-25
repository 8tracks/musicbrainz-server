package MusicBrainz::Server::WebService::Representation::2::XML;
use Moose;

use HTTP::Throwable::Factory qw( http_throw );
use Module::Pluggable::Object;
use Scalar::Util 'blessed';

has serializers => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        my $self = shift;
        my $prefix = 'MusicBrainz::Server::WebService::Representation::2::XML';
        return {
            map {
                my ($name) = $_ =~ /${prefix}::(.*)/;
                $name => $_->new( parent => $self )
            } grep { $_->isa('Moose::Object') } Module::Pluggable::Object->new(
                search_path => $prefix,
                require => 1
            )->plugins
        };
    },
    traits => [ 'Hash' ],
    handles => {
        serializer => 'get'
    }
);

sub serialize {
    my ($self, $resource) = @_;
    return join("\n",
        '<?xml version="1.0"?>',
        '<metadata>',
        $self->serialize_resource($resource),
        '</metadata>'
    );
}

sub serialize_resource {
    my ($self, $resource) = @_;
    if (!$resource) {
        return;
    }
    if (blessed($resource)) {
        return $self->_get_serializer($resource)
            ->serialize_resource($resource);
    }
    elsif (ref($resource) eq 'HASH') {
        my $entity = delete $resource->{entity}
            or die 'Could not find entity to serialize';
        return $self->_get_serializer($entity)
            ->serialize_resource($entity, %$resource);
    }
}

sub _get_serializer {
    my ($self, $for) = @_;
    $for = ref($for);
    my ($name) = $for =~ /^MusicBrainz::Server::Entity::(.*)/;
    my $serializer = $self->serializer($name)
        or http_throw('UnsupportedMediaType' => {
            message => "No serializer for $for"
        });

    return $serializer;
}

1;
