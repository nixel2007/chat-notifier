# chat-notifier

[![Тестирование](https://github.com/nixel2007/chat-notifier/actions/workflows/testing.yml/badge.svg)](https://github.com/nixel2007/chat-notifier/actions/workflows/testing.yml)

Минималистичный HTTP-прокси для отправки сообщений в Telegram. Один защищённый
эндпоинт принимает `chat_id`, `message` и авторизацию, а на выходе обращается к
Telegram Bot API и отправляет сообщение в канал или чат.

Стек: [OneScript](https://oscript.io) 2.1, контейнер компонентов
[autumn](https://github.com/autumn-library/autumn) («ОСень») и веб-сервер
[winow](https://github.com/autumn-library/winow), сериализация/десериализация
JSON через [jason](https://github.com/nixel2007/jason), декларативная валидация
через [autumn-validate](https://github.com/autumn-library/autumn-validate)
(аннотация `&Валидно`), отправка через
[messenger](https://github.com/oscript-library/messenger) (транспорт `telegram`),
модульные и интеграционные тесты на
[oneunit](https://github.com/autumn-library/oneunit), деплой в
[Railway](https://railway.app) по `Dockerfile`.

## API

### `POST /send`

Отправка сообщения. Требует авторизации.

Заголовок авторизации — HTTP Basic (штатный механизм winow): `Логин:Токен`,
где логин — `PROXY_LOGIN` (по умолчанию `api`), а токен — `PROXY_TOKEN`.

Тело запроса — JSON (winow десериализует его прямо в типизированный объект силами
jason):

| Поле       | Тип    | Обязательное | Описание                                                     |
|------------|--------|--------------|--------------------------------------------------------------|
| `chat_id`  | строка | да           | ID чата/канала строкой (`"-1001234567890"`) или `"@username"` |
| `message`  | строка | да           | Текст сообщения                                              |
| `format`   | строка | нет          | `html`, `md` (markdown) или `text` (по умолчанию)           |

`chat_id` передаётся строкой: тип поля зафиксирован аннотацией `&Тип("Строка")`,
это исключает потерю точности на больших id.

Пример:

```bash
curl -X POST https://<ваш-домен>.up.railway.app/send \
  -u api:$PROXY_TOKEN \
  -H "Content-Type: application/json" \
  -d '{"chat_id": "-1001234567890", "message": "<b>Привет!</b>", "format": "html"}'
```

Ответы:

- `200 OK` — `{"ok": true, "chat_id": "..."}`
- `400` — тело запроса пустое/не JSON
- `401` — нет/неверная авторизация (заголовок `WWW-Authenticate: Basic`)
- `500` — тело не прошло валидацию (не заполнены `chat_id`/`message`): проверку
  выполняет напильник autumn-validate по аннотации `&Валидно`
- `502` — ошибка обращения к Telegram API

### `GET /health`

Проверка живости (без авторизации). Возвращает `{"ok": true}`. Используется как
healthcheck в Railway.

## Переменные окружения

| Переменная               | Обязательная | По умолчанию | Назначение                                         |
|--------------------------|--------------|--------------|----------------------------------------------------|
| `TELEGRAM_BOT_TOKEN`     | да           | —            | Токен бота из [@BotFather](https://t.me/BotFather) |
| `PROXY_TOKEN`            | да           | —            | Секрет авторизации входящих запросов               |
| `PROXY_LOGIN`            | нет          | `api`        | Логин для Basic-авторизации                        |
| `PORT`                   | нет          | `3333`       | Порт HTTP (Railway задаёт автоматически)           |

Секреты и порт приходят в приложение как детальки ОСени (`&Деталька`): ENV-провайдер
configor мапит `TELEGRAM_BOT_TOKEN` → `TELEGRAM.BOT.TOKEN`, `PROXY_TOKEN` →
`PROXY.TOKEN`, `winow_Порт` → `winow.Порт`. Бот должен быть администратором канала
(или участником чата), в который отправляются сообщения.

## Архитектура

Приложение собрано из компонентов ОСени; веб-обвязку даёт winow.

- **`src/Классы/КонтролОтправки.os`** — контроллер winow (тонкий веб-слой):
  Basic-авторизация (`&Роли`), приём типизированного тела (`&Тип("ЗапросОтправки")`,
  десериализация jason), декларативная валидация (`&Валидно`) и сериализация ответа
  через jason (`СериализаторJson`).
- **`src/Классы/СервисОтправки.os`** — желудь-сервис (`&Желудь`): нормализует формат
  и отправляет сообщение через messenger. Готовый мессенджер приходит через
  `&Пластилин`, поэтому сервис не знает о токенах.
- **`src/Классы/ДубМессенджера.os`** — дуб-конфигурация (`&Дуб`): завязь (`&Завязь`)
  создаёт и инициализирует транспорт telegram, токен берёт из детальки
  `TELEGRAM.BOT.TOKEN`.
- **`src/Классы/ЗапросОтправки.os`** — DTO тела запроса: имена полей для jason
  (`&Сериализуемое`), типы и обязательность для autumn-validate (`&Тип`, `&Заполнено`).
- **`src/main.os`** — точка входа: поднимает контейнер ОСени и веб-сервер winow.

## Структура проекта

```
.
├── src/
│   ├── main.os                     # точка входа: контейнер ОСени + веб-сервер
│   └── Классы/
│       ├── КонтролОтправки.os      # контроллер winow: /send и /health
│       ├── СервисОтправки.os       # желудь-сервис отправки
│       ├── ДубМессенджера.os       # дуб-конфигурация транспорта telegram
│       └── ЗапросОтправки.os       # DTO тела запроса
├── tests/
│   ├── СервисОтправкиТест.os        # модульные тесты чистой логики
│   ├── ЗапросОтправкиТест.os        # тесты ограничений DTO (autumn-validate)
│   ├── ИнтеграционныйТест.os        # эндпоинты через 1connector с моком транспорта
│   └── Классы/
│       ├── МокМессенджера.os        # заглушка транспорта
│       └── ДубМокаМессенджера.os    # &Верховный дуб, подменяющий мессенджер в тестах
├── autumn-properties.json          # конфиг winow (хост; порт — из env)
├── lib.config                      # объявление классов пакета
├── packagedef                      # описание opm-пакета и зависимостей
├── .github/workflows/testing.yml   # CI на autumn-library/workflows
├── Dockerfile
├── docker-entrypoint.sh
├── railway.toml
└── LICENSE
```

## Тестирование

Тесты написаны на [oneunit](https://github.com/autumn-library/oneunit) (требует
OneScript 2.0+):

- **модульные** — чистая логика сервиса (нормализация формата) и ограничения DTO
  (autumn-validate), без веб-сервера;
- **интеграционные** — поднимают полный контейнер и веб-сервер winow, дёргают
  реальные эндпоинты через [1connector](https://github.com/oscript-library/1connector);
  боевой транспорт заменён моком через `&Верховный` желудь, поэтому Telegram не
  вызывается, а отправленные сообщения проверяются.

Локально:

```bash
opm install -l --dev
oneunit e -d tests
```

CI (`.github/workflows/testing.yml`) гоняет тесты через переиспользуемый workflow
`autumn-library/workflows` на матрице версий OneScript.

## Публикация Docker-образа

`.github/workflows/publish-image.yml` собирает образ и публикует его в Docker Hub
на каждый push в `master` и на теги `v*`. Это выносит `opm install` из среды
деплоя (в Railway он периодически падал по таймауту к `hub.oscript.io`) - Railway
тянет уже готовый образ.

Для работы задайте в репозитории:

- переменные (**Settings → Secrets and variables → Actions → Variables**):
  `DOCKERHUB_USERNAME` (образ публикуется как `<username>/chat-notifier`; либо
  задайте полное имя в `DOCKERHUB_REPOSITORY`). Для автоredeploy Railway -
  `RAILWAY_SERVICE_ID`;
- секреты (**Secrets**): `DOCKERHUB_TOKEN` (Docker Hub access token). Для
  автоredeploy Railway - `RAILWAY_TOKEN`.

Джоба `deploy` дергает `railway redeploy` только когда задан `RAILWAY_SERVICE_ID`.

## Деплой в Railway

1. Создайте бота в [@BotFather](https://t.me/BotFather) и получите токен.
2. Добавьте бота администратором в целевой канал.
3. В Railway создайте сервис из **готового Docker-образа**
   `docker.io/<username>/chat-notifier:latest` (а не из репозитория) - тогда
   деплой не собирает образ и не упирается в таймауты сети.
4. В разделе **Variables** задайте `TELEGRAM_BOT_TOKEN` и `PROXY_TOKEN`
   (при необходимости `PROXY_LOGIN`).
5. В разделе **Settings → Networking** включите публичный домен.

`PORT` Railway передаёт сам; entrypoint прокидывает его в `winow_Порт`. Значение
по умолчанию при отсутствии `PORT` — `3333`.

## Локальный запуск

Через Docker:

```bash
docker build -t chat-notifier .
docker run --rm -p 3333:3333 \
  -e TELEGRAM_BOT_TOKEN=xxxxx \
  -e PROXY_TOKEN=your-secret \
  chat-notifier
```

## Лицензия

[MIT](LICENSE) © Nikita Fedkin
