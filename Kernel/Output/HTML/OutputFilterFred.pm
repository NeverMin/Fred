# --
# Kernel/Output/HTML/OutputFilterFred.pm
# Copyright (C) 2001-2007 OTRS GmbH, http://otrs.org/
# --
# $Id: OutputFilterFred.pm,v 1.5 2007-08-24 10:03:40 tr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Output::HTML::OutputFilterFred;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.5 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # get needed objects
    foreach (qw(MainObject ConfigObject LogObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    return $Self;
}

sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Text = '';
    my $Home = $Self->{ConfigObject}->Get('Home');

    # do noting on redirects
    if (${$Param{Data}} =~ /^Status: 302 Moved/mi && ${$Param{Data}} =~ /^location:/mi && length(${$Param{Data}}) < 800 ) {
        # do nothing
        return 1;
    }

    # Check the HTML-Output with HTML::Lint
    if ($Self->{ConfigObject}->Get('Fred::HTMLCheck')) {
        my $HTMLText = '';
        if ($Self->{MainObject}->Require('HTML::Lint')) {
            HTML::Lint->import();
            my $HTMLLintObject = HTML::Lint->new( only_types => HTML::Lint::Error->STRUCTURE );
            $HTMLLintObject->parse (${$Param{Data}});

            my $ErrorCounter = $HTMLLintObject->errors;
            foreach my $Error ($HTMLLintObject->errors) {
                my $String .= $Error->as_string;
                if ($String !~ /Invalid character .+ should be written as /) {
                    $HTMLText .=  $String . "\n";
                }
            }
        } else {
            $HTMLText = 'The HTML-checker of Fred requires HTML::Lint to be installed!'
                . 'Please install HTML::Lint or deactivate the HTML-checker via SysConfig.';
        }

        if ($HTMLText) {
            $Text .= $Self->_HTMLQuote(
                Text => $HTMLText,
                Title => "HTML-Checker",
            );
        }
    }

    # Search for stderr messages
    if ($Self->{ConfigObject}->Get('Fred::STDERRLog')) {
        if (open (OUTPUT, "< ".$Self->{ConfigObject}->Get('Home')."/var/fred.log")) {
            my $ErrorLogText = '';
            my @Row = <OUTPUT>;
            my @ReverseRow = reverse(@Row);
            foreach (@ReverseRow) {
                if ($_ =~ /FRED/) {
                    last;
                }
                if ($_ !~ /Subroutine .+? redefined at/) {
                    $ErrorLogText .= $_;
                }
            }

            print STDERR "FRED\n";

            close (OUTPUT);

            if ($ErrorLogText) {
                $Text .= $Self->_HTMLQuote(
                    Text => $ErrorLogText,
                    Title => "STDERR",
                );
            }
        }
    }
    # use the cvs checks
#     if ($Self->{ConfigObject}->Get('Fred::CVSFilter')) {
#         my $PathToCVSFilter = $Self->{ConfigObject}->Get('Fred::PathToCVSFilter');
#         if (${$Param{Data}} =~ /Notify.+?Action.+?value="(.+?)">.*?$/mxs) {
#             my $Action = $1;
#             my $FilterText = '';
#             if (-e "$Home/Kernel/Modules/$Action.pm") {
#                 if (open (OUTPUT, "perl $PathToCVSFilter/filter-extended.pl $Home/Kernel/Modules $Home/Kernel/Modules/$Action.pm |")) {
#                     my $Merge = 0;
#                     while (<OUTPUT>) {
#                         if ($_!~ /^NOTICE/) {
#                             $FilterText .= $_;
#                             $Merge = 1;
#                         }
#                     }
#                     close (OUTPUT);
#                     if ($Merge) {
#                         $FilterText = $Action . ".pm\n" . $FilterText;
#                     }
#                 }
#             }
#
#             my $SystemModule = '';
#             if ($Action =~ /(Agent|Admin|Customer|Public)(.+)$/) {
#                 $SystemModule = $2;
#             }
#
#             if (-e "$Home/Kernel/System/$SystemModule.pm") {
#                 if (open (OUTPUT, "perl $PathToCVSFilter/filter-extended.pl $Home/Kernel/System $Home/Kernel/System/$SystemModule.pm |")) {
#                     my $Merge = 0;
#                     while (<OUTPUT>) {
#                         if ($_!~ /^NOTICE/) {
#                             $FilterText .= $_;
#                             $Merge = 1;
#                         }
#                     }
#                     close (OUTPUT);
#                     if ($Merge) {
#                         $FilterText = $SystemModule . ".pm\n" . $FilterText;
#                     }
#                 }
#             }
#             if ($FilterText) {
#                 $Text .= $Self->_HTMLQuote(
#                     Text => $FilterText,
#                     Title => "filter-extended.pl",
#                 );
#             }
#         }
#     }
    #-----------------------------------------

    if ($Text) {
        if (${$Param{Data}} =~ s/(\<body(|.+?)\>)/$1\n$Text\n\n\n\n/mx) {
        }
    }

    return 1;
}

sub _HTMLQuote {
    my $Self = shift;
    my %Param = @_;
    my $Output = '';
    $Param{Text} =~ s/&/&amp;/g;
    $Param{Text} =~ s/</&lt;/g;
    $Param{Text} =~ s/>/&gt;/g;
    $Param{Text} =~ s/\n/\n\<br\>/g;
    # shown message
    $Output .= "<table bgcolor=\"#000000\" cellspacing=\"3\" cellpadding=\"0\" width=\"100%\">\n";
    $Output .= "<tr>\n";
    $Output .= "<td bgcolor=\"ba0f0f\">\n";
    $Output .= "<table bgcolor=\"#ffffff\" cellspacing=\"0\" cellpadding=\"2\" width=\"100%\">\n";
    $Output .= "<tr>\n";
    $Output .= "<td bgcolor=\"ba0f0f\">\n";
    $Output .= "<b><font color=\"#ffffff\">Fred: $Param{Title}</font></b>\n";
    $Output .= "</td>\n";
    $Output .= "</tr>\n";
    $Output .= "<tr>\n";
    $Output .= "<td>\n";
    $Output .= "<font size=\"-2\">" . $Param{Text} ."</font>";
    $Output .= "</td>\n";
    $Output .= "</tr>\n";
    $Output .= "</table>\n";
    $Output .= "</td>\n";
    $Output .= "</tr>\n";
    $Output .= "</table>\n";
    # just a small space
    $Output .= "<table cellspacing=\"1\" cellpadding=\"0\" width=\"100%\">\n";
    $Output .= "<tr>\n";
    $Output .= "<td>\n";
    $Output .= "</td>\n";
    $Output .= "</tr>\n";
    $Output .= "</table>\n";
    return $Output;
}

1;
