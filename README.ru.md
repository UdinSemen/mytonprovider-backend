# mytonprovider-backend

Backend сервис для mytonprovider.org - сервис мониторинга провайдеров TON Storage.

## Описание

Данный backend сервис:

- Взаимодействует с провайдерами хранилища через ADNL протокол
- Мониторит производительность, доступность провайдеров, доступность хранимых файлов, проводит проверки здоровья
- Обрабатывает телеметрию от провайдеров
- Предоставляет API эндпоинты для фронтенда
- Вычисляет рейтинг, аптайм, статус провайдеров
- Собирает собственные метрики через **Prometheus**

## Установка и настройка

Для начала нам потребуется чистый сервер на Debian 12 с рут пользователем.

1. **Склонируйте скрипт для подключения по ключу**

Вместо логина по паролю, скрипт безопасности требует использовать логин по ключу. Этот скрипт нужно запускать на рабочей
машине, он не потребует sudo, а только пробросит ключи для доступа.

```bash
wget https://raw.githubusercontent.com/dearjohndoe/mytonprovider-backend/refs/heads/master/scripts/init_server_connection.sh
```

2. **Пробрасываем ключи и закрываем доступ по паролю**

```bash
USERNAME=root PASSWORD=supersecretpassword HOST=123.45.67.89 bash init_server_connection.sh
```

В случае ошибки man-in-the-middle, возможно вам стоит удалить known_hosts.

3. **Заходим на удаленную машину и качаем скрипт установки**

```bash
ssh root@123.45.67.89 # Если требует пароль, то предыдущий шаг завершился с ошибкой.

wget https://raw.githubusercontent.com/dearjohndoe/mytonprovider-backend/refs/heads/master/scripts/setup_server.sh
```

4. **Запускаем настройку и установку сервера**

Займет несколько минут.

```bash
PG_USER=pguser PG_PASSWORD=secret PG_DB=providerdb NEWFRONTENDUSER=jdfront NEWSUDOUSER=johndoe NEWUSER_PASSWORD=newsecurepassword bash ./setup_server.sh
```

По завершении выведет полезную информацию по использованию сервера.

## Разработка

### Конфигурация VS Code

Создайте `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Package",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd",
            "buildFlags": "-tags=debug",    // для обработки OPTIONS запросов без nginx при разработке
            "env": {...}
        }
    ]
}
```

## Структура проекта

```
├── cmd/                   # Точка входа приложения, конфиги, инициализация
├── pkg/                   # Пакеты приложения
│   ├── cache/             # Кастомный кеш
│   ├── httpServer/        # Fiber хандлеры сервера
│   ├── models/            # Модели данных для БД и API
│   ├── repositories/      # Вся работа с postgres здесь
│   ├── services/          # Бизнес логика
│   ├── tonclient/         # TON blockchain клиент, обертка для нескольких полезных функций
│   └── workers/           # Воркеры
├── db/                    # Схема базы данных
├── scripts/               # Скрипты настройки и утилиты
```

## API Эндпоинты

Сервер предоставляет REST API эндпоинты для:

- Сбора телеметрии провайдеров
- Информации о провайдерах и инструменты фильтрации
- Метрик

## Воркеры

Приложение запускает несколько фоновых воркеров:

- **Providers Master**: Управляет жизненным циклом провайдеров, проверками здоровья и хранимых файлов
- **Telemetry Worker**: Обрабатывает входящюю телеметрию
- **Cleaner Worker**: Чистит базу данных от устаревшей информации

## Лицензия

Apache-2.0

Этот проект был создан по заказу участника сообщества TON Foundation.

---

## Локальная разработка

Самый быстрый способ поднять всё локально (без сервера):

```bash
bash local_setup.sh
```

Скрипт автоматически:

1. Проверит зависимости (`docker`, `go`, `node`, `git`, `psql`)
2. Склонирует это репо и [mytonprovider-org](https://github.com/dearjohndoe/mytonprovider-org) если они отсутствуют
3. Запустит PostgreSQL в Docker
4. Применит схему базы данных
5. Установит зависимости фронтенда
6. Запустит бэкенд на `http://localhost:9090`
7. Запустит фронтенд на `http://localhost:3000`

Для остановки всех сервисов нажмите `Ctrl+C`.

### Зависимости

| Инструмент  | Установка                                       |
|-------------|-------------------------------------------------|
| Docker      | https://docs.docker.com/get-docker/             |
| Go 1.24+    | https://go.dev/dl/                              |
| Node.js 20+ | https://nodejs.org/                             |
| psql        | `brew install libpq && brew link libpq --force` |

### Переменные окружения

Скопируйте `.env.example` в `.env` и при необходимости отредактируйте:

```bash
cp .env.example .env
```

| Переменная             | По умолчанию | Описание                                                        |
|------------------------|--------------|-----------------------------------------------------------------|
| `DB_HOST`              | `localhost`  | Хост PostgreSQL                                                 |
| `DB_PORT`              | `5432`       | Порт PostgreSQL                                                 |
| `DB_USER`              | -            | Пользователь PostgreSQL                                         |
| `DB_PASSWORD`          | -            | Пароль PostgreSQL                                               |
| `DB_NAME`              | -            | Имя базы данных                                                 |
| `SYSTEM_PORT`          | `9090`       | Порт HTTP сервера                                               |
| `SYSTEM_ADNL_PORT`     | `16167`      | UDP порт ADNL                                                   |
| `SYSTEM_ACCESS_TOKENS` | -            | Bearer токены для `/metrics` и `GET /providers` (через запятую) |
| `SYSTEM_LOG_LEVEL`     | `1`          | `0`=Debug, `1`=Info, `2`=Warn, `3`=Error                        |
| `MASTER_ADDRESS`       | -            | Адрес discovery контракта TON Storage                           |
| `TON_CONFIG_URL`       | -            | URL глобального конфига TON                                     |
| `BATCH_SIZE`           | `100`        | Размер батча для обработки провайдеров                          |


## Исправленные баги

Проблемы обнаруженные и исправленные в процессе локальной установки:

| № | Файл                                       | Баг                                                                                                                                     | Исправление                                                                                             |
|---|--------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| 1 | `db/init.sql`                              | `CREATE SCHEMA ... AUTHORIZATION pguser` хардкодит имя роли - скрипт падает с любым другим пользователем БД                             | Заменено на `AUTHORIZATION CURRENT_USER`                                                                |
| 2 | `pkg/repositories/providers/repository.go` | `MAX(...)` без `COALESCE` возвращает `NULL` на пустой таблице -> `500` на `/api/v1/providers/filters`                                   | Добавлен `COALESCE(..., 0)` для полей `reg_time_days_max`, `max_bag_size_mb_min`, `max_bag_size_mb_max` |
| 3 | `scripts/build_backend.sh`                 | `MASTER_ADDRESS` установлен в фиктивный плейсхолдер `UQB3d3d3...0x0`                                                                    | Заменён на реальный адрес discovery контракта из библиотеки `tonutils-storage-provider`                 |
| 4 | `pkg/clients/ton/client.go`                | `WithRetry(20)` × `WithTimeout(5s)` = до 100 секунд молчания при недоступности TON lite server, игнорируя 20-секундный context deadline | Уменьшено количество ретраев до `3` (максимум 15 секунд)                                                |
| 5 | `pkg/workers/providersMaster/worker.go`    | `CollectNewProviders` логирует на уровне `Debug` - воркер выглядит полностью молчащим при ошибках                                       | Изменено на уровень `Info`                                                                              |
