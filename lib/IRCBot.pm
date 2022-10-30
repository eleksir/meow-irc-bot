package IRCBot;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open                  qw (:std :utf8);
use English               qw ( -no_match_vars );

use AnyEvent                 ();
use AnyEvent::IRC            ();
use AnyEvent::IRC::Client    ();
use AnyEvent::IRC::Util   qw (prefix_nick);
use Date::Format::ISO8601 qw (gmtime_to_iso8601_datetime);
use Encode                qw (decode_utf8 encode);
use JSON::XS              qw (decode_json);
use Log::Any              qw ($log);

use BotLib                qw (Command);
use BotLib::Command       qw (PrintMsg);
use BotLib::Conf          qw (LoadConf);
use BotLib::Periodic      qw (PollNotifications CleanExpiredEntries UpdateTopic);
use BotLib::Util          qw (rakedata storedata deletedata SigHandler SigIntHandler SigTermHandler SigQuitHandler);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (RunIRCBot);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Основная функция
# undef RunIRCBot()
sub RunIRCBot {
	my $cv = AnyEvent->condvar;

	# Пытаемся ловить сигналы асинхронно
	my $sigint  = AnyEvent->signal (signal => 'INT',  cb => \&SigIntHandler);
	my $sigterm = AnyEvent->signal (signal => 'TERM', cb => \&SigTermHandler);
	my $sigquit = AnyEvent->signal (signal => 'QUIT', cb => \&SigQuitHandler);

	# Раз в секунду опрашиваем базу с нотификашками
	my $pollnotifications;
	# Естественно, опрашиваем только если нотификашки включены в каком-то виде
	if ($c->{notifications}->{enabled} || $c->{notifications}->{desktop_notification}) {
		$pollnotifications = AnyEvent->timer(
			after    => 3, # seconds
			interval => 1, # second
			cb       => \&PollNotifications,
		);
	}

	# Раз в 15 минут чистим базы от просроченных записей
	my $cleandatabases = AnyEvent->timer (
		after    => 900, # seconds
		interval => 900, # seconds
		cb       => \&CleanExpiredEntries,
	);

	# Раз в минуту смотрим что у нас с топиком во всех каналах
	my $topicmonitor = AnyEvent->timer (
		after    => 5,  # seconds
		interval => 60, # seconds
		cb       => \&UpdateTopic,
	);

	# Looks butt-ugly, but we have to make global var calls... err calls to MAIN namespace var
	$MAIN::IRC = AnyEvent::IRC::Client->new (send_initial_whois => 1); ## no critic (Modules::RequireExplicitInclusion)

	$MAIN::IRC->reg_cb ( ## no critic (Modules::RequireExplicitInclusion)
		irc_privmsg => sub {
			my ($self, $msg) = @_;

			my $botnick = $MAIN::IRC->nick (); ## no critic (Modules::RequireExplicitInclusion)
			my $chatid  = decode_utf8 ($msg->{params}->[0]);
			my $text    = decode_utf8 ($msg->{params}->[-1]);
			my $nick    = prefix_nick (decode_utf8 ($msg->{prefix}));
			my $answer;

			# Ивенты без текста нам не интересны
			unless (defined $text) { return; }

			$answer = Command ($self, $chatid, $nick, $text);

			if (defined $answer && $answer ne '') {
				foreach my $string (split /\n/, $answer) {
					if ($string ne '') {
						if ($MAIN::IRC->is_my_nick ($chatid)) { ## no critic (Modules::RequireExplicitInclusion)
							# private chat
							PrintMsg ($nick, $string);
						} else {
							# chat in channel
							PrintMsg ($chatid, $string);
						}
					}
				}
			}

			return;
		},

		connect     => sub {
			my ($pc, $err) = @_;

			if (defined $err) {
				$log->err ("[ERROR] Couldn't connect to server: $err\n");
			}

			if (defined ($c->{identify}) && $c->{identify} ne '') {
				# freenode/libera.chat identification style
				$MAIN::IRC->send_srv ( ## no critic (Modules::RequireExplicitInclusion)
					PRIVMSG => 'NickServ',
					sprintf ('identify %s %s', encode ('UTF-8', $c->{nick}), encode ('UTF-8', $c->{identify})),
				);
			}

			# Джойнимся ко всем каналам, кроме assist-а
			for my $chan (sort (keys %{$c->{channels}})) {
				next if $chan eq 'assist';

				if ($chan eq 'notify') {
					next unless ($c->{notifications}->{enabled});
				}

				$MAIN::IRC->send_srv ('JOIN', $c->{channels}->{$chan}->{name}); ## no critic (Modules::RequireExplicitInclusion)
			}

			# К assist-у джойнимся в последнюю очередь, чтобы быть уже приджойненным ко всему остальному
			$MAIN::IRC->send_srv ('JOIN', $c->{channels}->{assist}->{name});

			return;
		},

		connfail    => sub {
			$log->err ('[ERROR] Connection failed, trying again');
			sleep 5;

			$MAIN::IRC->connect(
				$c->{server},
				$c->{port},
				{
					nick => $c->{nick},
					user => $c->{nick},
					real => $c->{nick},
				},
			);
		},

		registered  => sub {
			my ($self) = @_;
			$log->info ('[INFO] Registered on server');
			$MAIN::IRC->enable_ping (60);
			return;
		},

		disconnect  => sub {
			$log->err ("[ERROR] Disconnected");

			# Не забудем почистить сохранённые топики каналов, на всякий случай
			if (defined $MAIN::IRC->{topics}) {
				$MAIN::IRC->{topics} = undef;
			}

			sleep 5;

			$log->info ("[INFO] Re-connecting to $c->{server}:$c->{port}");
			$MAIN::IRC->connect (
				$c->{server},
				$c->{port},
				{
					nick => $c->{nick},
					user => $c->{nick},
					real => $c->{nick},
				},
			);

			return;
		},

		kick        => sub {
			my ($self, $kicked_nick, $channel, $is_myself, $msg, $kicker_nick) = @_;

			if ($is_myself) {
				if (defined $msg && $msg ne '') {
					$log->warn (
						sprintf '[WARN] %s kicked me from %s with reason: %s',
							decode_utf8 ($kicker_nick), decode_utf8 ($channel), decode_utf8 ($msg),
					);
				} else {
					$log->warn (
						sprintf '[WARN] %s kicked me from %s with no reason',
							decode_utf8 ($kicker_nick), decode_utf8 ($channel),
					);
				}

				# Подчистим сохранённый топик, на всякий случай
				$MAIN::IRC->{topics}->{decode_utf8 ($channel)} = undef;

				sleep 3;
				$log->info (
					sprintf "[INFO] Re-joining to %s",
						decode_utf8 ($channel),
				);

				$MAIN::IRC->send_srv ('JOIN', $channel);
			}

			return;
		},

		nick_change => sub {
			my ($self, $old_nick, $new_nick, $is_myself) = @_;

			if ($is_myself) {
				$log->warn (
					sprintf '[WARN] My nick have been changed from %s to %s',
						decode_utf8 ($old_nick), decode_utf8 ($new_nick),
				);
			}

			return;
		},

		part        => sub {
			my ($self, $nick, $channel, $is_myself, $msg) = @_;

			if ($is_myself) {
				if (defined $msg && $msg ne '') {
					$log->warn (
						sprintf '[WARN] I left %s channel: %s',
							decode_utf8 ($channel), decode_utf8 ($msg),
					);
				} else {
					$log->warn (sprintf '[WARN] I left %s channel', decode_utf8 ($channel));
				}

				# Подчистим сохранённый топик, на всякий случай
				$MAIN::IRC->{topics}->{decode_utf8 ($channel)} = undef;
			} else {
				if (defined $msg && $msg ne '') {
					$log->warn (
						sprintf '[INFO] %s left %s channel: %s',
							decode_utf8 ($nick), decode_utf8 ($channel), decode_utf8 ($msg),
					);
				} else {
					$log->warn (
						sprintf '[INFO] %s left %s channel',
							decode_utf8 ($nick), decode_utf8 ($channel),
					);
				}
			}

			return;
		},

		join        => sub {
			my ($self, $nick, $channel, $is_myself) = @_;

			if ($is_myself) {
				$log->info (sprintf '[INFO] I joined to %s channel', decode_utf8 ($channel));
				# Достанем топик канальчика, вроде по-дефолту клиент это не коллекционирует.
				$MAIN::IRC->send_srv ('TOPIC');
			} else {
				$log->info (
					sprintf '[INFO] %s joined to %s channel',
						decode_utf8 ($nick), decode_utf8 ($channel),
				);

				# Покажем отложенные уведомления пользователю в личку
				if ($channel eq $c->{channels}->{notify}->{name}) {
					# Юзер заджойнился в канал с нотификашками, надо ему в приват вывалить все нотификашки, которые
					# были, пока его не было, либо то, что было за последние retention_days
					my $notifications = rakedata ('delayed_notifications');
					my $title_shown = 0;

					foreach my $timestamp (sort keys (%{$notifications})) {
						my $show = 1;
						my $item = decode_json ($notifications->{$timestamp});

						unless (defined $item) {
							$log->error (
								sprintf '[ERROR] Unable to decode json from %s db: %s',
									$c->{db}->{delayed_notifications}, $EVAL_ERROR,
							);
						}

						foreach my $user (@{$item->{users_shown}}) {
							if ($user eq decode_utf8 ($nick)) {
								$show = 0;
								last;
							}
						}

						if ($show) {
							push @{$item->{users_shown}}, decode_utf8 ($nick);

							unless ($title_shown) {
								PrintMsg ($nick, 'Missing notifications since your last visit or for 2 days:');
								$title_shown = 1;
							}

							my $msg = sprintf (
								'Channel %s: %s',
								$item->{channel},
								$item->{message},
							);

							# Показываем только если в настройках указано, что надо показать
							if ($c->{delayed_notifications}->{enabled}) {
								PrintMsg ($nick, $msg);
							}

							deletedata ('delayed_notifications', $item->{timestamp});
							my $json = JSON::XS->new->utf8->canonical->encode ($item);

							storedata (
								'delayed_notifications',
								$item->{timestamp},
								$json,
								$item->{expiration_time},
							);
						}
					}
				}

				# Заинвайтим пользователя в канал notify
				if ($channel eq $c->{channels}->{assist}->{name}) {
					if ($c->{notifications}->{enabled}) {
						$log->debug (
							sprintf '[DEBUG] Inviting %s to %s',
								decode_utf8 ($nick),  $c->{channels}->{notify}->{name},
						);
						$MAIN::IRC->send_srv ('INVITE', $nick, $c->{channels}->{notify}->{name});
					}
				}
			}

			return;
		},

		# Ответ от команды /topic, если topic установлен, RPL_TOPIC
		irc_332   => sub {
			my ($self, $event) = @_;
			my $who     = decode_utf8 ($event->{params}->[0]); # Тот, кому отвечают с сервера. Вообще говоря, по идее
			                                                      # это всегда ник бота
			my $channel = decode_utf8 ($event->{params}->[1]);
			my $topic   = decode_utf8 ($event->{params}->[2]);

			$log->info ("[INFO] Topic for $channel set to $topic");

			# По-умолчанию, топики почему-то не коллекционируются.
			$MAIN::IRC->{topics}->{$channel}->{topic} = $topic;

			return;
		},

		# Ответ от команды /topic, если topic не установлен/убран, RPL_NOTOPIC
		irc_331   => sub {
			my ($self, $event) = @_;

			my $who     = decode_utf8 ($event->{params}->[0]); # Тот, кому отвечают с сервера. Вообще говоря, по идее
			                                                      # это всегда ник бота
			my $channel = decode_utf8 ($event->{params}->[1]);

			$log->info ("No Topic for $channel set");

			# По-умолчанию, топики почему-то не коллекционируются.
			$MAIN::IRC->{topics}->{$channel}->{topic}  = '';

			return;
		},

		irc_topic   => sub {
			my ($self, $event) = @_;
			my $channel = decode_utf8 ($event->{params}->[0]);
			my $topic   = decode_utf8 ($event->{params}->[1]);

			$log->info ("[INFO] Topic for $channel set to $topic");

			# По-умолчанию, топики почему-то не коллекционируются.
			$MAIN::IRC->{topics}->{$channel}->{topic} = $topic;

			return;
		},
	);

	# these commands will queue until the connection
	# is completly registered and has a valid nick etc.
	$MAIN::IRC->ctcp_auto_reply ('ACTION',     ## no critic (Modules::RequireExplicitInclusion)
		sub {
			my ($cl, $src, $target, $tag, $msg, $type) = @_;
			return ['ACTION', $msg];
		},
	);

	$MAIN::IRC->ctcp_auto_reply ('CLIENTINFO', ## no critic (Modules::RequireExplicitInclusion)
		[
			'CLIENTINFO',
			'CLIENTINFO ACTION FINGER PING SOURCE TIME USERINFO VERSION',
		],
	);

	$MAIN::IRC->ctcp_auto_reply ('FINGER',     ## no critic (Modules::RequireExplicitInclusion)
		[
			'FINGER',
			$c->{nick},
		],
	);

	$MAIN::IRC->ctcp_auto_reply ('PING',       ## no critic (Modules::RequireExplicitInclusion)
		sub {
			my ($cl, $src, $target, $tag, $msg, $type) = @_;
			return ['PING', $msg];
		},
	);

	$MAIN::IRC->ctcp_auto_reply ('SOURCE',     ## no critic (Modules::RequireExplicitInclusion)
		[
			'SOURCE',
			'https://github.com/eleksir/meow-irc-bot',
		],
	);

	$MAIN::IRC->ctcp_auto_reply ('TIME',       ## no critic (Modules::RequireExplicitInclusion)
		[
			'TIME',
			gmtime_to_iso8601_datetime (time ()),
		],
	);

	$MAIN::IRC->ctcp_auto_reply ('USERINFO',   ## no critic (Modules::RequireExplicitInclusion)
		[
			'USERINFO',
			$c->{nick},
		],
	);

	$MAIN::IRC->ctcp_auto_reply ('VERSION',    ## no critic (Modules::RequireExplicitInclusion)
		[
			'VERSION',
			'Meow IRC Bot/1.0',
		],
	);

	if ($c->{ssl}) {
		$MAIN::IRC->enable_ssl ();         ## no critic (Modules::RequireExplicitInclusion)
	}

	$MAIN::IRC->connect (                      ## no critic (Modules::RequireExplicitInclusion)
		$c->{server},
		$c->{port},
		{
			nick => $c->{nick},
			user => $c->{nick},
			real => $c->{nick},
		},
	);

	$cv->wait;
	$MAIN::IRC->disconnect;                    ## no critic (Modules::RequireExplicitInclusion)
	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
