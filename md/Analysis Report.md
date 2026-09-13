# Аналитический отчёт: byMakerCleaner
**Дата:** 2026-09-13 | **Текущая версия:** `ver.1.3.0` | **Ветка:** `ver.1.3.0`

---

## 1. Статус реализации по ТЗ

> Сводная таблица: что реализовано, что в планах, что отложено.

| Модуль / Фича | Статус | Версия | Примечание |
|---|---|---|---|
| Архитектура (xcodegen + PureMac в Vendor) | ✅ Готово | 1.0.1 | MIT-лицензированный донор |
| App Uninstaller (базовый, PureMac-based) | ✅ Готово | 1.0.1–1.0.9 | AppInfoFetcher + AppPathFinder |
| AppListView / AppDetailView (GPU-safe) | ✅ Готово | 1.0.2–1.0.4 | Только `Text`, никаких `Button` |
| Иконка и бренд byMakerCleaner | ✅ Готово | 1.0.1 | |
| System Cleaner / Smart Scan (10 категорий) | ✅ Готово | 1.0.11 | |
| Trash Bins (все тома, minimumSize:0) | ✅ Готово | 1.0.12–1.0.14 | |
| Исключения OCLP (displaypolicy, install.log) | ✅ Готово | 1.0.15 | |
| MenuBar Helper (CPU/RAM/Disk/Network) | ✅ Готово | 1.0.16–1.0.18 | |
| Login Items Manager | ✅ Готово | 1.0.20–1.0.30 | SMAppService + LaunchAgents/Daemons |
| Show in Finder (Login Items) | ✅ Готово | 1.0.30 | |
| Объединение Helper + Main App (один процесс) | ✅ Готово | 1.1.0 | `MenuBarExtra`, убран отдельный таргет-хелпер |
| Orphan Finder v1 (базовый) | ✅ Готово | 1.1.0 | Первичная реализация движка |
| Настраиваемый интервал опроса (1–60 сек) | ✅ Готово | 1.1.0 | `GeneralSettings` |
| Сортировки (Orphan, App List, Login Items) | ✅ Готово | 1.1.1 | по имени, размеру, статусу |
| Кнопка Settings в MenuBar (`SettingsLink`) | ✅ Готово | 1.1.1 | Исправлен баг с пустым окном |
| **Orphan Finder v2** (двухпроходный алгоритм) | ✅ Готово | **1.1.2** | AppPathFinder-based, аналог «второго скана» PureMac |
| **OrphanSafetyPolicy v2** (6 уровней + 50+ имён) | ✅ Готово | **1.1.3** | OCLP, Xsan, hidfw, SIP, kext, symlink guard |
| **App Uninstaller v2** (реальный суммарный размер) | ✅ Готово | **1.1.4** | Двухфазный пересчёт + Steam/Spotify/Epic |
| **App Uninstaller: безопасность** (изоляция файлов) | ✅ Готово | **1.1.5** | Developer.app (−30GB), Antigravity/IDE, CLIP STUDIO, OCLP |
| **Cask Database v2** (точные пути для 5406 приложений) | ✅ Готово | **1.1.6–1.1.8** | Стандартный ключ `lowercased()` (пробелы сохранены) |
| **App Uninstaller v3** (двухуровневая архитектура) | ✅ Готово | **1.1.6–1.1.8** | Verified (Cask) → мгновенно; Unknown → чекбоксы + `Deep Scan` |
| **App Uninstaller v3.1** (User Custom DB + Bundle ID) | ✅ Готово | **1.1.8** | `UserDatabase.json`, `bundleIDPaths`, thread-safe `NSLock` |
| **Contribute to Community** (экспорт User DB) | ✅ Готово | **1.1.9** | Экспорт в Downloads с датой, ссылка на GitHub Issues |
| **Cask DB In-App Update** (динамическое обновление) | ✅ Готово | **1.1.9+** | Homebrew API, парсинг на Swift, миграция User→Cask |
| **Bluetooth-виджет** (`IOBluetooth`) | ✅ Готово | **1.2.0** | |
| **Скриншот-тул** (`screencapture`) | ✅ Готово | **1.2.0** | OCLP-совместимо (`screencapture -i -c`) |
| **Дата последней очистки** (`UserDefaults`) | ✅ Готово | **1.2.0** | Ключ `lastCleanDate` в `CleanerView` |
| **Удалить папку `byMakerCleanerHelper/`** | ✅ Готово | **1.2.0** | Мёртвые файлы после объединения таргетов |
| **Maintenance** (RAM, DNS) | ✅ Готово | **1.2.0** | `purge`, `dscacheutil -flushcache` через `NSAppleScript` |
| **Health Indicator** (гейдж + уведомления) | ✅ Готово | **1.2.0** | `UNUserNotificationCenter` + `HealthScoreCalculator` |
| **Редизайн UI (Ретро-терминал)** | ✅ Готово | **1.3.0** | ASCII-стиль, чёрный фон, Sidebar, безопасные GPU-компоненты |

---

## 2. История итераций (подробный changelog)

### ver.1.0.1–1.0.9 — MVP: App Uninstaller

