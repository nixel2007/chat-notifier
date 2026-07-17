# ---------------------------------------------------------------------------
# Прокси отправки сообщений в Telegram: OneScript 2.1 + winow + messenger.
# Базируемся на официальном образе OneScript (FDD на .NET 8), в нём уже есть
# oscript и opm на PATH (/var/oscript) и настроенная локаль ru_RU.
# ---------------------------------------------------------------------------
FROM evilbeaver/onescript:2.1.0

WORKDIR /opt/chat-notifier

# Зависимости ставим локально в ./oscript_modules из packagedef (пины версий).
# opm install -l читает packagedef, тянет только прод-зависимости (winow,
# messenger, jason, autumn-validate и их транзитив; autumn 4.0, decorator,
# validate) и генерирует src/oscript.cfg с lib.additional=../oscript_modules,
# по которому main.os находит библиотеки. Поэтому packagedef и src нужны до
# установки.
COPY packagedef lib.config autumn-properties.json ./
COPY src ./src
RUN opm install -l

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Порт по умолчанию (Railway переопределяет переменной окружения PORT).
ENV PORT=3333
EXPOSE 3333

ENTRYPOINT ["/docker-entrypoint.sh"]
