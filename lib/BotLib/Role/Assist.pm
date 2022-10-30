package BotLib::Role::Assist;
# Содержит парсер команд для роли ассистента

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open                  qw (:std :utf8);
use English               qw ( -no_match_vars );

use BotLib::Command       qw (Notify  UrlencodeStr IrandNum);
use BotLib::Command::Todo qw (Todo);
use BotLib::Command::Hash qw (Md5Str Sha1Str Sha224Str Sha256Str Sha384Str Sha512Str Crc32Str MurmurhashStr B64Str);

use BotLib::Conf          qw (LoadConf);
use BotLib::Util          qw (runcmd SigHandler);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (AssistCommand);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Парсит команды для общей роли (роли ассистента)
# $reply AssistCommand($bot, $chatid, $chattername, $text)
sub AssistCommand {
	my $bot         = shift;
	my $chatid      = shift;
	my $chattername = shift;
	my $text        = shift;

	my $reply;

	if ($text eq 'help' || $text eq 'помощь') {
		$reply = _help ();
	} elsif ($text eq 'version' || $text eq 'ver') {
		$reply = 'Версия нуль.чего-то_там.чего-то_там';
	} elsif ($text eq 'ping') {
		$reply = 'pong';
	} elsif ($text eq 'cal') {
		my @cmd;

		if ($OSNAME eq 'darwin' || $OSNAME eq 'freebsd') {
			@cmd = qw (cal -Nh3);
		} elsif ($OSNAME eq 'linux') {
			@cmd = qw (cal -m3);
		}

		if ($#cmd > 0) {
			my $res = runcmd (@cmd);

			if ($res->{success}) {
				$reply = $res->{text};
			} else {
				$reply = $res->{err_msg};
			}
		}
	} elsif ($text eq 'quit' || $text eq 'exit') {
		SigHandler ('exit');
	} elsif ($text =~ /^(notify|remind)\s+me\s+after\s+(\d+)\s*(s|seconds|m|minutes|h|hours)\s+(.*)$/) {
		my $amount = $2;
		my $units = $3;
		my $message = $4;
		$reply = Notify ($chatid, $amount, $units, $message);
	} elsif ($text =~ /n\s+(\d+)(s|m|h)\s+(.*)$/) {
		my $amount = $1;
		my $units = $2;
		my $message = $3;
		$reply = Notify ($chatid, $amount, $units, $message);
	} elsif ($text =~ /^(todo\s*|todo\s+.+)$/) {
		$reply = Todo ($text);
	} elsif ($text =~ /^b64\s(.*)/) {
		$reply = B64Str ($1);
	} elsif ($text =~ /^md5\s(.*)/) {
		$reply = Md5Str ($1);
	} elsif ($text =~ /^sha1\s(.*)/) {
		$reply = Sha1Str ($1);
	} elsif ($text =~ /^sha224\s(.*)/) {
		$reply = Sha224Str ($1);
	} elsif ($text =~ /^sha256\s(.*)/) {
		$reply = Sha256Str ($1);
	} elsif ($text =~ /^sha384\s(.*)/) {
		$reply = Sha384Str ($1);
	} elsif ($text =~ /^sha512\s(.*)/) {
		$reply = Sha512Str ($1);
	} elsif ($text =~ /^crc32\s(.*)/) {
		$reply = Crc32Str ($1);
	} elsif ($text =~ /^murmurhash\s(.*)/) {
		$reply = MurmurhashStr ($1);
	} elsif ($text =~ /^urlencode\s(.*)/) {
		$reply = UrlencodeStr ($1);
	} elsif ($text =~ /^rand\s+(.*)\s*/) {
		$reply = IrandNum ($1);
	} elsif ($text eq 'unixtime') {
		$reply = time ();
	} elsif ($text eq '=(' || $text eq ':(' || $text eq '):') {
		$reply = ':)';
	} elsif ($text eq '=)' || $text eq ':)' || $text eq '(:') {
		$reply = ':D';
	}

	return $reply;
}

# Возвращает список возможных команд
# $text _help()
sub _help {
	my $text = '';
	$text .= "help                      - это сообщение\n";
	$text .= "ping                      - попинговать бота\n";
	$text .= "ver                       - написать что-то про версию ПО\n";
	$text .= "cal                       - календарик\n";
	$text .= "exit                      - завершить работу бота\n";
	$text .= "quit                      - завершить работу бота\n";
	$text .= "notify me after N [s|m|h] - одноразовая напоминалка через desktop notification\n";
	$text .= "n N[s|m|h] message        - одноразовая напоминалка через desktop notification\n";
	$text .= "todo                      - выводит списк запланированных дел\n";
	$text .= "todo -d N                 - удаляет из списка запланированных дел дело N\n";
	$text .= "todo ДЕЛО                 - добавляет в списк запланированных дел ДЕЛО\n";
	$text .= "sha1 STR                  - выводит sha1sum для STR\n";
	$text .= "sha224 STR                - выводит sha224sum для STR\n";
	$text .= "sha256 STR                - выводит sha256sum для STR\n";
	$text .= "sha384 STR                - выводит sha384sum для STR\n";
	$text .= "sha512 STR                - выводит sha512sum для STR\n";
	$text .= "crc32 STR                 - выводит crc32 для STR\n";
	$text .= "md5 STR                   - выводит md5sum для STR\n";
	$text .= "murmurhash STR            - выводит murmur hash для STR\n";
	$text .= "b64 STR                   - выводит base64 для STR\n";
	$text .= "urlencode STR             - кодирует STR по urlencode\n";
	$text .= "rand N                    - выдаёт рандомное целое число от 0 до указанного\n";
	$text .= "unixtime                  - выдаёт текущее время в формате unix timestamp (секунды с 1 янв 1970)\n";

	return $text;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
