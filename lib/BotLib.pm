package BotLib;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open                    qw (:std :utf8);
use English                 qw ( -no_match_vars );

use JSON::XS                   ();
use Log::Any                qw ($log);

use BotLib::Conf            qw (LoadConf);
use BotLib::Chan::Assist       ();
use BotLib::Chan::Registry     ();
use BotLib::Util            qw (runcmd);

use version; our $VERSION = qw (1.0);
use Exporter                qw (import);
our @EXPORT_OK =            qw (Command SigHandler SigIntHandler SigTermHandler SigQuitHandler);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Хэндлер, завершающий работу сервиса
# undef SigHandler($signal)
sub SigHandler {
	my $signal = shift;

	if (defined $MAIN::IRC) {                                          ## no critic (Modules::RequireExplicitInclusion)
		$log->info ('[INFO] Disconnect from server');

		if (defined $signal) {
			if ($signal eq 'exit') {
				$MAIN::IRC->send_raw ('QUIT :Quit by user request');   ## no critic (Modules::RequireExplicitInclusion)
			} else {
				$MAIN::IRC->send_raw ("QUIT :Quit by signal $signal"); ## no critic (Modules::RequireExplicitInclusion)
			}
		} else {
			$MAIN::IRC->send_raw ('QUIT :Quit with no reason');        ## no critic (Modules::RequireExplicitInclusion)
		}
	}

	if (defined ($c->{pidfile}) && -e $c->{pidfile}) {
		$log->info ("[INFO] Unlink $c->{pidfile}");
		unlink $c->{pidfile};
	}

	if (defined $signal) {
		if ($signal eq 'exit') {
			$log->info ('[INFO] Exit by user command');
		} else {
			$log->info ("[INFO] Exit by signal $signal");
		}

		exit 0;
	}

	# We should never see this in logs
	$log->info ('[INFO] Stay running because SigHandler called without signal name or reason');

	return;
}

# Хэндлер SigINT
# undef SigIntHandler()
sub SigIntHandler  { SigHandler ('INT');  return; }

# Хэндлер SigTERM
# undef SigTermHandler()
sub SigTermHandler { SigHandler ('TERM'); return; }

# Хэндлер SigQUIT
# undef SigQUITHandler()
sub SigQuitHandler { SigHandler ('QUIT'); return; }

# Парсер команд
# string Command($bot, $chatid, $chattername, $text)
sub Command {
	my $bot         = shift;
	my $chatid      = shift;
	my $chattername = shift;
	my $text        = shift;

	my $reply;
	my $csign = $c->{csign};

	return undef if (length ($text) <= length ($csign));

	$log->debug ("[DEBUG] Got message from $chattername in $chatid: $text");

	my $cmd = substr $text, length $csign;

	if ($chatid eq $c->{channels}->{assist}) {
		if ($cmd eq 'help' || $cmd eq 'помощь') {
			$reply = BotLib::Chan::Assist::Help ();
		} elsif ($cmd eq 'version'  ||  $cmd eq 'ver') {
			$reply = 'Версия нуль.чего-то_там.чего-то_там';
		} elsif ($text eq '=(' || $text eq ':(' || $text eq '):') {
			$reply = ':)';
		} elsif ($text eq '=)' || $text eq ':)' || $text eq '(:') {
			$reply = ':D';
		} elsif ($cmd eq 'ping') {
			$reply = 'pong';
		} elsif ($cmd eq 'cal') {
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
		} elsif ($cmd eq 'quit' || $cmd eq 'exit') {
			SigHandler ('exit');
		} elsif ($cmd =~ /^(todo\s*|todo\s+.+)$/) {
			$reply = BotLib::Chan::Assist::Todo ($cmd);
		} elsif ($cmd =~ /^b64\s(.*)/) {
			$reply = BotLib::Chan::Assist::B64Str ($1);
		} elsif ($cmd =~ /^md5\s(.*)/) {
			$reply = BotLib::Chan::Assist::Md5Str ($1);
		} elsif ($cmd =~ /^sha1\s(.*)/) {
			$reply = BotLib::Chan::Assist::Sha1Str ($1);
		} elsif ($cmd =~ /^sha224\s(.*)/) {
			$reply = BotLib::Chan::Assist::Sha224Str ($1);
		} elsif ($cmd =~ /^sha256\s(.*)/) {
			$reply = BotLib::Chan::Assist::Sha256Str ($1);
		} elsif ($cmd =~ /^sha384\s(.*)/) {
			$reply = BotLib::Chan::Assist::Sha384Str ($1);
		} elsif ($cmd =~ /^sha512\s(.*)/) {
			$reply = BotLib::Chan::Assist::Sha512Str ($1);
		} elsif ($cmd =~ /^crc32\s(.*)/) {
			$reply = BotLib::Chan::Assist::Crc32Str ($1);
		} elsif ($cmd =~ /^murmurhash\s(.*)/) {
			$reply = BotLib::Chan::Assist::MurmurhashStr ($1);
		} elsif ($cmd =~ /^urlencode\s(.*)/) {
			$reply = BotLib::Chan::Assist::UrlencodeStr ($1);
		} elsif ($cmd =~ /^rand\s+(.*)\s*/) {
			$reply = BotLib::Chan::Assist::IrandNum ($1);
		} elsif ($cmd eq 'unixtime') {
			$reply = time ();
		}
	} elsif ($chatid eq $c->{channels}->{registry}) {
		if ($cmd eq 'help' || $cmd eq 'помощь') {
			$reply = BotLib::Chan::Registry::Help ();
		} elsif ($cmd eq 'ls') {
			$reply = BotLib::Chan::Registry::ListProjects ();
		} elsif ($cmd =~ /^ls\s+(\S+)/) {
			$reply = BotLib::Chan::Registry::ListTags($1);
		}
	}

	return $reply;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