Первый рабочий прототип. Интегрирован код из **PureMac** (MIT-лицензия), перенесённый в папку `Vendor/`. Создана архитектура через **xcodegen** (`project.yml`) — проект никогда не редактируется вручную в Xcode.

- `AppInfoFetcher.swift` — сбор установленных приложений (`/Applications`, `~/Applications`)
- `AppPathFinder.swift` — эвристический поиск связанных файлов в `~/Library`
- `AppListView` / `AppDetailView` — GPU-safe: только `Text(...).onTapGesture {}`, без `Button`
- Кнопка Uninstall: перемещает `.app` + мусор в Корзину через `NSWorkspace.shared.recycle`
- `CrashReporter` добавлен в `standardLibrarySubdirectories` чтобы не удалять папку целиком (ver.1.0.9)

> **Причина GPU-safe подхода:** На старых Mac с Kepler GPU (OCLP) стандартный `Button` в SwiftUI вызывает Metal рендеринг (`CUIDraw CoreImage`), что приводит к крашу. Замена на `Text(...).onTapGesture {}` полностью устраняет проблему.

---

### ver.1.0.11 — System Cleaner / Smart Scan

Добавлен второй основной раздел приложения. Сканирует 10 категорий системного мусора:
- User Caches, System Logs, Application Logs, Saved Application State
- Browser Caches, Download Folder Analysis, Temp Files, Broken Preferences
- Old iOS Backups, Trash Bins

---

### ver.1.0.12–1.0.15 — Trash Bins & OCLP

- **ver.1.0.12:** Исправлен баг Clean для Trash Bins — использовать `removeItem` (файлы уже в Корзине), а не `trashItem`
- **ver.1.0.13:** Trash Bins сканирует все тома (не только системный), корректное сообщение на Done-экране
- **ver.1.0.14:** `minimumSize: 0` — показывает все файлы включая `.DS_Store`, результат совпадает с Finder
- **ver.1.0.15:** Исключены `displaypolicy` и `install.log` из System Junk — критически важны для OCLP-пользователей

---

### ver.1.0.16–1.0.18 — MenuBar Helper

Отдельный таргет **byMakerCleanerHelper** с виджетом в строке меню:
- **SystemMetricsService:** CPU%, RAM (used/total), Disk (free/total), Network (↑↓)
- **MenuBarPopoverView:** попап по клику с метриками и кнопками

> **Проблема на Kepler:** SwiftUI-анимации вызывают Metal compute shader crash. Решение: убрать все `withAnimation`, заменить `ProgressView` на текстовый прогресс `[████░░░░]`, отключить `NSWindow.allowsAutomaticWindowTabbing`.

---

### ver.1.0.20–1.0.30 — Login Items Manager

Полноценный менеджер автозагрузки с тремя источниками:
1. **Apps (SMAppService)** — приложения, зарегистрированные через macOS API (через AppleScript `system events`)
2. **LaunchAgents** — пользовательские `~/Library/LaunchAgents` и `/Library/LaunchAgents`
3. **LaunchDaemons** — `/Library/LaunchDaemons` (системные)

- Toggle вкл/выкл через `SMAppService.mainApp.register()`
- Show in Finder (ver.1.0.30): открывает `.plist` в Finder
- GPU-safe toggle: кастомные `Text`-переключатели вместо `Toggle`, исправлен `CUIDraw CoreImage` crash (ver.1.0.28–1.0.29)

---

### ver.1.1.0 — Объединение таргетов + Orphan Finder v1

Ключевая архитектурная реорганизация:

- Helper и Main App объединены в **один процесс** через `MenuBarExtra` (SwiftUI)
- Папка `byMakerCleanerHelper/` сохранилась в репозитории как мёртвый код — **не удалена** (технический долг)
- Добавлен **Orphan Finder v1**: первичная реализация поиска «осиротевших» файлов от удалённых приложений
- Добавлены **General Settings**: выбор интервала метрик (1, 2, 5, 10, 15, 25, 30, 45, 60 сек)
- Исправлен баг кнопки Settings в MenuBar (открывала пустое окно → заменена на `SettingsLink`)

---

### ver.1.1.1 — UI Improvements + Orphan Finder Fix

- **Orphan Finder:** добавлен список исключений `skipReverse` для системных сервисов (WindowServer, Homebrew и др.) — устранены ложные срабатывания
- **Сортировки:** единый стиль для App List, Login Items, Orphan Finder: по имени / размеру / статусу
- **MenuBar Settings:** кнопка исправлена (macOS 14+ `SettingsLink`)

---

### ver.1.1.2 — Orphan Finder v2 (двухпроходный алгоритм)

**Принципиальная переработка движка** — воспроизводит точное поведение «второго скана» PureMac:

```
Pass 1 — Build Map (параллельно через TaskGroup):
  ├── AppInfoFetcher.fetchInstalledApps() → список всех приложений
  ├── Для каждого: AppPathFinder.findPaths() параллельно
  └── Результат: Set<String> occupiedPaths (карта всех занятых файлов)

Pass 2 — Reverse Scan (depth=1):
  ├── Обойти OrphanSafetyPolicy.allowedRoots
  ├── Для каждого кандидата: если путь в occupiedPaths → пропустить
  └── Прошёл все проверки → orphan
```

