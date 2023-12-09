package BotLib::Util;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open                 qw (:std :utf8);
use English              qw ( -no_match_vars );

use Carp                 qw (cluck);
use CHI                     ();
use Digest::CRC          qw (crc32_hex);
use Digest::SHA          qw (sha1_base64 sha1_hex sha224_hex sha256_hex sha384_hex sha512_hex);
use Digest::MD5          qw (md5_base64 md5_hex);
use Digest::MurmurHash   qw (murmur_hash);
use Encode               qw (encode_utf8);
use Log::Any             qw ($log);
use Math::Random::Secure qw (irand);
use MIME::Base64         qw (encode_base64);
use Time::HiRes          qw (gettimeofday);
use URI::URL             qw (url);

use BotLib::Conf         qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (timems trim urlencode utf2b64 utf2sha1 utf2md5 utf2sha1hex utf2sha224hex utf2sha256hex
	                 utf2sha384hex utf2sha512hex utf2md5hex utf2crc32hex utf2murmurhash irandom runcmd storedata
	                 cleanexpireddata rakedata deletedata PrintMsg);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Возвращает текущее время с точностью до миллисекунды
# $string timems()
sub timems {
	my @time = gettimeofday ();
	return join '', @time;
}

# Убирает пробельные символы с обоих концов даденной строки
# $str trim($str)
sub trim {
	my $str = shift;

	unless (defined $str) {
		cluck '[ERROR] Str is undefined';
		return '';
	}

	if ($str eq '') {
		return $str;
	}

	while (substr ($str, 0, 1) =~ /^\s$/xms) {
		$str = substr $str, 1;
	}

	while (substr ($str, -1, 1) =~ /^\s$/xms) {
		chop $str;
	}

	return $str;
}

# Кодирует даденную строку согласно стандарту кодирования URL-ов
# $str urlencode($url)
sub urlencode {
	my $str = shift;

	unless (defined $str) {
		cluck '[ERROR] Str is undefined';
		return '';
	}

	my $urlobj = url $str;
	return $urlobj->as_string;
}

# Кодирует даденную строку "по base64"
# $str utf2b64($str)
sub utf2b64 {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return encode_base64 '';
	}

	if ($string eq '') {
		return encode_base64 '';
	}

	my $bytes = encode_utf8 $string;
	return encode_base64 $bytes;
}

# Берёт от даденной строки sha1 и кодирует "по base64"
# Пример применения - имена файлов из каких-то unsafe(для файловой системы)-строк
# $str utf2sha1($str)
sub utf2sha1 {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha1_base64 '';
	}

	if ($string eq '') {
		return sha1_base64 '';
	}

	my $bytes = encode_utf8 $string;
	return sha1_base64 $bytes;
}

# Берёт от даденной строки sha1 и кодирует "по base64"
# Пример использования - имена файлов из unsafe(для файловой системы)-параметров
# $str utf2md5($str)
sub utf2md5 {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha1_base64 '';
	}

	if ($string eq '') {
		return sha1_base64 '';
	}

	my $bytes = encode_utf8 $string;
	return md5_base64 $bytes;
}

# Берёт от даденной строки sha224, как утилита sha224sum
# $str utf2sha224hex($str)
sub utf2sha1hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha1_hex '';
	}

	if ($string eq '') {
		return sha1_hex '';
	}

	my $bytes = encode_utf8 $string;
	return sha1_hex $bytes;
}

# Берёт от даденной строки sha224, как утилита sha224sum
# $str utf2sha224hex($str)
sub utf2sha224hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha224_hex '';
	}

	if ($string eq '') {
		return sha224_hex '';
	}

	my $bytes = encode_utf8 $string;
	return sha224_hex $bytes;
}

# Берёт от даденной строки sha256, как утилита sha1sum
# $str utf2sha256hex($str)
sub utf2sha256hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha256_hex '';
	}

	if ($string eq '') {
		return sha256_hex '';
	}

	my $bytes = encode_utf8 $string;
	return sha256_hex $bytes;
}

# Берёт от даденной строки sha1, как утилита sha384sum
# $str utf2sha384hex($str)
sub utf2sha384hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha384_hex '';
	}

	if ($string eq '') {
		return sha384_hex '';
	}

	my $bytes = encode_utf8 $string;
	return sha384_hex $bytes;
}

# Берёт от даденной строки sha1, как утилита sha512sum
# $str utf2sha512hex($str)
sub utf2sha512hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return sha512_hex '';
	}

	if ($string eq '') {
		return sha512_hex '';
	}

	my $bytes = encode_utf8 $string;
	return sha512_hex $bytes;
}

