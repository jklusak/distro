# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::FeatureAccess::Configure;

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # Checkers may be called in a script context, in which case
    # Foswiki::Func is not available. However in a script context
    # this option isn't interesting anyway.
    return
      unless defined $Foswiki::Plugins::SESSION
      && eval("require Foswiki::Func");

    if ( defined $Foswiki::cfg{LoginManager}
        && $Foswiki::cfg{LoginManager} eq 'none' )
    {
        $reporter->ERROR(
"Configure access restrictions will not be used.  The ={LoginManager}= is set to 'none' and no access controls will be applied.
Clear this field, or configure a ={LoginManager}=. "
        ) if ( $Foswiki::cfg{FeatureAccess}{Configure} );
        return;
    }

    ( $Foswiki::cfg{FeatureAccess}{Configure} )
      ? $reporter->NOTE('The users listed in this field have configure access.')
      : $reporter->NOTE(
"This field is empty. Configure access is granted members of the $Foswiki::cfg{SuperAdminGroup} by default."
      );
    ( $Foswiki::cfg{Password} )
      ? $reporter->NOTE(
'   * The _internal admin_ user is configured and always has access to configure.'
      )
      : $reporter->NOTE('   * There is no _internal admin_ user configured.');

    my $it = Foswiki::Func::eachGroupMember( $Foswiki::cfg{SuperAdminGroup} );
    my @admins;

    while ( defined $it && $it->hasNext() ) {
        my $admin = $it->next();
        my $admincUID = Foswiki::Func::getCanonicalUserID($admin) || '';
        $admincUID =
          ( $admincUID && $admincUID ne $admin ) ? "($admincUID)" : '';

        # The group members come from a data topic, which might have been
        # populated even when running in bootstrap mode. In this case there
        # will be no mapping for the user and therefore no CUID.
        push( @admins, "$admin$admincUID" ) if $admin;
    }

    if ( scalar(@admins) lt 2 ) {
        $reporter->NOTE("   * The $Foswiki::cfg{SuperAdminGroup} is empty.");
    }

    if (   scalar(@admins) lt 2
        && !$Foswiki::cfg{Password}
        && !$Foswiki::cfg{FeatureAccess}{Configure} )
    {
        $reporter->WARN(
"$Foswiki::cfg{SuperAdminGroup} contains no users and the _internal admin_ password is not set ( =\$Foswiki::cfg{Password}= )
and the $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin}) cannot be used. You should:
   * set the _internal admin_ password, and/or
   * add users to this list who are permitted to access configure, or
   * Register and add add users to the $Foswiki::cfg{SuperAdminGroup}."
        );
        if ( $Foswiki::cfg{BOOTSTRAP} ) {
            $reporter->WARN(
"You are accessing configure while bootstrapping foswiki. Do not log out from foswiki without resovling this issue!"
            );
        }
    }
    $reporter->NOTE(
"   * Members of $Foswiki::cfg{SuperAdminGroup} have access to configure: ="
          . join( ', ', @admins )
          . "= " )
      unless ( $Foswiki::cfg{FeatureAccess}{Configure}
        || scalar(@admins) == 1 );
    $reporter->NOTE(
"   * Members of the $Foswiki::cfg{SuperAdminGroup} do *not* have access to configure."
    ) if $Foswiki::cfg{FeatureAccess}{Configure};

    my @Authorized = split( /[,\s]+/, $Foswiki::cfg{FeatureAccess}{Configure} );
    my $passed = '';   # Set to true if current user is allowed to use configure

    my $cUID    = Foswiki::Func::getCanonicalUserID();
    my $curuser = Foswiki::Func::getWikiName($cUID);

    unless ( scalar @Authorized ) {
        $passed = $Foswiki::Plugins::SESSION->{users}->isAdmin($cUID);
    }

    if ( scalar @Authorized ) {
        foreach my $user (@Authorized) {
            next unless $user;
            if ( $user eq $curuser || $user eq $cUID ) {
                $passed = 1;
            }
            if ( $user =~ m/Group$/ ) {
                $reporter->WARN(
"If $user is a group, it will be ignored. Configure does not use WikiGroups for access control. Only WikiNames are valid in this field."
                );
            }
        }
    }
    $reporter->ERROR(
"Current user $curuser  not in this list, and is locked out, If you save the configuration, you'll lose access to configure!"
    ) if ( !$passed && $cUID ne 'BaseUserMapping_333' );

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2015-2018 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
