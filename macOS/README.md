# Focus for macOS

Нативный перенос интерфейса Pomodoro Timer на Swift и SwiftUI. Веб-версия в `src/` сохранена как образец.

## Требования и запуск

- macOS 14 или новее.
- Xcode 26 со Swift 6.2 или новее; выбранный Xcode в `xcode-select`.
- Сторонние зависимости не требуются.

Откройте `macOS/Package.swift` в Xcode, выберите схему **Focus**, назначение **My Mac** и нажмите Run (⌘R).

Для сборки самостоятельного приложения из корня репозитория:

```bash
bash macOS/scripts/build-app.sh
open macOS/build/Focus.app
```

Готовое `Focus.app` можно перенести в «Программы». Скрипт использует локальную ad-hoc подпись; аккаунт разработчика и публикация не нужны для этой сборки на своём Mac. Сборка предназначена для архитектуры текущего Mac.

Для быстрой отладочной сборки:

```bash
bash macOS/scripts/build-app.sh debug
```

## Что перенесено

- Боковая навигация Home, Timer, Statistics и Settings.
- Светлая и тёмная темы, системные кнопки окна и SF Symbols.
- Главная с демонстрационными метриками и задачами, пустое состояние.
- Timers: прокручиваемые колёса часов/минут/секунд и ручной ввод с проверкой значений.
- Состояния запуска, паузы и завершения, кольцо прогресса, диалог сброса.
- Recents: список использованных длительностей и повторный запуск.
- Меню Prototype preview со всеми состояниями исходного интерфейса.
- Заглушки Statistics и Settings, соответствующие веб-версии.

Это **только интерфейс**. Start, Pause, Resume и Reset переключают демонстрационные состояния. Реального отсчёта, учёта рабочего времени, уведомлений, базы данных и облака нет. Recents и тема живут в памяти окна и сбрасываются после перезапуска. Метрики и задачи на Home — примеры. Состояние Time’s up доступно через Prototype preview.

## Структура

- `Sources/Focus/FocusApp.swift` — точка входа и окно.
- `Sources/Focus/WorkspaceView.swift` — навигация, тема, меню состояний и диалог.
- `Sources/Focus/HomeView.swift` — главная.
- `Sources/Focus/TimersView.swift` — настройка таймера, активные состояния и Recents.
- `Sources/Focus/DurationWheel.swift` — SwiftUI-колесо длительности.
- `Sources/Focus/Components.swift` — цвета и общие элементы.
- `Sources/Focus/InterfaceState.swift` — временное состояние интерфейса.
- `scripts/build-app.sh` — сборка локального `.app`.

Проверка компиляции: `cd macOS && swift build`. Форматирование: `swift format format --in-place --recursive macOS/Sources macOS/Package.swift` из корня репозитория.
