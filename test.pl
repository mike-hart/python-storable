#!/usr/bin/perl

use lib 'perl-modules';
use strict; use warnings;

use FindBin;
use lib "$FindBin::Bin";

use Fcntl ":seek";
use Fatal qw(open);
use File::Path qw(mkpath);
use Config;

use Storable qw(nfreeze freeze nstore store);

# make the base path
my $base =
    "$FindBin::Bin/tests/resources/$Config{myarchname}/$Storable::VERSION";
mkpath($base);
my $filenames = {};
my $count     = 0;

# very simple tests: note, for storable. all a ref
save_sample('scalar',        \'Some scalar, less then 255 bytes size');
save_sample('empty_hash',    {});
save_sample('empty_array',   []);
save_sample('double',        \7.9);
save_sample('undef',         \undef);

# large scalars are different in storable, make one that is bigger than
# 255 bytes, (one byte size denomination)
my $lscalar = 'x' x 1024;
save_sample('large_scalar',  \$lscalar);

# more complex tests, still nothing fancy: just a hash, hash in hash,
# array in a hash, array in array, hash in array. All with multiple elements
# too of course, and combined as much as possible.
save_sample('simple_hash01', {aa => 'bb'});
save_sample('simple_hash02', {aa => {bb => 'cc'}});
save_sample('simple_hash03', {aa => {bb => 7.8}});
save_sample('simple_hash04', {aa => []});
save_sample('simple_hash05', {aa => ['bb', 6.77]});
save_sample('simple_hash06', {aa => 'bb', 0.667 => 'test', abc => 66.77});
save_sample('simple_hash07', {aa => undef, bb => undef, undef => undef});
save_sample('simple_hash08', [undef, {}, 8.9, 'aa', undef, undef]);
save_sample('simple_hash09', [
    [0.6, 0.7], {a => 'b'}, undef, ['uu','ii', [undef], [7,8,9,{}]]
]);


# In python, there are no refs, hence, this must all be the same: all just
# an array
my @array = ();
save_sample('ref01', \@array);
save_sample('ref02', \\@array);
save_sample('ref03', \\\@array);
save_sample('ref04', \\\\@array);

{
    # same object, added + shared multiple times in an array. In python,
    # that is preferrably also the same object. This is possible too. Note
    # that this is a reference SX_OBJECT test already too
    $array[5] = 'x';
    my $x = [undef, \@array, \@array, \\@array, \\@array];
    save_sample('complex01', $x);
}

{
    # in perl, a scalar copy is a scalar copy, hence 2 different objects
    # in python
    my $x = {aa => 'bb'};
    $x->{cc} = $x->{aa};
    save_sample('complex02', $x);
}

{
    # .. but a ref must make it the same object. NOTE: in python, everything
    # is a ref, hence, no extra ref/deref is possible. This basically needs
    # to give the same result in python as the previous sample.
    my $x = {aa => 'bb'};
    $x->{cc} = \$x->{aa};
    save_sample('complex03', $x);
}

{
    # same thing with an array of course. The 'a', 'b', 'c' appear to be tied
    # scalars in a storable too.
    my $x = [undef, 6, [qw(a b c), {'uu' => 5.6}]];
    $x->[6] = \$x->[0];
    $x->[7] = \$x->[1];
    $x->[5] =  $x->[2];
    $x->[4] =  $x->[2][3];
    $x->[3] =  $x->[2][3];
    save_sample('complex04', $x);

    # a small circular one: hash with ref to its own
    $x->[2][3]{ii} = $x->[2][3];
    save_sample('complex05', $x);

    # a circular one over the entire structure.... niiiice.
    $x->[2][3]{oo} = $x;
    save_sample('complex06', $x);
}

{
    # small circular one with an array
    my $x = [undef, 'yy'];
    push @{$x}, $x;
    save_sample('complex07', $x);
}

