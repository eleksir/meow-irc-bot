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
use Encode                qw (decode);
use JSON::XS              qw (decode_json encode_json);
use Log::Any              qw ($log);

use BotLib                qw (Command SigIntHandler SigTermHandler SigQuitHandler);
use BotLib::Command       qw (PrintMsg);
use BotLib::Conf          qw (LoadConf);
use BotLib::Periodic      qw (PollNotifications CleanExpiredEntries);
use BotLib::Util          qw (rakedata storedata deletedata);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (RunIRCBot);

local $OUTPUT_AUTOFLUSH = 1;

# Основная функция
# undef RunIRCBot()
sub RunIRCBot {
	my $c = LoadConf ();
	my $cv = AnyEvent->condvar;

	# Пытаемся ловить сигналы асинхронно
	my $sigint  = AnyEvent->signal (signal => 'INT',  cb => \&SigIntHandler);
	my $sigterm = AnyEvent->signal (signal => 'TERM', cb => \&SigTermHandler);
	my $sigquit = AnyEvent->signal (signal => 'QUIT', cb => \&SigQuitHandler);

	# Раз в секунду опрашиваем базу с нотификашками
	my $pollnotifications = AnyEvent->timer (
		after    => 3, # seconds
		interval => 1, # second
		cb       => \&PollNotifications,
	);

	# Раз в 15 минут чистим базы от просроченных записей
	my $cleandatabeses = AnyEvent->timer (
		after    => 900, # seconds
		interval => 900, # seconds
		cb       => \&CleanExpiredEntries,
	);

	# Looks butt-ugly, but we have to make global var calls... err calls to MAIN namespace var
	$MAIN::IRC = AnyEvent::IRC::Client->new (send_initial_whois => 1); ## no critic (Modules::RequireExplicitInclusion)

	$MAIN::IRC->reg_cb ( ## no critic (Modules::RequireExplicitInclusion)
		irc_privmsg => sub {
			my ($self, $msg) = @_;
			my $botnick = $MAIN::IRC->nick (); ## no critic (Modules::RequireExplicitInclusion)
			my $chatid = $msg->{params}->[0];
			my $text = decode ('utf8', $msg->{params}->[-1]);
			my $nick = prefix_nick ($msg->{prefix});
			my $answer;

			# Ивенты без текста нам не интересны
			unless (defined $text) {return;}

			# Команды, как правило, начинаются с csign, это обычно . (точка)
			if (substr($text, 0, length $c->{csign}) eq $c->{csign}) {
				$answer = Command ($self, $chatid, $nick, $text);

				unless (defined $answer && $answer ne '') {
					return;
				}
			} # То, что не команды мы игнорируем.

			if (defined $answer) {
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

			if (defined($c->{identify}) && $c->{identify} ne '') {
				# freenode/libera.chat identification style
				$MAIN::IRC->send_srv ( ## no critic (Modules::RequireExplicitInclusion)
					PRIVMSG => 'NickServ',
					sprintf ('identify %s %s', $c->{nick}, $c->{identify}),
				);
			}

			# Джойнимся ко всем каналам, кроме assist-а
			for my $chan (sort (keys %{$c->{channels}})) {
				next if $chan eq 'assist';

				if ($chan eq 'notify') {
					next unless ($c->{notifications}->{enabled});
				}

				$MAIN::IRC->send_srv ('JOIN', $c->{channels}->{$chan}); ## no critic (Modules::RequireExplicitInclusion)
			}

			# К assist-у джойнимся в последнюю очередь, чтобы быть уже приджойненным ко всему остальному
			$MAIN::IRC->send_srv ('JOIN', $c->{channels}->{assist});

			return;
		},

		connfail    => sub {
			$log->err ('[ERROR] Connection failed, trying again');
			sleep 5;

			$MAIN::IRC->connect (
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
			$log->info('[INFO] Registered on server');
			$MAIN::IRC->enable_ping (60);
			return;
		},

		disconnect  => sub {
			# TODO: Data::Dump here and debug $_[1], it's undef!
			$log->err("[ERROR] Disconnected: $_[1]");
			sleep 5;

			$log->info ("[INFO] Re-connecting to $c->{server}:$c->{port}");
			$MAIN::IRC->connect(
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
						$kicker_nick, $channel, decode('utf8', $msg),
					);
				} else {
					$log->warn (sprintf '[WARN] %s kicked me from %s with no reason', $kicker_nick, $channel);
				}

				sleep 3;
				$log->info ("[INFO] Re-joining to $channel");
				$MAIN::IRC->send_srv ('JOIN', $channel);
			}

			return;
		},

		nick_change => sub {
			my ($self, $old_nick, $new_nick, $is_myself) = @_;

			if ($is_myself) {
				$log->warn(sprintf '[WARN] My nick have been changed from %s to %s', $old_nick, $new_nick);
			}

			return;
		},

		part        => sub {
			my ($self, $nick, $channel, $is_myself, $msg) = @_;

			if ($is_myself) {
				if (defined $msg &&  $msg ne '') {
					$log->warn(sprintf '[WARN] I left %s channel: %s', $channel, $msg);
				} else {
					$log->warn(sprintf '[WARN] I left %s channel', $channel);
				}
			} else {
				if (defined $msg &&  $msg ne '') {
					$log->warn(sprintf '[INFO] %s left %s channel: %s', $nick, $channel, $msg);
				} else {
					$log->warn(sprintf '[INFO] %s left %s channel', $nick, $channel);
				}
			}

			return;
		},

		join        => sub {
			my ($self, $nick, $channel, $is_myself) = @_;

			if ($is_myself) {
				$log->info (sprintf '[INFO] I joined to %s channel', $channel);
			} else {
				$log->info( sprintf '[INFO] %s joined to %s channel', $nick, $channel);

				# Покажем отложенные уведомления пользователю в личку
				if ($channel eq $c->{channels}->{notify}) {
					# Юзер заджойнился в канал с нотификашками, надо ему в приват вывалить все нотификашки, которые
					# были, пока его не было, либо то, что было за последние retention_days
					my $notifications = rakedata ('delayed_notifications');
					my $title_shown = 0;

					foreach my $timestamp (sort keys (%{$notifications})) {
						my $show = 1;
						my $item = decode_json ($notifications->{$timestamp});

						unless (defined $item) {
							$log->error ("[ERROR] Unable to decode json from $c->{db}->{delayed_notifications} db: $EVAL_ERROR");
						}

						foreach my $user (@{$item->{users_shown}}) {
							if ($user eq $nick) {
								$show = 0;
								last;
							}
						}

						if ($show) {
							push @{$item->{users_shown}}, $nick;

							unless ($title_shown) {
								PrintMsg ($nick, 'Missing notifications since your last visit or for 2 days:');
								$title_shown = 1;
							}

							my $msg = sprintf (
								'Channel %s: %s',
								$item->{channel},
								$item->{message},
							);

							if ($c->{delayed_notifications}->{enabled}) {
								PrintMsg ($nick, $msg);
							}

							deletedata ('delayed_notifications', $item->{timestamp});
							# TODO: pretty jsonl
							my $json = encode_json $item;

							storedata (
								$c->{db}->{delayed_notifications},
								$item->{timestamp},
								$json,
								$item->{expiration_time},
							);
						}
					}
				}

				# Заинвайтим пользователя в канал notify
				if ($channel eq $c->{channels}->{assist}) {
					if ($c->{notifications}->{enabled}) {
						$log->debug ("[DEBUG] Inviting $nick to $c->{channels}->{notify}");
						$MAIN::IRC->send_srv ('INVITE', $nick, $c->{channels}->{notify});
					}
				}
			}

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
			'https://github.com/elersir/meow-irc-bot',
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
		$MAIN::IRC->enable_ssl (); ## no critic (Modules::RequireExplicitInclusion)
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
