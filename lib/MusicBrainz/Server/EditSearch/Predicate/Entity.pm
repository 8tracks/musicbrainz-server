use MusicBrainz::Server::EditSearch::Predicate::LinkedEntity;
use MusicBrainz::Server::EditSearch::Predicate::SubscribedEntity;

package MusicBrainz::Server::EditSearch::Predicate::Artist;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'artist' };
with 'MusicBrainz::Server::EditSearch::Predicate::SubscribedEntity' => { type => 'artist' };
with 'MusicBrainz::Server::EditSearch::Predicate';

package MusicBrainz::Server::EditSearch::Predicate::Label;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'label' };
with 'MusicBrainz::Server::EditSearch::Predicate::SubscribedEntity' => { type => 'label' };
with 'MusicBrainz::Server::EditSearch::Predicate';

package MusicBrainz::Server::EditSearch::Predicate::Recording;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'recording' };
with 'MusicBrainz::Server::EditSearch::Predicate';

package MusicBrainz::Server::EditSearch::Predicate::Release;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'release' };
with 'MusicBrainz::Server::EditSearch::Predicate';

package MusicBrainz::Server::EditSearch::Predicate::ReleaseGroup;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'release_group' };
with 'MusicBrainz::Server::EditSearch::Predicate';

package MusicBrainz::Server::EditSearch::Predicate::Work;
use Moose;
with 'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => { type => 'work' };
with 'MusicBrainz::Server::EditSearch::Predicate';
