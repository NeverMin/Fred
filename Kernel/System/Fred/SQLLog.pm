# --
# Kernel/System/Fred/SQLLog.pm
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: SQLLog.pm,v 1.5 2007-10-18 05:14:28 tr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::Fred::SQLLog;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '$Revision: 1.5 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

=head1 NAME

Kernel::System::Fred::SQLLog

=head1 SYNOPSIS

handle the sql log

=over 4

=cut

=item new()

create a object

    use Kernel::Config;
    use Kernel::System::Log;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );

=cut

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Object (qw(ConfigObject LogObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }
    return $Self;
}

=item DataGet()

Get the data for this fred module. Returns true or false.
And add the data to the module ref.

    $BackendObject->DataGet(
        ModuleRef => $ModuleRef,
    );

=cut

sub DataGet {
    my $Self  = shift;
    my %Param = @_;

    # open the TranslationDebug.log file to get the untranslated words
    my $File = $Self->{ConfigObject}->Get('Home') . '/var/fred/SQL.log';
    my $Filehandle;
    if ( !open $Filehandle, '<', $File ) {
        $Param{ModuleRef}->{Data} = [
            "Perhaps you don't have permission at /var/fred/",
            "Can't read /var/fred/SQL.log"
        ];
        return;
    }

    my @LogMessages;

    # get the whole information
    LINE:
    for my $Line (reverse <$Filehandle>) {
        last LINE if $Line =~ /FRED/;

        my @SplitedLog = split /;/, $Line;
        if ($SplitedLog[0] eq 'SQL-DO' && $SplitedLog[1] =~ /^SELECT/) {
            $SplitedLog[0] .= ' - Perhaps you have an error you use DO for a SELECT-Statement:';
        }
        push @LogMessages, \@SplitedLog;
    }

    pop @LogMessages;
    close $Filehandle;

    $Self->InsertWord( What => "FRED\n" );
    $Param{ModuleRef}->{Data} = \@LogMessages;

    return 1;
}

=item ActivateModuleTodos()

Do all jobs which are necessary to activate this special module.

    $FredObject->ActivateModuleTodos(
        ModuleName => $ModuleName,
    );

=cut

sub ActivateModuleTodos {
    my $Self  = shift;

    my $File = $Self->{ConfigObject}->Get('Home') . '/Kernel/System/DB.pm';

    # check if it is an symlink, because it can be development system which use symlinks
    die "Can't manipulate $File because it is a symlink!" if -l $File;

    # to use TranslationDebug I have to manipulate the Language.pm file
    open my $Filehandle, '<', $File || die "Can't open $File !\n";
    my @Lines = <$Filehandle>;
    close $Filehandle;

    open my $FilehandleII, '>', $File || die "Can't write $File !\n";
    $Self->{LogObject}->Log( Priority => 'error', Message => "write file!" );
    for my $Line (@Lines) {
        if ( $Line =~ m[^                               \s*
                        if                              \s*
                        \(                              \s*
                        !                               \s*
                        \(                              \s*
                        \$Self->{Curser}                \s*
                        =                               \s*
                        \$Self->{dbh}->prepare\(\$SQL\) \s*
                        \)                              \s*
                        \)                              \s*
                        {
            ]x
        ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "insert fred log Prepare!" );
            print $FilehandleII "# FRED - manipulated\n";
            print $FilehandleII "use Kernel::System::Fred::SQLLog;\n";
            print $FilehandleII "my \$SQLLogObject = Kernel::System::Fred::SQLLog->new(\%{\$Self});\n";
            print $FilehandleII "my \$Caller = caller();\n";
            print $FilehandleII "\$SQLLogObject->InsertWord(What => \"SQL-SELECT;\$SQL;\$Caller\");\n";
            print $FilehandleII "# FRED - manipulated\n";
        }
        if ( $Line =~ /^    # send sql to database/ ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "insert fred log do!" );
            print $FilehandleII "# FRED - manipulated\n";
            print $FilehandleII "use Kernel::System::Fred::SQLLog;\n";
            print $FilehandleII "my \$SQLLogObject = Kernel::System::Fred::SQLLog->new(\%{\$Self});\n";
            print $FilehandleII "my \$Caller = caller();\n";
            print $FilehandleII "\$SQLLogObject->InsertWord(What => \"SQL-DO;\$Param{SQL};\$Caller\");\n";
            print $FilehandleII "# FRED - manipulated\n";
        }

        print $FilehandleII $Line;
    }
    close $FilehandleII;

    return 1;
}

=item DeactivateModuleTodos()

Do all jobs which are necessary to deactivate this special module.

    $FredObject->DeactivateModuleTodos(
        ModuleName => $ModuleName,
    );

=cut

sub DeactivateModuleTodos {
    my $Self  = shift;
    my $File  = $Self->{ConfigObject}->Get('Home') . '/Kernel/System/DB.pm';

    # check if it is an symlink, because it can be development system which use symlinks
    die "Can't manipulate $File because it is a symlink!" if -l $File;

    # to use TranslationDebugger I have to manipulate the Language.pm file
    # here I undo my manipulation
    open my $Filehandle, '<', $File || die "Can't open $File !\n";
    my @Lines = <$Filehandle>;
    close $Filehandle;

    open my $FilehandleII, '>', $File || die "Can't write $File !\n";

    my %RemoveLine = (
        "# FRED - manipulated\n"                                                  => 1,
        "use Kernel::System::Fred::SQLLog;\n"                                     => 1,
        "my \$SQLLogObject = Kernel::System::Fred::SQLLog->new(\%{\$Self});\n"    => 1,
        "my \$Caller = caller();\n"                                               => 1,
        "\$SQLLogObject->InsertWord(What => \"SQL-DO;\$Param{SQL};\$Caller\");\n" => 1,
        "\$SQLLogObject->InsertWord(What => \"SQL-SELECT;\$SQL;\$Caller\");\n"    => 1,
    );

    for my $Line (@Lines) {
        if ( !$RemoveLine{$Line} ) {
            print $FilehandleII $Line;
        }
    }
    close $FilehandleII;
    return 1;
}

=item InsertWord()

Save a word in the translation debug log

    $BackendObject->InsertWord(
        What => 'a word',
    );

=cut

sub InsertWord {
    my $Self  = shift;
    my %Param = @_;

    # check needed stuff
    if ( !$Param{What} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need What!',
        );
        return;
    }

    # save the word in log file
    my $File = $Self->{ConfigObject}->Get('Home') . '/var/fred/SQL.log';
    open my $Filehandle, '>>', $File || die "Can't write $File !\n";
    print $Filehandle $Param{What} . "\n";
    close $Filehandle;

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl.txt.

=cut

=head1 VERSION

$Revision: 1.5 $ $Date: 2007-10-18 05:14:28 $

=cut