package BotLib::Periodic;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;

use utf8;
use open                  qw (:std :utf8);
use English               qw ( -no_match_vars );

use JSON::XS              qw (decode_json);
use Log::Any              qw ($log);

use BotLib::Command       qw (PrintMsg);
use BotLib::Conf          qw (LoadConf);
use BotLib::Util          qw (runcmd cleanexpireddata rakedata deletedata);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (PollNotifications CleanExpiredEntries);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Регулярно выгребаем нотификашки из базы, запускаем нотификашки и пишем уведомления в канальчик с оповещениями
# undef PollNotifications()
sub PollNotifications {
	# Достаём все нотифаи в формате ссылки на хэш
	my $notification  = rakedata ('notifications');
	$log->debug ('[DEBUG] Raked notifications from ' . $c->{db}->{notifications} . ' db');

	my $deadline      = time ();
	my @notifications = sort (keys %{$notification});

	foreach my $timestamp (@notifications) {
		if ($timestamp <= $deadline) {
			$log->debug ("[Debug] Notification timestamp $timestamp <= $deadline, parsing");

			my $alarm = eval { decode_json ($notification->{$timestamp}); };
			deletedata ('notifications', $timestamp);

			next unless ($c->{notifications}->{enabled});

			# TODO: Показывать нотификации не только для mac os
			if (defined $alarm) {
				my $res;
				my @cmd;

				if (defined ($c->{notifications}->{sound}) && -e $c->{notifications}->{sound}) {
					if ($OSNAME eq 'darwin') {
						# Mac OS
						$log->debug ("[DEBUG] use macos-specific methods of playing sounds");
						@cmd = ('afplay', $c->{notifications}->{sound}, '--volume', '6');
					} elsif ($OSNAME eq 'MSWin32') {
						# Windows
						# Хрен знает как проиграть штатными средствами, без всплывающих окон звук в windows
						# TODO: Научиться проигрывать звук в windows :)
						$log->debug ("[DEBUG] windows detected, i don't know how to play sounds there")
					} elsif ($OSNAME eq 'linux' || $OSNAME eq 'freebsd') {
						# Linux/FreeBSD
						$log->debug ("[DEBUG] use linux/freebsd-specific methods of playing sounds");

						if (-x '/usr/bin/mpg123' || -x '/bin/mpg123' || -x '/usr/local/bin/mpg123') {
							@cmd = ('mpg123', '-q', $c->{notifications}->{sound});
						} elsif (-x '/usr/bin/mpg321' || -x '/bin/mpg321' || -x '/usr/local/bin/mpg321') {
							@cmd = ('mpg321', '-q', $c->{notifications}->{sound});
						} elsif (-x '/usr/bin/madplay' || -x '/bin/madplay' || -x '/usr/local/bin/madplay') {
							@cmd = ('madplay', '-q', '--no-tty-control', $c->{notifications}->{sound});
						} elsif (-x '/usr/bin/mp3blaster' || -x '/bin/mp3blaster' || -x '/usr/local/bin/mp3blaster') {
							@cmd = ('mp3blaster', $c->{notifications}->{sound});
						}
					} else {
						$log->debug ("[DEBUG] don't know how to play sounds on $OSNAME");
					}

					if ($#cmd > 0) {
						$res = runcmd (@cmd);
					}

					$#cmd = -1;
				}

				# Хрен знает, как показывать нотификашки стандартными средствами windows
				# TODO: Научиться показывать нотификашки в windows :)
				if ($OSNAME ne 'MSWin32') {
					if (defined $alarm->{text} && $alarm->{text} ne '') {
						if (defined $alarm->{title} && $alarm->{title} ne '') {
							if ($OSNAME eq 'darwin') {
								$log->debug ("[DEBUG] use macos-specific method of desktop notifications");
								my $applescript = sprintf (
									'display notification "%s" with title "%s"',
									$alarm->{text}, $alarm->{title},
								);

								@cmd = ('osascript', '-e', "'$applescript'");
							} else {
								$log->debug ("[DEBUG] use linux/freebsd-specific method of desktop notifications");
								@cmd = ('notify-send', '--expire-time=5000', $alarm->{title}, $alarm->{text});
							}
						} else {
							if ($OSNAME eq 'darwin') {
								$log->debug ("[DEBUG] use macos-specific method of desktop notifications");
								my $applescript = sprintf (
									'display notification "%s" with title "%s"',
									$alarm->{text}, $alarm->{text},
								);

								@cmd = ('osascript', '-e', "'$applescript'");
							} else {
								$log->debug ("[DEBUG] use linux/freebsd-specific method of desktop notifications");
								@cmd = ('notify-send', '--expire-time=5000', 'Напоминание от meow-бота', $alarm->{text});
							}
						}

						PrintMsg($c->{channels}->{notify}, $alarm->{text});
					} else {
						if ($OSNAME eq 'darwin') {
							$log->debug ("[DEBUG] use macos-specific method of desktop notifications");
							my $applescript = 'display notification "Настало время придти времени." with title "Напоминание от meow-бота"';
							@cmd = ('osascript', '-e', "'$applescript'");
						} else {
							$log->debug ("[DEBUG] use linux/freebsd-specific method of desktop notifications");
							@cmd = ('notify-send', '--expire-time=5000', 'Напоминание от meow-бота', 'Настало время придти времени.');
						}

						PrintMsg ($c->{channels}->{notify}, 'Настало время придти времени.');
					}

					$res = runcmd (@cmd);
				} else {
					$log->debug ('[DEBUG] skip desktopn notification on windows');
				}
			} else {
				$log->error (sprintf (
					'[ERROR] Bad notification data in db %s: %s',
					$c->{db}->{notifications}, $EVAL_ERROR,
				));
			}
		} else {
			$log->debug ("[Debug] Notification timestamp $timestamp > $deadline, skipping");
		}

		# Не выплёвываем все нотификации сразу, если их более одной штуки
		if ($#notifications > -1) {
			sleep 1;
		}
	}

	return;
}

# Вычищает протухшие записи из всех баз
# undef CleanExpiredEntries()
sub CleanExpiredEntries {
	foreach my $db (keys %{$c->{db}}) {
		cleanexpireddata ($db);
	}

	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
