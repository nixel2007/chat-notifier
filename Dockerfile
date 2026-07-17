# ---------------------------------------------------------------------------
# Прокси отправки сообщений в Telegram: OneScript 2.0.2 + winow + messenger.
# Базируемся на официальном образе OneScript (FDD на .NET 8), в нём уже есть
# oscript и opm на PATH (/var/oscript) и настроенная локаль ru_RU.
# ---------------------------------------------------------------------------
FROM evilbeaver/onescript:2.0.2

# Прод-зависимости (autumn 4.0, decorator, validate тянутся транзитивно).
# winow 0.11.3+ собирает маршруты из определения желудя, а autumn-validate 2.0
# регистрируется автосканом autumn 4.0 - контроллеры с &Валидно работают "из
# коробки", без обходных путей.
RUN opm install winow messenger jason autumn-validate

# Приложение. main.os подключает пакет через #Использовать ".." (нужен lib.config),
# конфиг autumn-properties.json читается из рабочего каталога.
WORKDIR /opt/chat-notifier
COPY lib.config autumn-properties.json ./
COPY src ./src
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Порт по умолчанию (Railway переопределяет переменной окружения PORT).
ENV PORT=3333
EXPOSE 3333

ENTRYPOINT ["/docker-entrypoint.sh"]
