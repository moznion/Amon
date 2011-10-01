use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../../lib/";
use Test::More;
use Amon2::Setup;
use File::Temp qw/tempdir/;
use App::Prove;
use File::Basename;
use Cwd;
use t::Util qw(slurp);

note $^X;
note $];

my $orig_dir = Cwd::getcwd();
my $dir = tempdir(CLEANUP => 1);
chdir($dir);

my $setup = Amon2::Setup->new(module => 'My::App');
$setup->run(['Basic']);

ok(-d 'static/js/', 'js dir');
ok(-d 'static/css/', 'css dir');
ok(-d 'static/img/', 'img dir');
ok(-f 'lib/My/App.pm', 'lib/My/App.pm exists');
ok((do 'lib/My/App.pm'), 'lib/My/App.pm is valid') or do {
    diag $@;
    diag do {
        open my $fh, '<', 'lib/My/App.pm' or die;
        local $/; <$fh>;
    };
};
is( scalar( my @files = glob('static/js/jquery-*.js') ), 1 );
like(slurp('lib/My/App/Web.pm'), qr{Web::FillInFormLite});
like(slurp('lib/My/App/Web.pm'), qr{Web::HTTPSession});

{
    my $_00_compile = slurp("t/00_compile.t");
    like $_00_compile, qr(My::App);
    like $_00_compile, qr(My::App::Web);
    like $_00_compile, qr(My::App::Web::Dispatcher);
};

my $libpath = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', '..', 'lib'));
my $app = App::Prove->new();
$app->process_args('-Ilib', "-I$libpath", <t/*.t>);
ok($app->run);

chdir($orig_dir);
undef $dir;

done_testing;

