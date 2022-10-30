package BotLib::Conf;
# loads config

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open     qw (:std :utf8);
use English  qw ( -no_match_vars );

use Encode   qw (encode_utf8);
use JSON::XS    ();
use Log::Any qw ($log);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (LoadConf);

local $OUTPUT_AUTOFLUSH = 1;

# Загружает конфиг в hashref
# $hashref LoadConf()
sub LoadConf {
	my $c = 'data/config.json';
	open my $CH, '<', $c or die "[FATA] No conf at $c: $OS_ERROR\n";
	binmode $CH;
	my $len = (stat $c) [7];
	my $json;
	my $readlen = read $CH, $json, $len;

	unless ($readlen) {
		close $CH;
		$log->fatal ("[FATA] Unable to read $c: $OS_ERROR");
	}

	if ($readlen != $len) {
		close $CH;
		$log->fatal ("[FATA] File $c is $len bytes on disk, but we read only $readlen bytes");
	}

	$json = encode_utf8 ($json);

	close $CH;
	my $j = JSON::XS->new->utf8->relaxed;

	# TODO: full validation of config
	return $j->decode ($json);
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