- Старый алгоритм давал ~40 результатов (включая файлы установленных приложений)
- Новый даёт ~15–20 реальных orphan-файлов (совпадает с PureMac)
- Добавлен GPU-safe двухфазный прогресс-индикатор: `[████░░░░]`
- `OrphanFinderViewModel`: новые состояния `buildingMap` / `scanning` + `mapProgress`
- `project.yml`: `SWIFT_VERSION 5.0 → 6.0`, удалена мёртвая URL-scheme `bymakercleaner://`

---

### ver.1.1.3 — OrphanSafetyPolicy v2 (6 уровней защиты)

Расширение политики безопасности до **6 уровней**:

| Уровень | Что проверяется | Примеры |
|---|---|---|
| **L1** | `highRiskHomeDotPaths` | `.ssh`, `.aws`, `.kube`, `.gnupg`, `.cargo`, `.pip`, `.zshrc` |
| **L2** | `allowedRoots` — строгое соответствие | Только 8 разрешённых директорий |
| **L3** | `blockedFragments` | Preferences, Containers, Security, Extensions, Kernel |
| **L4** | `com.apple.*` prefix | Все Apple-файлы по имени |
| **L5** | `safeNameBlocklist` (50+ имён) | OCLP, Xsan, hidfw, SIP, kext, Time Machine, APFS, recovery |
| **L6** | Symlink guard | Симлинки никогда не обрабатываются |

**L5 — критически важные категории:**
- 🔴 OCLP/OpenCore: `dortania`, `opencore`, `oclp`, `ocvalidate`
- 🔴 Apple ФС: `xsan`, `afp`, `smb`
- 🔴 Firewall: `hidfw`, `alf`, `socketfilterfw`
- 🔴 SIP: `amfid`, `csr`, `syspolicyd`
- 🔴 Kext: `kextd`, `kextcache`, `sysextd`
- 🔴 Time Machine / APFS: `timemachine`, `backupd`, `apfs`
- 🔴 Boot/Recovery: `recovery`, `bootp`, `bless`, `efi`, `nvram`
- 🟡 Power mgmt: `powerlog`, `sysdiagnose`, `spindump`

---

### ver.1.1.4 — App Uninstaller v2: реальный суммарный размер

**Проблема:** `AppInfoFetcher.appSize()` считал только `.app`-бандл (Steam.app = 11 MB). Реальный размер: Steam + `Library/Application Support/Steam` (1.2 GB) + `Library/Caches/Steam` (83 MB) = ~1.3 GB.

**Решение — двухфазная загрузка:**
```
Phase 1 (мгновенно): fetchInstalledApps() → показать список с .app-only размерами
Phase 2 (фоново, TaskGroup): AppPathFinder.findPaths() для каждого приложения параллельно
  → FileSizeCalculator суммирует все найденные пути
  → batch-update всех размеров одним @MainActor publish при завершении
```

- `InstalledApp.size`: `let → var` (мутабельный для async-обновления)
- `AppState.isRecalculatingSizes`: новый `@Published` флаг
- Header: `calculating sizes...` пока идёт Phase 2 (GPU-safe: Text)

**Добавлены `AppCondition.forceIncludePaths` для игр:**
- Steam (`com.valvesoftware.steam`): `Application Support/Steam`, `Caches/Steam`
- Epic Games Launcher: `Application Support/Epic Games`
- Battle.net: `Application Support/Battle.net`
- Spotify: `Application Support/Spotify`, `Caches/com.spotify.client`

**Ожидаемые результаты:** Steam ~1.3 GB, Firefox ~1 GB+, Spotify ~500 MB+ (совпадает с CleanMyMac).

---

### ver.1.1.5 — App Uninstaller: критические исправления безопасности

Четыре проблемы с «разливанием» файлов из одного приложения на другое:

**Проблема 1: Developer.app показывал 8.58 GB**
- Причина: имя `Developer` совпадало с `~/Library/Developer` (4.6 GB) и `/Library/Developer` (28 GB)
- Исправление: `~/Library/Developer` и `/Library/Developer` добавлены в глобальный `skipPaths`
- `AppCondition` для `developer.apple.wwdc-release` с жёсткими `includeTerms` и `excludeTerms`

**Проблема 2: Antigravity показывал 1.3 GB (ожидалось ~520 MB)**
- Причина: токен `antigravity` захватывал файлы Antigravity IDE (36 MB+ в Application Support)
- Исправление: отдельные `AppCondition` для `com.google.antigravity` и `com.google.antigravity-ide` с взаимными `excludeTerms`

**Проблема 3: CLIP STUDIO показывал 1.62 GB (ожидалось ~330 MB)**
- Причина: имя `clip studio` захватывало файлы CLIP STUDIO PAINT
- Исправление: `AppCondition` для каждого приложения с взаимными `excludeTerms`

**Проблема 4: OpenCore-Patcher показывал 1 GB**
- Исправление: `AppCondition` по Bundle ID с `excludeTerms` блокирующими `dortania`, `opencore`, `oclp`

