use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use t::TestFlavor;
use Test::Requires {
	'String::CamelCase' => '0.02',
	'Mouse'             => '0.95', # Mouse::Util
	'Teng'                            => '0.18',
	'DBD::SQLite'                     => '1.33',
    'Plack::Session'                  => '0.14',
    'Module::Find'                    => '0.10',
    'Test::WWW::Mechanize::PSGI'      => 0,
    'Module::Functions'               => '0',
    'HTML::FillInForm::Lite'          => 0,
};

test_flavor(sub {
    ok(!-e 'xxx');
    ok(!-e 'yyy');
    my @files = (<Amon2::*>);
    is(0+@files, 0);

    system('sqlite3 db/test.db < sql/sqlite.sql');
    system('sqlite3 db/development.db < sql/sqlite.sql');

    for my $dir (qw(tmpl/ tmpl/pc tmpl/admin/ static/pc static/admin)) {
        ok(-d $dir, $dir);
    }
	for my $file (qw(Build.PL lib/My/App.pm t/Util.pm .proverc tmpl/pc/error.tx tmpl/admin/error.tx)) {
		ok(-f $file, "$file exists");
	}
    for my $f (qw(lib/My/App/Web.pm lib/My/App/Web/ tmpl/index.tx)) {
        ok(!-e $f, "There is no $f");
    }

    for my $type (qw(PC Admin)) {
        open my $pfh, '>', "lib/My/App/$type/C/Error.pm" or die "$type: $!";
        print $pfh sprintf(<<'...', $type);
package My::App::%s::C::Error;
use strict;

sub error {
    my ($class, $c) = @_;
    return $c->show_error('Oops!');
}

1;
...
        close $pfh;
    }

    for my $type (qw(pc admin)) {
        my $f = "${type}.psgi";
        my $buff = << "...";
\$SIG{__WARN__} = sub { die 'Warned! ' . shift };
@{[slurp($f)]}
...
        open my $fh, '>', $f;
        print $fh $buff;
        close $fh;
    }

    my $app = Plack::Util::load_psgi('app.psgi');
    my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
    {
        my $res = $mech->get('http://localhost/error/error');
        is($res->code, 500);
        like($res->content, qr{An error});
        like($res->content, qr{Oops});
    }
    {
        my $res = $mech->get('http://localhost/admin/error/error');
        is($res->code, 401);
    }
    {
        $mech->credentials('admin', 'admin');
        my $res = $mech->get('http://localhost/admin/error/error');
        is($res->code, 500);
        like($res->content, qr{An error});
        like($res->content, qr{Oops});
    };

    like(slurp('tmpl/pc/include/layout.tx'), qr{jquery}, 'loads jquery');
}, 'Large');

done_testing;

