package BotLib::Command::Todo;
# Имплементация команды todo

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open         qw (:std :utf8);
use English      qw ( -no_match_vars );

use Log::Any     qw ($log);

use BotLib::Util qw (storedata rakedata deletedata cleardata);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Todo);


# Парсит запрос команды todo
# $reply Todo($message)
sub Todo {
	my $message = shift;

	my $reply;

	if (($message eq 'todo') || ($message =~ /^todo\s+$/)) {
		# Просматриваем список todo
		$log->debug ('[DEBUG] got todo command without arguments');
		$reply = _todoPrint ();
	} elsif ($message =~ /^todo\s+\-d\s+(\d+)\s*$/) {
		# Удаляем пункт из списка todo
		$log->debug ('[DEBUG] got todo command with -d argument');

		deletedata ('todo', $1);

		# Выгребаем всё, чистим базу и заново втыкаем, по пути перенумеровав
		my $todo = rakedata ('todo');
		cleardata ('todo');

		my $counter = 1;

		foreach my $item_num (sort keys (%{$todo})) {
			storedata ('todo', $counter, $todo->{$item_num}, 'never');
			$counter++;
		}

		$reply = _todoPrint ();
	} else {
		# Добавляем пункт в список todo
		if ($message =~ /^todo\s+(.*)/) {
			my $data = $1;
			$log->debug ("[DEBUG] got todo command message: $message");
			my $todo = rakedata ('todo');
			my $num = int (keys %{$todo}) + 1;
			storedata ('todo', $num, $data, 'never');
			$reply = _todoPrint ();
		} else {
			$log->debug ('[DEBUG] got todo command with garbage');
		}
	}

	return $reply;
}

# Выгребает список todo-шек из базы
# $msg _todoPrint()
sub _todoPrint {
	$log->debug ('[DEBUG] raking data from todo db');
	my $todo = rakedata ('todo');
	my $msg = '';

	foreach (sort keys (%{$todo})) {
		$msg .= sprintf "%d. %s\n", $_, $todo->{$_};
	}

	return $msg;
}

1;