---

### ver.1.1.6–1.1.8 — Cask Database v2 + App Uninstaller v3/v3.1

Масштабный рефакторинг App Uninstaller — **принципиально новая архитектура**:

#### Cask Database (интеграция Homebrew)

```
Источник: formulae.brew.sh/api/cask.json
Скрипт: md/prompts and scripts/generate_cask_db.py
Результат: CaskDatabase.swift (6600+ строк, 5406 приложений)
```

- `zapPaths`: словарь `[appName.lowercased(): [String]]` — точные пути к мусорным файлам
- `bundleIDPaths`: словарь `[bundleID.lowercased(): [String]]` — поиск по Bundle ID (для App Store-приложений)
- `normalize_key()` = стандартный `lowercased()` без удаления пробелов — совместимость с Homebrew

> **Ключевое решение:** `"Google Chrome"` → ключ `"google chrome"` → найдено ✅. Пробелы сохранены.

#### App Uninstaller v3 — двухуровневая архитектура

| Уровень | Триггер | Скорость | Точность |
|---|---|---|---|
| **✅ Verified (Cask DB)** | Автоматически при загрузке | ⚡ Мгновенно (только `stat()`) | 100% (данные Homebrew) |
| **👤 User Verified (UserDB)** | Автоматически при загрузке | ⚡ Мгновенно (твои пути) | 100% (ты подтвердил) |
| **⚠️ Unknown (Эвристика)** | Только по явному запросу | 🔍 Медленно (обход диска) | ~85% |

#### App Uninstaller v3.1 — UserDatabase + Bundle ID

- **`UserDatabase.swift`**: сохранение пользовательских путей в `~/Library/Application Support/byMakerCleaner/UserDatabase.json`
- Thread-safe: `NSLock` + `@unchecked Sendable`
- Приоритет: UserDB → CaskName → CaskBundleID → Heuristic
- После Deep Scan: кнопка **«💾 Add to My Database»** сохраняет найденные пути

#### Алгоритм загрузки (v3.1)

```
AppInfoFetcher.fetchInstalledApps():
  Для каждого .app:
  1. Найдено в UserDatabase (bundleID)? → 👤 User Verified (мгновенно)
  2. Найдено в CaskDatabase.zapPaths[name.lowercased()]? → ✅ Verified
  3. Найдено в CaskDatabase.bundleIDPaths[bundleID.lowercased()]? → ✅ Verified
  4. Иначе → ⚠️ Unknown

UI:
  Секция "👤 User Verified": tap → мгновенный список (сохранённый тобой)
  Секция "✅ Verified Apps": tap → мгновенный список (Cask DB пути)
  Секция "⚠️ Unknown Apps": ☐ чекбокс + кнопка "Deep Scan (N)"
    └── Deep Scan → AppPathFinder.findPaths() (эвристика)
    └── После Deep Scan → 💾 "Add to My Database" (сохраняет в UserDB)
```

#### Инструменты генерации условий

- `tools/generate_app_conditions.py` — генерирует `AppCondition` из `cask_paths.json`
- `tools/cask_paths.json` — исходные данные для условий (337 строк)
- `Conditions.swift` расширен до 472+ строк (473 новых записей)
- `Glob.swift` — добавлен для раскрытия путей с `~` и `*`

---

### ver.1.1.9 — Contribute to Community + Cask DB In-App Update

#### Contribute to Community

Раздел в General Settings для помощи сообществу Homebrew Cask:
- Кнопка **«Export Database»**: копирует `UserDatabase.json` в `~/Downloads/byMakerCleaner_UserDB_YYYY-MM-DD.json`
- Ссылка **«How to submit?»** → `https://github.com/Homebrew/homebrew-cask/issues`
- Инструкция: 1. Экспорт → 2. Открыть ссылку → 3. Прикрепить JSON к issue/PR

> Автоматическое открытие браузера **не делаем** — это вызывает ощущение небезопасности у пользователей.

#### Cask DB In-App Update

`CaskDatabase` превращён из `enum` в `final class CaskDatabase: @unchecked Sendable` (singleton):

```
При старте приложения:
  Есть ParsedCaskDB.json в Application Support? → загрузить его
  Нет? → использовать встроенный хардкод (defaultZapPaths/defaultBundleIDPaths)

CaskDatabaseUpdater.checkUpdate():
  1. HEAD-запрос к formulae.brew.sh/api/cask.json
  2. Сравнение ETag с UserDefaults["lastCaskETag"]
  3a. ETag совпадает → state = .upToDate
  3b. ETag новый    → state = .updateAvailable(etag:)

CaskDatabaseUpdater.downloadAndInstall(etag:):
  1. GET → скачать JSON (~30 МБ)
  2. Task.detached (background) → парсинг:
     ├── app-имена, zap-пути, bundle ID из каждого cask
     └── Сохранить в [String: [String]] словари
  3. ParsedCaskDB.json → Application Support
  4. CaskDatabase.shared.reload(from:) → применить без перезапуска
  5. UserDatabase.migrateToCaskDB() → удалить из UserDB записи,
     которые теперь покрывает Cask DB (миграция User → ✅ Verified)
  6. Сохранить ETag + дату в UserDefaults
```

