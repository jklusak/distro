# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality;

use strict;
use warnings;
use Assert;

# We try to use the ANSI SQL standard as far as possible, for the most
# part different SQL DB implementations support it fairly well. However
# they all have nuances, and there are areas where the support is not
# consistent - most notably in regex support. To that end we have to
# have a database personality module, which provides these custom
# operations in a consistent way.

sub new {
    my ( $class, $dbistore ) = @_;
    my $this = bless( { store => $dbistore }, $class );

    # SQL reserved words. The following words are reserved in all of
    # PostgresSQL, ANSI SQL, MySQL and SQLite so provide a good
    # working basis. Personality modules should extend this list.
    $this->reserve(
        qw(
          ALL ALTER AND AS ASC BETWEEN BY CASCADE CASE CHECK COLLATE COLUMN
          CONSTRAINT CREATE CROSS CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP
          DEFAULT DELETE DESC DISTINCT DROP ELSE EXISTS FOR FOREIGN FROM GROUP
          HAVING IN INDEX INNER INSERT INTO IS JOIN KEY LEFT LIKE NOT NULL ON OR
          ORDER OUTER PRIMARY REFERENCES RESTRICT RIGHT SELECT SET TABLE THEN TO
          UNION UNIQUE UPDATE VALUES WHEN WHERE WITH
          )
    );
    return $this;
}

# Protected - for use by subclasses only
# Register reserved words
sub reserve {
    my $this = shift;
    foreach (@_) {
        $this->{reserved}->{$_} = 1;
    }
}

=begin TML

---++ startup()
Execute any SQL commands required to start the DB in ANSI mode.
The default is no specific setup.

=cut

sub startup {
}

=begin TML

---+ table_exists(table_name [, table_name]*) -> boolean
Determine if a table exists

=cut

sub table_exists {
    my $this = shift;
    my $tables = join( ',', map { "'$_'" } @_ );

    # MySQL, Postgresql, MS SQL Server
    my $sql = <<SQL;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME IN ($tables)
SQL
    my @rows = $this->{store}->{handle}->selectrow_array($sql);

    #print STDERR scalar(@rows)." tables exist of ".scalar(@_)."\n";
    return scalar(@rows);
}

=begin TML

---++ require_COMMIT() -> $boolean
True if there is an automatic transaction opened that requires a commit.
The default is TRUE which works for SQLite, MySQL and Postgresql.

=cut

sub requires_COMMIT {
    return 1;
}

=begin TML

---++ text_type() -> string
Get the name of the TEXT type, used to store variable-length strings.

=cut

sub text_type {
    return 'TEXT';
}

=begin TML

---++ regexp($lhs, $rhs) -> $sql
Construct an SQL expression to execute the given regular expression
match.
  * =$rhs= - right hand side of the match
  * =$lhs= - the regular expression (perl syntax)
be different :-(

=cut

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    return "$lhs REGEXP $rhs";
}

=begin TML

---++ wildcard($lhs, $rhs) -> $sql
Construct an SQL expression that will match a Foswiki wildcard
name match.

Default is ANSI standard.
ANSI wildcards in LIKE are:
 _ (underscore)
 Any one character. For example, a_ matches ab and ac, but not a.
 % (percent)
 Any string of zero or more characters. For example, bl% matches
 bl and bla.
 []
 Any single character in the specified range or set. For example,
 T[oi]m matches Tom or Tim.
 [^]
 Any single character not in the specified range or set. For
 example, M[^c] matches Mb and Md, but not Mc.
Foswiki uses * wildcards, and separates alternatives with comma, so this
is easy to do.

The default implementation uses the regexp function to match.

=cut

sub wildcard {
    my ( $this, $lhs, $rhs ) = @_;
    my @exprs;
    if ( $rhs =~ s/^'(.*)'$/$1/ ) {
        foreach my $spec ( split( /(?:,\s*|\|)/, $rhs ) ) {
            $spec =~ s/(['.])/\\$1/g;
            my $like = 0;
            $like = 1 if $spec =~ s/\*/.*/g;
            $like = 1 if $spec =~ s/\?/./g;

            if ($like) {
                $spec = "'^$spec\$'";
                my $res = $this->regexp( $lhs, $spec );
                push( @exprs, $res );
            }
            else {
                push( @exprs, "$lhs='$spec'" );
            }
        }
    }
    return join( ' OR ', @exprs );
}

=begin TML

---++ d2n($timestring) -> $isosecs
Convert a Foswiki time string to a number.
This implementation is for SQLite - there is no support in ANSI.

=cut

sub d2n {
    my ( $this, $arg ) = @_;

    return "CAST(strftime(\"%s\", $arg) AS FLOAT)";
}

=begin

Calculate the character length of a string

=cut

sub length {
    my ( $this, $s ) = @_;
    return "LENGTH($s)";
}

=begin TML

---++ safe_id($id) -> $safeid
Make sure the ID is safe to use in this dialect of SQL.
Unsafe IDs should be quoted using the dialect's identifier
quoting rule. The default is to double-quote it.

=cut

sub safe_id {
    my ( $this, $id ) = @_;
    if ( $this->{reserved}->{$id} ) {
        $id = "\"$id\"";
    }
    return $id;
}

=begin TML

---++ cast_to_numeric($sql) -> $sql
Cast a datum to a numeric type for comparison

=cut

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS NUMERIC)";
}

=begin TML

---++ cast_to_string($sql) -> $sql
Cast a datum to a character string type for comparison

=cut

sub cast_to_text {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS " . $this->text_type() . ')';
}

=begin TML

---++ string_quote() -> $quote_char
Quote character for character strings - default is '

=cut

sub string_quote {
    return "'";
}

sub make_comment {
    my $this = shift;
    return '/*' . join( ' ', @_ ) . '*/';
}

sub true {
    return '1=1';
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2013 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
