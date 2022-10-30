package BotLib::Command;
# Парсит команды. Здесь команды, которые не вынесены в отдельные модули-тематические-коллекции.

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open         qw (:std :utf8);
use English      qw ( -no_match_vars );

use JSON::XS        ();
use Log::Any     qw ($log);

use BotLib::Conf qw (LoadConf);
use BotLib::Util qw (storedata rakedata deletedata timems utf2b64 urlencode irandom);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Notify DelayedNotify PrintMsg UrlencodeStr IrandNum);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Одноразовая напоминалка. Сохраняет сообщение в базу notifications и отправляет его в delayed notifications.
# Возвращает либо строку-подтверждение, либо подсказку как пользоваться командой.
# $string Notify($chatid, $amount, $units, $message)
sub Notify {
	my $chatid  = shift;
	my $amount  = shift;
	my $units   = shift;
	my $message = shift;

	if (defined $units) {
		if ($units eq 'm' || $units eq 'minute' || $units eq 'minutes') {
			$amount = eval { $amount * 60 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		} elsif ($units eq 'h' || $units eq 'hour' || $units eq 'hours') {
			$amount = eval { $amount * 60 * 60 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		} elsif ($units eq 's' || $units eq 'second' || $units eq 'seconds') {
			$amount = eval { $amount + 0 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		}
	} else {
		$amount = eval { $amount + 0 };

		unless (defined $units) {
			return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
		}
	}

	my $timestamp = time () + $amount;
	my $msg->{title} = 'Meow-bot notification';

	if (defined $message && $message ne '') {
		$msg->{text} = $message;
	} else {
		$msg->{text} = 'Напоминалка!';
	}

	my $json = JSON::XS->new->utf8->canonical->encode ($msg);
	storedata ('notifications', $timestamp, $json, $c->{notifications}->{retention_days});
	DelayedNotify ($c->{channels}->{notify}->{name}, $msg->{text});

	return sprintf 'Notification will be sent after %d seconds', $amount;
}

# Пишет сообщение в чятик и складывает в БД, чтобы позже показать юзеру, когда он появится в чятике
# undef PrinfMsgForUser($userid, $chatid, $message)
sub DelayedNotify {
	my $channel = shift;
	my $message = shift;

	my $timestamp = timems ();
	my $data;
	$data->{message}         = $message;
	$data->{channel}         = $channel;
	$data->{timestamp}       = $timestamp;
	$data->{expiration_time} = $c->{delayed_notifications}->{retention_days} * 24 * 60 * 60 * 1000 + $timestamp;
	$data->{retention_days}  = $c->{delayed_notifications}->{retention_days};

	# Достанем список тех, кто есть в канальчике notify, им на джоине показывать сообщение не надо
	my @users = keys %{$MAIN::IRC->channel_list->{$c->{channels}->{notify}->{name}}}; ## no critic (Modules::RequireExplicitInclusion)
	$data->{users_shown} = \@users;

	my $json = JSON::XS->new->utf8->canonical->encode ($data);
	storedata ('delayed_notifications', timems (), $json, $c->{delayed_notifications}->{retention_days});

	return;
}

# Пишет сообщение в чятик или юзеру
# undef PrintMsg($chatid, $text)
sub PrintMsg {
	my $channel = shift;
	my $message = shift;

	$MAIN::IRC->send_long_message ('utf8', 0, 'PRIVMSG', $channel, $message); ## no critic (Modules::RequireExplicitInclusion)
	$log->debug ("[DEBUG] message '$message' sent to $channel");

	return;
}

sub UrlencodeStr {
	my $str = shift;
	return urlencode ($str);
}

sub IrandNum {
	my $num = shift;
	$num = eval {$num + 0};

	if (defined $num) {
		return irandom ($num);
	} else {
		return;
	}
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