**UI кнопки в Настройках:**

| Состояние | Вид |
|---|---|
| `.idle` | «Check Update Cask DB» (серый) + дата последней проверки |
| `.checking` | ProgressView + «Checking...» |
| `.upToDate` | «Database is up to date.» |
| `.updateAvailable` | «Download and Install Cask DB» (зелёный) |
| `.downloading` | ProgressView + «Downloading...» |
| `.parsing` | ProgressView + «Installing...» |
| `.success` | «Successfully updated!» (3 сек → возврат в idle) |
| `.error(msg)` | Текст ошибки красным |

**Настройка частоты уведомлений** (`GeneralSettings.CaskUpdateFrequency`):
- 1 раз в неделю / 1 раз в 2 недели / 1 раз в месяц / Отключить

**Файлы изменены:**

| Файл | Изменение |
|---|---|
| `CaskDatabaseUpdater.swift` | **[НОВЫЙ]** — полная логика проверки, скачивания, парсинга, миграции |
| `CaskDatabase.swift` | `enum` → `final class`, singleton `shared`, `reload(from:)`, загрузка `ParsedCaskDB.json` |
| `UserDatabase.swift` | Добавлен `migrateToCaskDB(caskZapPaths:caskBundleIDPaths:)` |
| `AppInfoFetcher.swift` | → `CaskDatabase.shared.getZapPaths()` / `getBundleIDPaths()` |
| `AppPathFinder.swift` | → `CaskDatabase.shared.getZapPaths()` |
| `GeneralSettings.swift` | `CaskUpdateFrequency` enum + `@Published caskUpdateFrequency` |
| `GeneralSettingsView.swift` | Раздел «Cask Database Update»: кнопка + частота + статус + ScrollView |

---

### ver.1.2.0 — Расширения Menu Bar, Модуль Обслуживания и Индикатор Здоровья

Масштабное обновление, внедряющее новые функциональные блоки (Фазы 2, 3 и 4) и закрывающее накопленный технический долг.

#### 1. Устранение технического долга
- **Удален устаревший Helper:** Мы полностью удалили директорию `byMakerCleanerHelper/`.
- **Отслеживание Smart Scan:** Обновлен файл `CleanerView.swift`, так что теперь после каждой успешной очистки ее время сохраняется в `UserDefaults`. Эта информация используется новым сервисом проверки «здоровья» Mac.
- **Потокобезопасность Swift 6:** Внедрены исправления параллелизма, включая использование `async`/`await` внутри `Task` для `requestAuthorization` в `CaskDatabaseUpdater` и `HealthService` (исключение сбоев `_dispatch_assert_queue_fail`). Добавлен протокол `Sendable`.

#### 2. Расширения для Menu Bar (Фаза 2)
- **Мониторинг Bluetooth:** Внедрен новый сервис `BluetoothService`, использующий нативный фреймворк `IOBluetooth`. Он безопасно сканирует сопряженные устройства без зависаний интерфейса.
- **Интерактивные скриншоты:** Добавлен `ScreenshotService`, который запускает встроенную утилиту macOS для скриншотов (`screencapture -i -c`) и сразу сохраняет результат в буфер обмена (безопасно для OCLP, так как не использует Metal-оверлеи ScreenCaptureKit).
- **Интеграция UI:** Обновлен вид окна в строке меню (`MenuBarPopoverView`). Новая секция Bluetooth наглядно показывает устройства и их статус подключения (● или ○), а отдельная кнопка запускает создание скриншота.

#### 3. Модуль обслуживания (Maintenance, Фаза 3)
- **Движок MaintenanceEngine:** Создан сервис для выполнения задач с правами суперпользователя с использованием `NSAppleScript`.
  - **Очистка RAM:** Выполняет консольную команду `purge`.
  - **Сброс DNS:** Выполняет команду `dscacheutil -flushcache; killall -HUP mDNSResponder`.
- **GPU-Safe интерфейс:** Так как некоторые SwiftUI-элементы (например, `Button` или `ProgressView`) вызывают сбои на старых видеокартах Kepler (OCLP), мы аккуратно создали `MaintenanceView`, используя исключительно `Text().onTapGesture`. Кнопки плавно превращаются в индикаторы загрузки `[████░░░░]`. Функция Time Machine thinning была признана излишней и не реализована по запросу.

#### 4. Индикатор здоровья системы (Health, Фаза 4)
- **Расчет индекса здоровья:** Разработан `HealthScoreCalculator` для оценки состояния системы (до 100%). Он учитывает свободное место на диске (<20% или <10%) и количество дней с последней очистки Smart Scan (>7 или >14 дней).
- **Система уведомлений:** Создан `HealthService`, который анализирует индекс в фоновом режиме. Если индекс падает ниже согласованного порога в **<40%**, сервис автоматически отправит уведомление macOS (не чаще раза в день).
- **Интерфейс Health Gauge:** Интегрирован новый компонент `HealthGaugeView`, который отображает полосу загрузки в ретро-ASCII стиле. Добавлен как в главное окно (`ContentView`), так и в верхнюю часть всплывающего окна Menu Bar.