{
    # same but try to make 'a', 'b', 'c' not tied scalars
    my $x = [undef, 6, ['a', 'b', 'c', {'uu' => 5.6}]];
    $x->[6] = \$x->[0];
    $x->[7] = \$x->[1];
    $x->[5] =  $x->[2];
    $x->[4] =  $x->[2][3];
    $x->[3] =  $x->[2][3];
    save_sample('complex08', $x);
}

{
    # bless test: scalar, $test is undef => will result in 'None'
    my $x = bless \my $test, 'Aa::Bb';
    save_sample('bless01', $x);
}

{
    # bless test: scalar, $test is 'Test' => will result in 'Test'
    my $test = 'Test';
    my $x = bless \$test, 'Aa::Bb';
    save_sample('bless02', $x);
}

{
    # bless test: array
    my $x = bless [], 'Aa::Bb';
    save_sample('bless03', $x);
}

{
    # bless test: hash
    my $x = bless {}, 'Aa::Bb';
    save_sample('bless04', $x);
}

{
    # bless test: ref to a ref
    my $x = bless \{}, 'Aa::Bb';
    save_sample('bless05', $x);
}

{
    # bless test: more than one bless, all the same one though
    my $x = bless [
        bless({}, 'Aa::Bb'),
        bless([], 'Aa::Bb'),
        bless(\[], 'Aa::Bb'),
        bless(\my $test1, 'Aa::Bb'),
        bless(\my $test2, 'Aa::Cc'),
        bless(['TestA'], 'Aa::Cc'),
        bless(['TestB'], 'Aa::Dd'),
        bless(['TestC'], 'Aa::Cc'),
        bless(['TestD', bless({0=>bless([], 'Aa::Bb')}, 'Aa::Cc')], 'Aa::Bb'),
    ], 'Aa::Bb';
    save_sample('bless06', $x);
}

{
    # bless test: bless without a package
    my $x = bless [];
    save_sample('bless07', $x);
}

{
    # utf-8 test
    my $x = "\x{263A}";
    save_sample('utf8test01', \$x);
}

{
    # utf-8 test: large scalar
    my $x = "\x{263A}" x 1024;
    save_sample('utf8test02', \$x);
}

{
    # SX_HOOK test: simple array-return
    package Test;
    sub new {bless {-test => [], -testscalar => 'Hello world'}, $_[0]};
    sub STORABLE_freeze {
        return 1, $_[0]->{-test}, \$_[0]->{-testscalar};
    }

    package main;

    my $h = Test->new();
    save_sample('medium_complex_hook_test', $h);
}

{
    # SX_HOOK test: large simple array-return
    package Test2;
    sub new {bless {}, $_[0]};
    sub STORABLE_freeze {
        return 0, map {\$_[0]->{$_}} (('x') x 300);
    }

    package main;

    my $h = Test2->new();
    save_sample('medium_complex_hook_test_large_array', $h);
}

{
    # SX_HOOK test: multiple test: same scalar
    package Test3;
    sub new {bless {}, $_[0]};
    sub STORABLE_freeze {
        return 0, \'some scalar var';
    }

    package main;

    my $x = [ Test3->new(), Test3->new() ];
    save_sample('medium_complex_multiple_hook_test', $x);
}

{
    # SX_HOOK test: multiple test: different scalar
    package Test4;
    sub new {bless {-v => $_[1]}, $_[0]};
    sub STORABLE_freeze {
        return 0, \$_[0]->{-v};
    }

    package main;

    my $x = [ Test4->new('var 1'), Test4->new('var 2') ];
    save_sample('medium_complex_multiple_hook_test2', $x);
}

{
    # SX_HOOK test: array
    package Test6;
    sub new {bless [$_[1]], $_[0]};
    sub STORABLE_freeze {
        return 0, \$_[0][0];
    }

    package main;

    my $x = [ Test6->new('avar 1'), Test6->new('avar 2') ];
    save_sample('medium_hook_array_test1', $x);
}

{
    # SX_HOOK test: multiple test: own serialized + array
    package Test7;
    sub new {bless [$_[1]], $_[0]};
    sub STORABLE_freeze {
        return "SERIALIZED:$_[0]->[0]:SERIALIZED", \$_[0][0];
    }

    package main;

    my $x = [ Test7->new('svar 1'), Test7->new('svar 2') ];
    save_sample('medium_own_serialized1', $x);
}

