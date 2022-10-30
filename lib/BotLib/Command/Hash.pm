package BotLib::Command::Hash;
# Имплементация команд на хэширование строк разными алгоритмами, в основном вропперы.

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open         qw (:std :utf8);
use English      qw ( -no_match_vars );

use Log::Any     qw ($log);

use BotLib::Util qw (utf2md5hex utf2sha1hex utf2sha224hex utf2sha256hex utf2sha384hex utf2sha512hex utf2crc32hex
                     utf2murmurhash utf2b64);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (B64Str Md5Str Sha1Str Sha224Str Sha256Str Sha384Str Sha512Str Crc32Str MurmurhashStr);


sub B64Str {
	my $str = shift;
	return utf2b64 ($str);
}

sub Md5Str {
	my $str = shift;
	return utf2md5hex ($str);
}

sub Sha1Str {
	my $str = shift;
	return utf2sha1hex ($str);
}

sub Sha224Str {
	my $str = shift;
	return utf2sha224hex ($str);
}

sub Sha256Str {
	my $str = shift;
	return utf2sha256hex ($str);
}

sub Sha384Str {
	my $str = shift;
	return utf2sha384hex ($str);
}

sub Sha512Str {
	my $str = shift;
	return utf2sha512hex ($str);
}

sub Crc32Str {
	my $str = shift;
	return utf2crc32hex ($str);
}

sub MurmurhashStr {
	my $str = shift;
	return utf2murmurhash ($str);
}


1;