---

### ver.1.3.0 — Полный редизайн интерфейса (Ретро-Футуристичный Терминал)

Масштабное визуальное и структурное обновление приложения для создания уникальной эстетики ASCII-терминала:

#### 1. Новая дизайн-система (`Theme.swift` & `TerminalComponents.swift`)
- **Цвета**: Глубокий черный фон (`#000000`), яркий оранжевый акцент (`#FF8C00`), красный для деструктивных действий (`#FF3333`) и зеленый для успеха (`#00FF66`), а также желтый для предупреждений.
- **Компоненты (GPU-safe)**: Полностью переписаны все UI-элементы для совместимости со старыми GPU (Kepler / OCLP). Никаких `Button`, `Toggle`, `Picker` или `ProgressView`. Все интерактивные элементы построены на `Text()` с модификатором `.onTapGesture()`. Созданы `TerminalCard`, `TerminalButton`, `TerminalToggle`, `TerminalProgress`, и `TerminalBarChart`.
- **Типографика**: Глобальное использование моноширинного шрифта.

#### 2. Структурные изменения
- **Навигация**: `TabView` заменен на кастомную боковую панель (Sidebar) в `ContentView.swift`. Это придает приложению вид классического консольного приложения.
- **Окно приложения**: Применена настройка `.windowStyle(.hiddenTitleBar)`, которая скрывает стандартную серую полосу заголовка macOS, а кнопки управления окном органично интегрированы в интерфейс.

#### 3. Обновленные экраны
- **`CleanerView`**: Заменены стандартные индикаторы загрузки на ASCII-стиль (`[ CHECKING... ]`).
- **`MaintenanceView`**: Полностью переведен на карточную систему команд терминала.
- **`LoginItemsView` & `OrphanFinderView`**: Отключен системный фон списков (`.scrollContentBackground(.hidden)`). Системные переключатели заменены на кастомный текстовый переключатель `[X] / [ ]`.
- **`MenuBarPopoverView`**: Переписан в стиле терминала. Полосы прогресса заменены на текстовые гистограммы (`TerminalBarChart`).
- **`GeneralSettingsView`**: Удалены системные Picker-ы в пользу кастомных текстовых переключателей для интервалов.

---

## 3. Архитектура App Uninstaller v3.1 (текущая)

> Двухуровневая + пользовательская система: **Cask DB (мгновенно) + UserDB (мгновенно) + Эвристика (по запросу)**.

### Ключ поиска в Cask DB

- **Стандартный формат:** `appName.lowercased()` (пробелы сохранены)
- `"Google Chrome"` → ключ `"google chrome"` → найдено ✅
- `"Visual Studio Code"` → ключ `"visual studio code"` → найдено ✅
- Совместимо с будущими обновлениями Homebrew — база обновляется in-app

### Файлы ядра App Uninstaller

| Файл | Роль |
|---|---|
| `AppInfoFetcher.swift` | Сбор приложений + приоритетный матчинг (UserDB → CaskName → CaskBundleID) |
| `AppPathFinder.swift` | Эвристический поиск файлов (для Unknown) |
| `CaskDatabase.swift` | Singleton-класс с 5406 приложениями (встроенный + динамический) |
| `CaskDatabaseUpdater.swift` | Скачивание и парсинг обновлённой базы с Homebrew API |
| `UserDatabase.swift` | Пользовательская база путей (JSON, thread-safe) |
| `Conditions.swift` | `AppCondition` для игр и сложных случаев (Steam, Epic, CLIP STUDIO...) |
| `Glob.swift` | Раскрытие путей (`~`, `*`) |
| `AppState.swift` | Координация: загрузка, Deep Scan, удаление, экспорт |

---

## 4. Архитектура безопасности Orphan Finder

> Orphan Finder работает **полностью безопасно** — многоуровневая защита исключает любые системные, критически важные или активно используемые файлы.

### Область сканирования (allowedRoots)

Сканируются **только** эти директории:
- `~/Library/Caches`
- `~/Library/Logs`
- `~/Library/Saved Application State`
- `~/Library/HTTPStorages`
- `~/Library/WebKit`
- `~/Library/Application Support/CrashReporter`
- `/Library/Caches`
- `/Library/Logs`

**Не сканируются:** Preferences, Containers, Group Containers, LaunchAgents, LaunchDaemons, Application Support, Keychains, Mail, Safari, Messages, Calendars, Mobile Documents, CloudStorage.

### Алгоритм (ver.1.1.2+)

```
Pass 1 — Build Map
  ├── AppInfoFetcher.fetchInstalledApps()
  ├── Для каждого: AppPathFinder.findPaths() параллельно (TaskGroup)
  └── Set<String> occupiedPaths — карта всех занятых файлов

Pass 2 — Reverse Scan
  ├── Обойти allowedRoots (depth=1)
  ├── Для каждого кандидата: если путь в occupiedPaths → пропустить
  └── Прошёл все 6 уровней проверки → orphan
```

