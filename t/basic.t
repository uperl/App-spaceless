use strict;
use warnings;
use v5.10;
use Capture::Tiny qw( capture capture_stdout );
use App::spaceless;
use Test::More tests => 4;
use Env qw( @PATH );
use File::Temp qw( tempdir );
use Path::Class qw( file dir );
use Config;

subtest '--version' => sub {
  plan tests => 3;
  my($out, $err, $ret) = capture { App::spaceless->main('--version') };
  chomp $out;
  is $ret, 1, 'exit is 1';
  my $ver = $App::spaceless::VERSION // 'dev';
  is $out, "App::spaceless version $ver", 'output';
  is $err, '', 'error';
};

subtest '-v' => sub {
  plan tests => 3;
  my($out, $err, $ret) = capture { App::spaceless->main('-v') };
  chomp $out;
  is $ret, 1, 'exit is 1';
  my $ver = $App::spaceless::VERSION // 'dev';
  is $out, "App::spaceless version $ver", 'output';
  is $err, '', 'error';
};

subtest '-f' => sub {
  my $tmp = dir( tempdir( CLEANUP => 1 ));
  ok -d $tmp, "dir created";
  
  my $expected;
  
  subtest 'spaceless (no args)' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { App::spaceless->main };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    isnt $out, '', 'output is not empty';
    
    $expected = $out;
  };
  
  my $file = $tmp->file('foo.txt');
  
  my $actual;
  
  subtest "spaceless -f $file" => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { App::spaceless->main(-f => $file->stringify) };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    is $out, '', 'output is not empty';
    
    $actual = $file->slurp;
  };
  
  is $actual, $expected, 'output matches';
  
  note $actual;
};

subtest 'cmd.exe' => sub {
  plan skip_all => 'only on MSWin32 and cygwin' unless $^O =~ /^(MSWin32|cygwin)$/;
  my($cmd_exe) = grep { -e $_ } grep !/\s/, map { "$_/cmd$Config{exe_ext}" } @PATH;
  plan skip_all => 'unable to find sh' unless defined $cmd_exe;
  note 'full path:', $cmd_exe;

  my $tmp = dir( tempdir( CLEANUP => 1 ) );
  
  my $run_cmd = sub {
    my($path) = @_;
    $path = Cygwin::posix_to_win_path($path) if $^O eq 'cygwin';
    my @cmd = ($path);
    @cmd = ($cmd_exe, '/c', @cmd) if $^O eq 'cygwin';
    note "execute: @cmd";
    system @cmd;
    $?;
  };
  
  my $script1 = file( $tmp, 'test1.cmd' );
  do {
    $script1->spew("\@echo off\necho hi there\n");
    my($out, $err, $ret) = capture { $run_cmd->($script1) };
    plan skip_all => "really really simple .cmd script didn't exit 0" unless $ret == 0;
    plan skip_all => "really really simple .cmd script had error output" unless $err eq '';
    plan skip_all => "really really simple .cmd script didn't have the expected output" unless $out =~ /hi there/;
  };
  
  plan tests => 5;
  
  my $dir1 = dir($tmp, 'Program Files', 'Foo', 'bin');
  my $dir2 = dir($tmp, 'Program Files (x86)', 'Foo', 'bin');
  note capture_stdout { map { $_->mkpath(1,0700) } $dir1, $dir2 };
  ok -d $dir1, "dir $dir1";
  ok -d $dir2, "dir $dir2";

  unshift @PATH, $dir1, $dir2;

  my $set_path;

  subtest 'spaceless --cmd' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { App::spaceless->main('--cmd') };
    is $exit, 0, 'exit is 0';
    is $err, '', 'error is empty';
    isnt $out, '', 'output is not empty';
    $set_path = $out;
  };
  
  note "[set_path] begin";
  note $set_path;
  note "[set_path] end";

  splice @PATH, 0, 2; 

  $tmp->file('caller2.cmd')->openw->print($set_path, "\n\nscript2.cmd\n");
  $dir1->file('script2.cmd')->openw->print("\@echo off\necho this is script TWO\n");
  
  subtest 'script2' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { $run_cmd->($tmp->file('caller2.cmd')) };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    like $out, qr{TWO}, "out matches";
  };

  $tmp->file('caller3.cmd')->openw->print($set_path, "\n\nscript3.cmd\n");
  $dir2->file('script3.cmd')->openw->print("\@echo off\necho this is script THREE\n");

  subtest 'script3' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { $run_cmd->($tmp->file('caller3.cmd')) };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    like $out, qr{THREE}, "out matches";
  };
};

__END__

subtest 'bourne shell' => sub {
  my($sh_exe) = grep { -e $_ } grep !/\s/, map { "$_/sh.exe" } @PATH;
  plan skip_all => 'unable to find sh.exe' unless defined $sh.exe;
  note 'full path:', $cmd_exe;

  my $tmp = dir( tempdir( CLEANUP => 1 ) );
  
  my $run_cmd = sub {
    my($path) = @_;
    $path = Cygwin::posix_to_win_path($path) if $^O eq 'cygwin';
    my @cmd = ($path);
    @cmd = ($cmd_exe, '/c', @cmd) if $^O eq 'cygwin';
    note "execute: @cmd";
    system @cmd;
    $?;
  };
  
  my $script1 = file( $tmp, 'test1.cmd' );
  do {
    $script1->spew("\@echo off\necho hi there\n");
    my($out, $err, $ret) = capture { $run_cmd->($script1) };
    plan skip_all => "really really simple .cmd script didn't exit 0" unless $ret == 0;
    plan skip_all => "really really simple .cmd script had error output" unless $err eq '';
    plan skip_all => "really really simple .cmd script didn't have the expected output" unless $out =~ /hi there/;
  };
  
  plan tests => 5;
  
  my $dir1 = dir($tmp, 'Program Files', 'Foo', 'bin');
  my $dir2 = dir($tmp, 'Program Files (x86)', 'Foo', 'bin');
  note capture_stdout { map { $_->mkpath(1,0700) } $dir1, $dir2 };
  ok -d $dir1, "dir $dir1";
  ok -d $dir2, "dir $dir2";

  unshift @PATH, $dir1, $dir2;

  my $set_path;

  subtest 'spaceless --cmd' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { App::spaceless->main('--cmd') };
    is $exit, 0, 'exit is 0';
    is $err, '', 'error is empty';
    isnt $out, '', 'output is not empty';
    $set_path = $out;
  };
  
  note "[set_path] begin";
  note $set_path;
  note "[set_path] end";

  splice @PATH, 0, 2; 

  $tmp->file('caller2.cmd')->openw->print($set_path, "\n\nscript2.cmd\n");
  $dir1->file('script2.cmd')->openw->print("\@echo off\necho this is script TWO\n");
  
  subtest 'script2' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { $run_cmd->($tmp->file('caller2.cmd')) };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    like $out, qr{TWO}, "out matches";
  };

  $tmp->file('caller3.cmd')->openw->print($set_path, "\n\nscript3.cmd\n");
  $dir2->file('script3.cmd')->openw->print("\@echo off\necho this is script THREE\n");

  subtest 'script3' => sub {
    plan tests => 3;
    my($out, $err, $exit) = capture { $run_cmd->($tmp->file('caller3.cmd')) };
    is $exit, 0, 'exit okay';
    is $err, '', 'error is empty';
    like $out, qr{THREE}, "out matches";
  };
};

