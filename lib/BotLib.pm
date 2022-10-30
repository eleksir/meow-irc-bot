package BotLib;
# Экспортирует парсер команд. Собственно, входная точка для парсеров команд по "ролям".

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open                 qw (:std :utf8);
use English              qw ( -no_match_vars );

use Log::Any             qw ($log);

use BotLib::Role::Assist qw (AssistCommand);
use BotLib::Conf         qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Command);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Парсер команд. Его задача раскидывать команды в зависимости от ролей (от того, в какой канал пришла команда)
# string Command($bot, $chatid, $chattername, $text)
sub Command {
	my $bot         = shift;
	my $chatid      = shift;
	my $chattername = shift;
	my $text        = shift;

	return undef unless defined $text;

	$log->debug ("[DEBUG] Got message from $chattername in $chatid: $text");
	my $reply;

	# Для простоты разделим команды по "ролям". Предполагается, что каждый канальчик несёт в себе одну роль.
	if ($chatid eq $c->{channels}->{assist}->{name}) {
		$reply = AssistCommand ($bot, $chatid, $chattername, $text);
	}

	return $reply;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