> PureMac первый скан использует упрощённую эвристику (~40 результатов); второй — полный AppPathFinder (~17). Наш алгоритм всегда использует полный вариант.

---

## 5. Сравнительный анализ: byMakerCleaner vs PureMac vs CleanMyMac

**Дата теста:** 2026-08-30 | **Версия при тесте:** ver.1.1.2

### Результаты Orphan Finder

| Программа | Кол-во | Тип алгоритма |
|---|---|---|
| **byMakerCleaner** | **18** | Двухпроходный, AppPathFinder + 6-уровневая политика |
| PureMac | 18 | Второй скан — полный AppPathFinder |
| CleanMyMac | N/A | Другая логика — Uninstaller Leftovers, не Orphan Finder |

### byMakerCleaner vs PureMac — в чём отличия

| Элемент | byMakerCleaner | PureMac | Вердикт |
|---|---|---|---|
| `pip` (85 MB) | ❌ исключён | ✅ показывает | 🟢 **Мы правы:** Python-пакетник может использоваться |
| `typescript` (4 KB) | ❌ исключён | ✅ показывает | 🟢 **Мы правы:** npm-инструмент |
| `Dortania` (16 KB) | ❌ исключён | ✅ показывает | 🟢 **Критично:** OCLP — трогать нельзя |
| `hidfw-crashlogs` | ❌ исключён | ❌ | 🟢 Исправлено в ver.1.1.2 |
| `Xsan` logs | ❌ исключён | ❌ | 🟢 Исправлено в ver.1.1.2 |

**Итог:** byMakerCleaner безопаснее PureMac — корректно защищает инструменты разработчика, OCLP-компоненты и системную инфраструктуру.

### CleanMyMac — принципиально другое

> CleanMyMac **Leftovers** — это раздел **Uninstaller**. Это аналог нашего **App Uninstaller**, а не Orphan Finder.

| Параметр | byMakerCleaner Orphan Finder | CleanMyMac Leftovers |
|---|---|---|
| Принцип | Reverse scan любых брошенных файлов | Поиск файлов конкретного удалённого приложения |
| Область | Caches, Logs, HTTPStorages, WebKit | Containers (UUID!), Preferences, Group Containers |
| Привязка к приложению | Нет — общий поиск | Да — знает что было удалено |
| Аналог в нашем проекте | Orphan Finder | App Uninstaller |

---

## 6. Технический долг и план разработки

### Активный технический долг

| Приоритет | Задача | Версия |
|---|---|---|
| 🟢 Низкий | Оптимизация производительности при большом числе приложений | 1.3.x |

### Закрытый технический долг

| Задача | Закрыто в | Примечание |
|---|---|---|
| ~~Удалить папку `byMakerCleanerHelper/` из репозитория~~ | ~~1.2.0~~ | ✅ Выполнено |
| ~~Сохранять `lastCleanDate` в `UserDefaults` при Clean~~ | ~~1.2.0~~ | ✅ Выполнено |
| ~~Уведомление при устаревшей Cask DB (> N дней) — триггер при старте~~ | ~~1.2.0~~ | ✅ Выполнено |
| ~~Orphan Finder: небезопасные результаты~~ | ~~1.1.2~~ | ✅ Двухпроходный алгоритм |
| ~~SWIFT_VERSION: 5.0 → 6.0~~ | ~~1.1.2~~ | ✅ Исправлены Swift 6 warnings |
| ~~Мёртвая URL-scheme bymakercleaner://~~ | ~~1.1.2~~ | ✅ Удалена из project.yml |
| ~~App Uninstaller: только .app-размер~~ | ~~1.1.4~~ | ✅ Двухфазный расчёт через AppPathFinder |
| ~~Developer.app захватывал /Library/Developer~~ | ~~1.1.5~~ | ✅ skipPaths + AppCondition |
| ~~CLIP STUDIO захватывал CLIP STUDIO PAINT~~ | ~~1.1.5~~ | ✅ взаимные excludeTerms |
| ~~CaskDatabase: enum (не обновляемый)~~ | ~~1.1.9+~~ | ✅ singleton class + In-App Update |
| ~~Swift 6 Concurrency (Sendable, MainActor)~~ | ~~1.2.0~~ | ✅ Замена closures на `async/await` Tasks |

### Правила разработки (принято как стандарт)

- **Версионирование:** `CFBundleShortVersionString` в `project.yml` = версия коммита
- **GPU-safe:** только `Text(...).onTapGesture {}` — никаких `Button`, `Toggle`, `ProgressView`
- **Swift 6:** никаких warnings о concurrency, всегда `let finalX` перед передачей в `@MainActor`
- **MIT-код PureMac:** копировать напрямую с сохранением copyright-хедеров
- **Мёртвый код:** удалять немедленно, не откладывать
- **Безопасность превыше всего:** любое сомнительное удаление → исключить

### Roadmap

| Версия | Что | Категория |
|---|---|---|
| **1.3.x+** | libimobiledevice (iOS-устройства), WidgetKit, Privacy-аудит (TCC.db), SMC температура | Бэклог |

---

## 7. Ключевые технические решения и пояснения

