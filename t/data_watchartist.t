use strict;
use warnings;
use Test::Fatal;
use Test::More;
use MusicBrainz::Server::Test;

my $c = MusicBrainz::Server::Test->create_test_context;
MusicBrainz::Server::Test->prepare_test_database($c, '+watch');

my $sql = Sql->new($c->dbh);

subtest 'Find watched artists for editors watching artists' => sub {
    my @watching = $c->model('WatchArtist')->find_watched_artists(1);
    is(@watching => 2, 'watching 2 artists');
    is_watching('Spor', 1, @watching);
    is_watching('Break', 2, @watching);
};

subtest 'Find watched artists where an editor is not watching anyone' => sub {
    my @watching = $c->model('WatchArtist')->find_watched_artists(2);
    is(@watching => 0, 'Editor #2 is not watching any artists');
};

subtest 'Can add new artists to the watch list' => sub {
    $c->model('WatchArtist')->watch_artist(
        artist_id => 3, editor_id => 2
    );

    my @watching = $c->model('WatchArtist')->find_watched_artists(2);
    is(@watching => 1, 'Editor #2 is now watching 1 artist');
    is_watching('Tosca', 3, @watching);
};

subtest 'Watching a watched artist does not crash' => sub {
    ok !exception {
        $c->model('WatchArtist')->watch_artist(
            artist_id => 3, editor_id => 2
        );
    }, 'editor #2 watched artist #3 without an exception';
};

subtest 'is_watching' => sub {
    ok($c->model('WatchArtist')->is_watching(
        artist_id => 3, editor_id => 2),
        'editor #2 is watching artist #3');
    ok(!$c->model('WatchArtist')->is_watching(
        artist_id => 1, editor_id => 2),
        'editor #2 is not watching artist #1');
};

subtest 'stop_watching' => sub {
    $c->model('WatchArtist')->stop_watching_artist(
        artist_ids => [ 3 ], editor_id => 2
    );

    ok(!$c->model('WatchArtist')->is_watching(
        artist_id => 3, editor_id => 2),
        'editor #2 is no longer watching artist #3');
};

subtest 'find_new_releases' => sub {
    subtest 'Find releases in the future' => sub {
        $sql->begin;
        $sql->do('UPDATE editor_watch_preferences SET last_checked = NOW()');
        $sql->do("UPDATE release_meta SET date_added = NOW() + '@ 1 week'::INTERVAL");

        my @releases = $c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 1, 'found one release');
        $sql->rollback;
    };

    subtest 'Find releases after last_checked' => sub {
        $sql->begin;
        $sql->do("UPDATE release_meta SET date_added = NOW() - '@ 1 week'::INTERVAL");

        my @releases = $c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 0, 'found no releases');
        $sql->rollback;
    };

    subtest 'Do not notify of newly added releases released in the past' => sub {
        $sql->begin;
        $sql->do('UPDATE release SET date_year = 2009');
        $sql->do("UPDATE release_meta SET date_added = NOW() + '@ 1 week'::INTERVAL");
        my @releases = $c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 0, 'found no releases');
        $sql->rollback;
    };
};

subtest 'find_editors_to_notify' => sub {
    my @editors = $c->model('WatchArtist')->find_editors_to_notify;
    is(@editors => 1, '1 editors have watch lists');
    ok((grep { $_->name eq 'acid2' } @editors), 'acid2 has a watchlist');
};

subtest 'find_editors_to_notify ignores editors not requesting emails' => sub {
    $sql->auto_commit(1);
    $sql->do('UPDATE editor_watch_preferences SET notify_via_email = FALSE
               WHERE editor = 1');

    my @editors = $c->model('WatchArtist')->find_editors_to_notify;
    is(@editors => 0, '0 editors to notify');
};

subtest 'update_last_checked' => sub {
    $sql->auto_commit(1);
    $sql->do("UPDATE editor_watch_preferences
                 SET last_checked = NOW() - '@ 1 week'::INTERVAL");

    $c->model('WatchArtist')->update_last_checked;

    ok($sql->select_single_value(
            "SELECT 1 FROM editor_watch_preferences
              WHERE last_checked > NOW() - '@ 1 week'::INTERVAL"),
        'last_checked has moved forward in time');
};

subtest 'Default preferences' => sub {
    my $prefs = $c->model('WatchArtist')->load_preferences(2);
    
    is($prefs->notification_timeframe->in_units('days') => 7,
        'default notification timeframe is 7 days');
    is($prefs->notify_via_email => 1,
        'will notify via email by default');

    is($prefs->all_types => 1, 'will watch for albums by default');
    ok((grep { $_->id => 2 } $prefs->all_types),
        'will watch for albums by default');

    is($prefs->all_statuses => 1,
        'will watch for official releases by default');
    ok((grep { $_->id => 1 } $prefs->all_statuses),
        'will watch for official releases by default');
};

subtest 'Saving preferences' => sub {
    $c->model('WatchArtist')->save_preferences(
        2, {
            notification_timeframe => 14,
            notify_via_email => 0,
            type_id => [ 1, 2 ],
            status_id => [ 3 ]
        });

    my $prefs = $c->model('WatchArtist')->load_preferences(2);
    
    is($prefs->notification_timeframe->in_units('days') => 14,
        'notification timeframe is 14 days');
    is($prefs->notify_via_email => 0,
        'will not notify via email');

    is($prefs->all_types => 2);
    ok((grep { $_->id => 1 } $prefs->all_types));
    ok((grep { $_->id => 2 } $prefs->all_types));

    is($prefs->all_statuses => 1);
    ok((grep { $_->id => 3 } $prefs->all_statuses));
};

done_testing;

sub is_watching {
    my ($name, $artist_id, @watching) = @_;
    subtest "Is watching $name" => sub {
        ok((grep { $_->name eq $name } @watching),
            '...artist.name');
        ok((grep { $_->id == $artist_id } @watching),
            '...artist_id');
    };
}