{
    # SX_HOOK test: test: scalar
    package Test8;
    sub new {bless \$_[1], $_[0]};
    sub STORABLE_freeze {
        return 0, $_[0], \10, \'Test string';
    }

    package main;

    my $x = Test8->new('scalar var 1');
    save_sample('medium_hook_scalar', $x);
}

{
    # SX_HOOK test: test: scalar, large serialize string
    package Test9;
    sub new {bless \$_[1], $_[0]};
    sub STORABLE_freeze {
        return 'x'x300, $_[0], \10, \'Test string';
    }

    package main;

    my $x = Test9->new('large scalar var 1');
    save_sample('large_frozen_string_hook', $x);
}

{
    # SX_HOOK test: array
    package Test10;
    sub new {bless [$_[1]], $_[0]};
    sub STORABLE_freeze {
        return 0, \$_[0][0];
    }

    package main;

    my $b = Test10->new('scalar var 1');
    my $x = [
        $b,
        Test10->new('scalar var 2'),
        Test10->new('scalar var 3'),
        $b
    ];
    save_sample('medium_hook_array_three', $x);
}

{
    save_sample('integer',    \44556677);
}

{
    save_sample('biginteger', \112233445566778899);
}

{
    save_sample('integer_array', [44556677, 556677]);
}

{
    save_sample('integer_hash',  {44556677 => 'a', 556677 => 'b'});
}

{
    # Immortal test: undef
    save_sample('immortal_test01_undef', \undef());
}

{
    # Immortal test: yes
    save_sample('immortal_test02_yes', \!0);
}

{
    # Immortal test: no
    #save_sample('immortal_test03_no', \!1);
    # This _would_ work if !1 wasn't a dualvar... :|
    # Was dualvar added after PL_sv_(yes|no)?
    # How do i get an instance of PL_sv_no that isn't a dualvar such that
    # storable will write it and not the scalar?
    # For now, write out something of the same expected length, then modify it
    # to what it should be.
    my @names = save_sample('immortal_test03_no', \!0);
    my $sx_sv_no = "\x{10}";
    for my $filename (@names) {
        open(my $fh, '+<:raw', $filename) or die;
        seek($fh, -1, SEEK_END);
        print $fh $sx_sv_no;
        close $fh;
    }
}

{
    # Version test (short)
    my $x = v5.6.0.0.35;
    save_sample('version_test01_short', \$x);
}

{
    # Version test (long)
    my $x = v5.6.0.0.35555555555.5555555555.555555555.555555555.555555555.5555555555.5555555555.5555555.555555555.55555555.555555555.55555555.555555555.555555555.555555555.5555555555.5555555555.5555555.555555555.33333333.333333333.33333333.333333333.333333333.333333333.1111111111;
    save_sample('version_test02_long', \$x);
}

sub save_sample {
    my ($what, $data) = @_;
    $count++;
    my @filenames = ();
    for my $type (qw(freeze nfreeze)){
        my $filename = generate_filename($what, $count, $type);
        push @filenames, $filename;
        my $x;
        {
            no strict 'refs';
            $x = &$type($data);
        }
        open(my $fh, '>', $filename);
        print $fh $x;
        close($fh);
    }

    for my $type (qw(store nstore)){
        my $filename = generate_filename($what, $count, $type);
        push @filenames, $filename;
        my $x;
        {
            no strict 'refs';
            $x = &$type($data, $filename);
        }
    }
    return @filenames;
}

sub generate_filename {
    my ($what, $count, $type) = @_;
    my $filename =
        "$base/".sprintf('%03d', $count)."_${what}_".
        "${Storable::VERSION}_$Config{myarchname}_${type}.storable";

    print "saving sample $what for $type to $filename\n";
    die "Duplicate filename $filename\n"
        if exists $filenames->{$filename};
    $filenames->{$filename} = 1;
    return $filename;
}

print "Done\n";
