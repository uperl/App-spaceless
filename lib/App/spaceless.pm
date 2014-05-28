package App::spaceless;

use strict;
use warnings;
use v5.10;
use Config;
use Shell::Guess;
use Shell::Config::Generate qw( win32_space_be_gone );
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

# ABSTRACT: Convert PATH type environment variables to spaceless versions
# VERSION

=head1 DESCRIPTION

This module provides the machinery for the L<spaceless> app, a program
that helps convert PATH style environment variables to spaceless varities
on Windows systems (including Cygwin).

=cut

sub main
{
  shift;
  local @ARGV = @_;
  my $shell;
  my $file;

  GetOptions(
    'csh'     => sub { $shell = Shell::Guess->c_shell },
    'sh'      => sub { $shell = Shell::Guess->bourne_shell },
    'cmd'     => sub { $shell = Shell::Guess->cmd_shell },
    'command' => sub { $shell = Shell::Guess->command_shell },
    'fish'    => sub { $shell = Shell::Guess->fish_shell },
    'korn'    => sub { $shell = Shell::Guess->korn_shell },
    'power'   => sub { $shell = Shell::Guess->power_shell },
    'f=s'     => \$file,
    'help|h'  => sub { pod2usage({ -verbose => 2}) },
    'version'      => sub {
      say 'App::spaceless version ', ($App::spaceless::VERSION // 'dev');
      return 1;
    },
  );

  $shell = Shell::Guess->running_shell unless defined $shell;

  @ARGV = ('PATH') unless @ARGV;
  my $config = Shell::Config::Generate->new;
  $config->echo_off;
  my $sep = quotemeta $Config{path_sep};

  *filter = $^O eq 'cygwin' && $shell->is_win32 ? sub { map { Cygwin::posix_to_win_path($_) } @_ } : sub { @_ };

  foreach my $var (@ARGV)
  {
    $config->set_path(
      $var => filter(win32_space_be_gone split /$sep/, $ENV{$var})
    );
  }

  if(defined $file)
  {
    $config->generate_file($shell, $file);
  }
  else
  {
    print $config->generate($shell);
  }
  
  return 0;
}

1;
