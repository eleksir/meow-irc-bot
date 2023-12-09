# Meow-IRC-bot - Простой ассистивный IRC бот

## About

Бот основан Perl модуле [AnyEvent::IRC][1].

Конфиг должен находиться в **data/config.json**, пример конфига расположен в **data/sample_config.json**.

Бота можно запустить через команду **bin/meow-irc-bot**.

Этого бота можно считать экспериментальным из-за отсутсвия всестороннего тестирования. Он сделан по принципу "works for
me". Он проверялся на работоспособность на MacOS "Big Sur" и Slackware Linux 15.0.

## Installation

Чтобы запустить бота, надо вначале его забутстрапить - загрузить и установить все нужные перловые модули.

Для MacOS нам понадобится xcode console tools. (Их предлагают установить при установке VS Code, например).

Для Linux нам понадобится "Development Tools" или похожий набор пакетов и дополнительно perl, perl-devel,
perl-local-lib, perl-app-cpanm, sqlite-devel, zlib-devel, openssl-devel, libdb4-devel (Berkeley DB devel), make.

После установки указанных пакетов, можно смело запускать:

```sh
bash bootstrap.sh
```

и всё необходимое будет скачано из интернетов, протестировано и установлено в локальный каталог vendor_perl.


[1]: https://metacpan.org/pod/AnyEvent::IRC