### LSUIElement = false (текущее)

`LSUIElement` управляет видимостью иконки в Dock:
- `false` (текущий): иконка в Dock + полноценное главное окно — **оставляем**
- `true`: только menu-bar агент (без Dock-иконки) — не подходит для нашего случая

### OCLP / Kepler GPU — ограничения

Все компоненты UI **обязаны** использовать `Text(...).onTapGesture {}`:
- `Button` — вызывает Metal рендеринг → краш на Kepler GPU
- `ProgressView` — аналогично → заменён на текстовый `[████░░░░]`
- SwiftUI-анимации — Metal compute shader crash → убраны все `withAnimation`

Системные файлы OCLP (`Dortania`, `OpenCore`) внесены в `safeNameBlocklist` — **никогда не предлагаются к удалению**.

### PureMac как донор (MIT лицензия)

Условие использования: сохранить copyright-комментарий в файлах.

| Файл | Источник |
|---|---|
| `AppPathFinder.swift` | PureMac (с модификациями) |
| `Conditions.swift` | PureMac (значительно расширен) |
| `AppInfoFetcher.swift` | PureMac (с модификациями) |
| `Locations.swift` | PureMac |
| `OrphanSafetyPolicy.swift` | PureMac (полностью переписан) |
| `OrphanFinderEngine.swift` | Написан нами (двухпроходный алгоритм) |
| Вся UI-логика | Написана нами |
| MenuBar, Login Items | Написаны нами |

### Homebrew Cask — вклад сообщества

Пользователи могут делиться своими путями с командой Homebrew:
1. Settings → Contribute to Community → Export Database
2. Файл сохраняется в `~/Downloads/byMakerCleaner_UserDB_YYYY-MM-DD.json`
3. Открыть https://github.com/Homebrew/homebrew-cask/issues
4. Создать issue/PR с прикреплённым JSON

### ScreenCaptureKit — риск для OCLP

Перед реализацией скриншот-тула: проверить, использует ли `ScreenCaptureKit` Metal/CoreImage overlays. Если да → `CGWindowListCreateImage` как безопасная альтернатива. Entitlement `com.apple.security.screen-recording` добавить только тогда.

---

## 8. Структура проекта (ключевые файлы)

```
byMakerCleaner/
├── Logic/
│   ├── Scanning/
│   │   ├── AppInfoFetcher.swift         — сбор приложений + матчинг
│   │   ├── AppPathFinder.swift          — эвристический поиск файлов
│   │   ├── CaskDatabase.swift           — 5406 приложений (singleton)
│   │   ├── CaskDatabaseUpdater.swift    — In-App обновление из Homebrew
│   │   ├── UserDatabase.swift           — пользовательские пути (JSON)
│   │   ├── Conditions.swift             — AppCondition для сложных случаев
│   │   ├── OrphanFinderEngine.swift     — двухпроходный Orphan Finder
│   │   ├── LoginItemsManager.swift      — SMAppService + LaunchAgents/Daemons
│   │   ├── MaintenanceEngine.swift      — AppleScript purge & dns
│   │   └── Glob.swift                  — раскрытие путей (~, *)
│   └── Utilities/
│       ├── GeneralSettings.swift        — настройки (метрики, Cask update freq)
│       ├── OrphanSafetyPolicy.swift     — 6 уровней защиты
│       ├── FileSize.swift               — вычисление размеров
│       ├── SystemMetricsService.swift   — CPU/RAM/Disk/Network
│       ├── BluetoothService.swift       — IOBluetooth мониторинг
│       ├── ScreenshotService.swift      — screencapture -i -c
│       ├── HealthScoreCalculator.swift  — расчет индекса здоровья
│       └── HealthService.swift          — фоновый сервис уведомлений
├── ViewModels/
│   ├── AppState.swift                   — главный координатор
│   └── OrphanFinderViewModel.swift
├── Views/
│   ├── AppListView.swift                — App Uninstaller UI
│   ├── OrphanFinderView.swift
│   ├── LoginItemsView.swift
│   ├── GeneralSettingsView.swift        — настройки (интервал, Cask, Contribute)
│   ├── MenuBarPopoverView.swift         — UI с Health и Bluetooth
│   ├── MaintenanceView.swift            — GPU-safe меню обслуживания
│   └── HealthGaugeView.swift            — ретро-индикатор здоровья
├── UI/
│   ├── Theme.swift                      — глобальные токены стилей терминала
│   └── TerminalComponents.swift         — GPU-safe кастомные компоненты
├── Vendor/                              — PureMac (MIT, без изменений)
├── byMakerCleanerApp.swift              — EntryPoint + MenuBarExtra
└── project.yml                          — xcodegen конфигурация

tools/
├── generate_app_conditions.py           — генератор AppCondition
├── cask_paths.json                      — исходные данные условий
└── generated_conditions.swift          — результат генерации

md/
├── prompts and scripts/
│   └── generate_cask_db.py             — генератор CaskDatabase.swift
│   └── generate_log.py                 — генератор лога диалога
├── Analysis Report.md                  — этот файл
└── GitHub_Workflow.md                  — правила Git-workflow
```