# Берёт от даденной строки md5, как утилита md5sum
# $str utf2md5hex($str)
sub utf2md5hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return md5_hex '';
	}

	if ($string eq '') {
		return md5_hex '';
	}

	my $bytes = encode_utf8 $string;
	return md5_hex $bytes;
}

# Берёт от даденной строки crc32
# $str utf2crc32hex($str)
sub utf2crc32hex {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return crc32_hex '';
	}

	if ($string eq '') {
		return crc32_hex '';
	}

	my $bytes = encode_utf8 $string;
	return crc32_hex $bytes;
}

# Берёт от даденной строки murmur_hash
# $str utf2murmurhash($str)
sub utf2murmurhash {
	my $string = shift;

	unless (defined $string) {
		cluck '[ERROR] String is undefined';
		return murmur_hash '';
	}

	if ($string eq '') {
		return murmur_hash '';
	}

	my $bytes = encode_utf8 $string;
	return murmur_hash $bytes;
}

# Возвращает рандомное целое число от 0 до даденного числа
# $num irand($num)
sub irandom {
	my $num = shift;
	return irand ($num);
}

# Execs command via backticks and handles errors in generic way
# Returns hashref
# $ret runcmd($cmd, @args)
sub runcmd {
	my @cmd = @_;

	my $out = '';
	my $ret->{error} = 0;
	$ret->{success}  = 1;
	my $err_msg = '';

	$out = `@cmd`;

	if ($CHILD_ERROR != 0) {
		$err_msg = sprintf 'Unable to run %s', join (' ', @cmd);
		$log->err ("[ERROR] $err_msg");
		$ret->{error}   = 1;
		$ret->{success} = 0;
		$ret->{err_msg} = $err_msg;
	} else {
		$ret->{text} = $out;
	}

	return $ret;
}

# Сохраняет данные в указанной БД с указанным expiration time. Expiration time может быть never, unixtimestamp, relative.
# Где unixtimestmp в секундах (с 1970 года), relative - это например 2 days.
# undef storedata($dbname, $key, $value, $time)
sub storedata {
	my $dbname = shift;
	my $key    = shift;
	my $value  = shift;
	my $time   = shift;

	cluck "[ERROR] datadir undefined in config"    unless (defined $c->{datadir});
	cluck "[ERROR] database not defined in config" unless (defined $c->{db}->{$dbname});

	my $db_path = sprintf '%s/%s', $c->{datadir}, $c->{db}->{$dbname};

	my $cache = CHI->new (
		driver   => 'BerkeleyDB',
		root_dir => $db_path,
	);

	$cache->set ($key, $value, $time);
	$log->debug ("[DEBUG] key $key with value $value and exp $time stored to $dbname");

	return;
}

# Удаляет протухшие ключи из указанной бд
# undef cleanexpireddata($dbname)
sub cleanexpireddata {
	my $dbname = shift;

	# TODO: check that db defined in config
	my $db_path = sprintf '%s/%s', $c->{datadir}, $c->{db}->{$dbname};

	my $cache = CHI->new (
		driver   => 'BerkeleyDB',
		root_dir => $db_path,
	);

	foreach my $entry ($cache->get_keys ()) {
		unless ($cache->is_valid ($entry)) {
			$cache->remove ($entry);
			$log->debug ("[DEBUG] Expired key $entry removed from $dbname");
		}
	}

	return;
}

# Выгребает ключ-значение из указанной БД в формате ссылочной структуры. Ключ гарантированно не протухший
# dataref rakedata($dbname)
sub rakedata {
	my $dbname = shift;

	# TODO: check if db exist
	my $db_path = sprintf '%s/%s', $c->{datadir}, $c->{db}->{$dbname};

	cluck unless defined $c->{db}->{$dbname};
	cluck unless defined $c->{datadir};
	my $cache = CHI->new (
		driver   => 'BerkeleyDB',
		root_dir => $db_path,
	);

	my $hashref;

	foreach ($cache->get_keys()) {
		my $cache_object = $cache->get_object ($_);
		$hashref->{$cache_object->key ()} = $cache_object->value ();
	}

	return $hashref;
}

# Удаляет ключ и ассоциированные с ним данные из указанной бд
# undef deletedata($dbname, $key)
sub deletedata {
	my $dbname = shift;
	my $key    = shift;

	cluck unless defined $c->{db}->{$dbname};
	cluck unless defined $c->{datadir};
	my $db_path = sprintf '%s/%s', $c->{datadir}, $c->{db}->{$dbname};

	my $cache = CHI->new (
		driver   => 'BerkeleyDB',
		root_dir => $db_path,
	);

	$cache->remove ($key);
	$log->debug ("[DEBUG] Key $key removed from $dbname");

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

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
