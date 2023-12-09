package BotLib::Chan::Registry;
# Парсит команды и взаимодействует с докерным регистри, согласно спеке описанной вот тут:
# https://github.com/distribution/distribution/blob/5cb406d511b7b9163bff9b6439072e4892e5ae3b/docs/spec/api.md

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open         qw (:std :utf8);
use English      qw ( -no_match_vars );

use HTTP::Tiny      ();
use JSON::XS     qw (decode_json);
use Log::Any     qw ($log);

use BotLib::Conf qw (LoadConf);
use BotLib::Util qw (utf2b64 urlencode);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT = qw (Help ListProjects);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Возвращает список возможных команд
# $text Help()
sub Help {
	my $text  = '';
	my $csign = $c->{csign};

	$text .= "${csign}help    - это сообщение\n";
	$text .= "${csign}ls      - список репозиториев образов\n";
	$text .= "${csign}ls REPO - список тэгов образов в репозитории\n";

	return $text;
}

# Отображает список проектов в регистри
sub ListProjects {
	my $str = '';
	my $url = sprintf '%s/v2/_catalog', $c->{registry}->{url};

	my $s = getJson ($url, $c->{registry}->{user}, $c->{registry}->{password});

	if ($s->{success}) {
		foreach (@{$s->{struct}->{repositories}}) {
			$str .= $_ . "\n";
		}
	} else {
		$str = "Unable to list repositories";
	}

	return $str;
}

# Отображает список тэгов проекта
sub ListTags {
	my $repo = shift;
	$repo = urlencode ($repo);

	my $str = '';
	my $url = sprintf '%s/v2/%s/tags/list', $c->{registry}->{url}, $repo;

	my $s = getJson ($url, $c->{registry}->{user}, $c->{registry}->{password});

	if ($s->{success}) {
		foreach (@{$s->{struct}->{tags}}) {
			$str .= sprintf "%s:%s\n", $s->{struct}->{name}, $_;
		}
	} else {
		$str = "Unable to list tags for given repository";
	}

	return $str;
}

# Делает http GET-запрос и возвращает ответ ref-объектиком, ошибку записывает в лог.
# {success, error, status, text} get (url, user, pass)
sub get {
	my $url    = shift;
	my $user   = shift;
	my $pass   = shift;

	my $auth = 'Basic ' . utf2b64 ( sprintf('%s:%s', $user, $pass) );

	my $ret->{success} = 0;

	my $http = HTTP::Tiny->new(
		agent => "meow-irc-bot",
		timeout => 10,
		# Просто, отъебитесь с этой хуйнёй
		verify_SSL => 0,
		default_headers => { Authorization => $auth },
	);

	my $r = $http->get ($url);

	if ($r->{success}) {
		$ret->{success} = $r->{success};
		$ret->{text}    = $r->{content};
		$ret->{status}  = $r->{status};
	} else {
		$ret->{error}  = $r->{reason};
		$ret->{status} = $r->{status};

		$log->error( sprintf ("[ERRO] Unable to GET $url: %s %s", $r->{status}, $r->{reason}) );
	}

	return $ret;
}

# Раскодирует JSON, полученный из get-запроса в данный url и возвращает ref-структурку, ошибку декодирования записывает
# в лог.
# {success, error, status, struct{...}} getJson (url, user, pass)
sub getJson {
	my $url    = shift;
	my $user   = shift;
	my $pass   = shift;

	my $r = get ($url, $user, $pass);
	my $ret->{status} = $r->{status};
	$ret->{success}   = $r->{success};

	if ($r->{success}) {
		my $j = eval { decode_json($r->{text}) };

		unless (defined $j) {
			$ret->{success} = 0;
			$ret->{status}  = 500;
			$ret->{error}   = $EVAL_ERROR;

			$log->error( sprintf ("[ERRO] Unable to decode json GET-ed from $url: %s", $EVAL_ERROR) );

			return $ret;
		}

		$ret->{struct} = $j;
	} else {
		$ret->{error} = $r->{error};
	}

	return $ret;
}
