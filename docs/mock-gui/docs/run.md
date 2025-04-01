# Запуск приложения

Для запуска необходимо выполнить следующую команду:

```shell
sudo systemctl start mockgui
```

## Ручной запуск без service файла

Ручной запуск без service файла может выполняться от пользователя состоящего в группе `mock`.

Подготовка базы данных(делается один раз):

```shell
/opt/brepo/ruby33/bin/bundle exec sequel -m db/migrations sqlite://db/workbase.sqlite3
```

Запуск приложения

```shell
/opt/brepo/ruby33/bin/bundle exec /opt/brepo/ruby33/bin/ruby app.rb
```

## Использование приложения

Открыть в браузере страницу:

```
http://[ip]:8081
```
