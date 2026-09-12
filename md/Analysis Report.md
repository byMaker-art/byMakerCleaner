# Аналитический отчёт: byMakerCleaner
**Дата:** 2026-09-12 | **Текущая версия:** `ver.1.0.0 (786b2e9)`

---

## 1. Статус реализации по ТЗ

> Сводная таблица: что реализовано, что в планах, что отложено.

| Модуль / Фича | Статус | Версия | Примечание |
|---|---|---|---|
| Архитектура (xcodegen + PureMac в Vendor) | ✅ Готово | 1.0.1 | MIT-лицензированный донор |
| App Uninstaller (10-уровневый matching) | ✅ Готово | 1.0.1–1.0.9 | |
| AppListView / AppDetailView (GPU-safe) | ✅ Готово | 1.0.2–1.0.4 | Только `Text`, никаких `Button` |
| Иконка и бренд byMakerCleaner | ✅ Готово | 1.0.1 | |
| System Cleaner / Smart Scan (10 категорий) | ✅ Готово | 1.0.11 | |
| Trash Bins (все тома, minimumSize:0) | ✅ Готово | 1.0.12–1.0.14 | |
| Исключения OCLP (displaypolicy, install.log) | ✅ Готово | 1.0.15 | |
| MenuBar (CPU/RAM/Disk/Network) | ✅ Готово | 1.0.16–1.0.18 | |
| Login Items Manager | ✅ Готово | 1.0.20–1.0.30 | SMAppService + LaunchAgents/Daemons |
| Show in Finder (Login Items) | ✅ Готово | 1.0.30 | |
| Объединение Helper + Main App | ✅ Готово | 1.1.0–1.1.1 | |
| Настраиваемый интервал опроса (1–60 сек) | ✅ Готово | 1.1.0 | |
| Сортировки (Orphan, App List, Login Items) | ✅ Готово | 1.1.1 | |
| Кнопка Settings в MenuBar (SettingsLink) | ✅ Готово | 1.1.1 | |
| **Orphan Finder v2** (двухпроходный алгоритм) | ✅ Готово | **1.1.2** | AppPathFinder-based, аналог «второго скана» PureMac |
| **OrphanSafetyPolicy v2** (6 уровней + 50+ имён) | ✅ Готово | **1.1.3** | OCLP, Xsan, hidfw, SIP, kext, symlink guard |
| **App Uninstaller v2** (реальный суммарный размер) | ✅ Готово | **1.1.4** | Фоновый AppPathFinder пересчёт + Steam/Spotify/Epic |
| **App Uninstaller: безопасность** (изоляция файлов) | ✅ Готово | **1.1.5** | Developer.app (−30GB), Antigravity/IDE, CLIP STUDIO, OCLP |
| **Cask Database v2** (точные пути для 5406 приложений) | ✅ Готово | **1.1.6** | Стандартный ключ `lowercased()` (пробелы сохранены) + исправлен баг `normalize_key` |
| **App Uninstaller v3** (двухуровневая архитектура) | ✅ Готово | **1.1.7** | Verified (Cask) → мгновенно; Unknown → чекбоксы + `Deep Scan` по запросу |
| **App Uninstaller v3.1** (User Custom DB + Bundle ID) | ✅ Готово | **1.1.8** | Сохранение своих приложений в `UserDatabase.json`, `bundleIDPaths` для App Store и расхождений имён |
| **Contribute to Community** (экспорт User DB) | ✅ Готово | **1.1.9** | Экспорт `UserDatabase` в папку Downloads с датой, инструкция по отправке в Homebrew Cask, ссылка на GitHub Issues |
| **Cask DB In-App Update** (динамическое обновление) | ✅ Готово | **1.1.9** | Скачивание JSON с Homebrew API (~30МБ), парсинг на Swift, миграция User→Cask, настройка частоты уведомлений |
| Bluetooth-виджет (`IOBluetooth`) | ⏳ Запланировано | 1.2.x | |
| Скриншот-тул (`ScreenCaptureKit`) | ⏳ Запланировано | 1.1.4 | Нужна OCLP-совместимость проверка |
| Дата последней очистки (`UserDefaults`) | ⏳ Запланировано | 1.1.x | Ключ `lastCleanDate` в `CleanerView` |
| Удалить папку `byMakerCleanerHelper/` | ⏳ Запланировано | 1.1.x | Мёртвые файлы после объединения таргетов |
| Кнопка Free Up RAM в MenuBar | ⏳ Запланировано | 1.2.x | Вместе с Maintenance |
| Maintenance (RAM, DNS, Time Machine) | ⏳ Запланировано | 1.2.x | `purge`, `dscacheutil`, `tmutil` |
| Health Indicator (гейдж + уведомления) | ⏳ Запланировано | 1.3.x | `UNUserNotificationCenter` + `HealthScoreCalculator` |
| Entitlement `screen-recording` | ⏳ Запланировано | 1.1.4 | Только при разработке скриншот-тула |

---

## 2. Архитектура App Uninstaller v3 (ver.1.1.7)

> Двухуровневая система: **Cask DB (мгновенно) + Эвристика (по запросу)**.

### Уровни работы

| Уровень | Триггер | Скорость | Точность |
|---|---|---|---|
| **Verified (Cask DB)** | Автоматически при загрузке | ⚡ Мгновенно (только `stat()` на известных путях) | 100% (данные из Homebrew) |
| **Unknown (Эвристика)** | Только по явному выбору пользователя | 🔍 Медленно (полный обход диска) | ~85% |

### Алгоритм загрузки (v3.1)

```
loadInstalledApps():
  1. AppInfoFetcher.fetchInstalledApps()
     ├── Найдено в UserDatabase? → 👤 User Verified (мгновенно, твои пути)
     ├── Найдено в CaskDatabase (Name)? → ✅ Verified (мгновенно, Cask пути)
     ├── Найдено в CaskDatabase (BundleID)? → ✅ Verified (мгновенно, Cask пути)
     └── Иначе → ⚠️ Unknown (app-only size)
  2. Для известных приложений: Glob.expand(dbPaths) → size ← fast stat()

UI:
  Секция "👤 User Verified": tap → мгновенный список (сохранённый тобой)
  Секция "✅ Verified Apps": tap → мгновенный список (Cask DB)
  Секция "⚠️ Unknown Apps": ☐ чекбокс + кнопка "Deep Scan (N)"
    └── Deep Scan → AppPathFinder.findPaths()
    └── После Deep Scan → 💾 "Add to My Database" (сохраняет в UserDB)

Обновление базы (In-App):
  1. Кнопка в настройках скачивает JSON (~30МБ) напрямую из Homebrew API.
  2. `CaskDatabaseUpdater` парсит его за 1-2 секунды, обновляет `CaskDatabase`.
  3. Программы из `UserDatabase`, которые теперь есть в официальном `Cask DB`, автоматически мигрируют в секцию ✅ Verified.
```

### Ключ поиска в Cask DB

- **Стандартный формат:** `appName.lowercased()` (пробелы сохранены)
- `"Google Chrome"` → ключ `"google chrome"` → найдено ✅
- `"Visual Studio Code"` → ключ `"visual studio code"` → найдено ✅
- Совместимо с будущими обновлениями базы Homebrew

### Файлы изменены

| Файл | Изменение |
|---|---|
| `AppInfoFetcher.swift` | `InstalledApp` получил `isKnownApp`, `caskPaths`, `selectedForHeuristic` |
| `AppInfoFetcher.swift` | `loadAppInfo()` проверяет `CaskDatabase` при создании каждого `InstalledApp` |
| `AppState.swift` | Step 2 ограничен только Cask-apps (Glob expand); новые методы `toggleHeuristicSelection()`, `scanSelectedWithHeuristic()`, `selectApp()` умеет работать с обоими типами |
| `AppListView.swift` | Два раздела: Verified + Unknown с чекбоксами и кнопкой Deep Scan |
| `generate_cask_db.py` | `normalize_key()` = стандартный `lowercased()` без убирания пробелов |
| `CaskDatabase.swift` | Перегенерирован: **5406 приложений**, стандартные ключи |

### Обновление Cask DB (In-App, v3.2)

```
CaskDatabaseUpdater.checkUpdate():
  1. HEAD-запрос к formulae.brew.sh/api/cask.json
  2. Сравнение ETag с сохранённым в UserDefaults
  3a. ETag совпадает → state = .upToDate
  3b. ETag новый    → state = .updateAvailable

CaskDatabaseUpdater.downloadAndInstall(etag:):
  1. GET запрос → скачивает JSON (~30 МБ)
  2. Task.detached (background) → парсинг:
     ├── Для каждого Cask: извлечь app-имена, zap-пути, bundle ID
     └── Сохранить в [String: [String]] словари
  3. Результат → ParsedCaskDB.json (Application Support)
  4. CaskDatabase.shared.reload(from:) → применяет без перезапуска
  5. UserDatabase.migrateToCaskDB() → удаляет записи из UserDB,
     которые теперь есть в официальной Cask DB
  6. ETag и дата сохраняются в UserDefaults

UI состояния кнопки в Настройках:
  .idle        → "Check Update Cask DB" (серый)
  .checking    → ProgressView + "Checking..."
  .upToDate    → "Database is up to date."
  .updateAvailable → "Download and Install Cask DB" (зелёный)
  .downloading → ProgressView + "Downloading..."
  .parsing     → ProgressView + "Installing..."
  .success     → "Successfully updated!"
  .error(msg)  → текст ошибки красным
```

### Файлы изменены (v3.2)

| Файл | Изменение |
|---|---|
| `CaskDatabaseUpdater.swift` | **[НОВЫЙ]** — полная логика проверки, скачивания, парсинга, миграции |
| `CaskDatabase.swift` | Превращён из `enum` в `final class CaskDatabase: @unchecked Sendable`, singleton `shared`, загружает `ParsedCaskDB.json` при старте; хардкод стал `defaultZapPaths`/`defaultBundleIDPaths` |
| `UserDatabase.swift` | Добавлен `migrateToCaskDB(caskZapPaths:caskBundleIDPaths:)` — удаляет записи, найденные в новой Cask DB |
| `AppInfoFetcher.swift` | Обновлён на `CaskDatabase.shared.getZapPaths()` / `getBundleIDPaths()` |
| `AppPathFinder.swift` | Обновлён на `CaskDatabase.shared.getZapPaths()` |
| `GeneralSettings.swift` | Добавлен `CaskUpdateFrequency` (weekly/biweekly/monthly/disabled), `@Published caskUpdateFrequency` |
| `GeneralSettingsView.swift` | Добавлен раздел "Cask Database Update": кнопка + частота + статус |

---

## 3. Архитектура безопасности Orphan Finder

> Orphan Finder работает **полностью безопасно** — многоуровневая защита исключает любые системные, критически важные или активно используемые файлы.

### Алгоритм (ver.1.1.2)

```
Pass 1 — Build Map
  ├── Получить список всех установленных приложений (AppInfoFetcher)
  ├── Для каждого запустить AppPathFinder.findPaths() через TaskGroup (параллельно)
  └── Получить Set<String> occupiedPaths — «карта занятых файлов»

Pass 2 — Reverse Scan
  ├── Обойти allowedRoots (depth=1)
  ├── Для каждого кандидата: если путь в occupiedPaths → пропустить
  └── Прошёл все проверки (6 уровней) → orphan
```

> Это воспроизводит точное поведение «второго скана» PureMac с первой попытки. В PureMac первый скан использует упрощённую эвристику (~40 результатов); второй — полный AppPathFinder (~17). Наш алгоритм всегда использует полный вариант.

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

### 6 уровней защиты (OrphanSafetyPolicy)

| Уровень | Что проверяется | Примеры |
|---|---|---|
| **L1** | highRiskHomeDotPaths | `.ssh`, `.aws`, `.kube`, `.gnupg`, `.cargo`, `.pip`, `.zshrc` |
| **L2** | allowedRoots — строгое соответствие | Только 8 разрешённых директорий |
| **L3** | blockedFragments — абсолютный блок-лист | Preferences, Containers, Security, Extensions, Kernel |
| **L4** | com.apple.* prefix | Все Apple-файлы по имени |
| **L5** | safeNameBlocklist (50+ имён) | Xsan, hidfw, Dortania/OCLP, OpenCore, SIP, kext, Time Machine, APFS, recovery, installer, crypto |
| **L6** | Symlink guard | Симлинки никогда не обрабатываются |

### Категории имён в blocklist (L5)

| Категория | Примеры |
|---|---|
| 🔴 OCLP / OpenCore | `dortania`, `opencore`, `oclp`, `ocvalidate` |
| 🔴 Apple ФС и сеть | `xsan`, `xsand`, `afp`, `smb` |
| 🔴 Firewall | `hidfw`, `hidfw-crashlogs`, `alf`, `socketfilterfw` |
| 🔴 SIP / целостность | `amfid`, `csr`, `sip`, `syspolicyd`, `xprotect` |
| 🔴 Kext / драйверы | `kextd`, `kexts`, `kextcache`, `sysextd` |
| 🔴 Time Machine / APFS | `timemachine`, `backupd`, `apfs`, `diskarbitrationd` |
| 🔴 Boot / Recovery | `recovery`, `bootp`, `bless`, `efi`, `nvram` |
| 🟡 Installer / pkgs | `pkgutil`, `receipts`, `bom`, `installd` |
| 🟡 Power mgmt | `powerlog`, `powerdatad`, `batteryd` |
| 🟡 Diagnostics | `sysdiagnose`, `spindump`, `diagnosticd` |
| 🟢 Developer tools | `pip`, `typescript`, `lldb`, `dtrace`, `xcrun` |

---

## 3. Сравнительный анализ: byMakerCleaner vs PureMac vs CleanMyMac

**Дата теста:** 2026-08-30 | **Версия при тесте:** ver.1.1.2

### Результаты сканирования

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
| `hidfw-crashlogs` | ~~показывал~~ → теперь ❌ | ❌ | 🟢 Исправлено в ver.1.1.2 |
| `Xsan` logs | ~~показывал~~ → теперь ❌ | ❌ | 🟢 Исправлено в ver.1.1.2 |

**Итог:** byMakerCleaner безопаснее PureMac — корректно защищает инструменты разработчика, OCLP-компоненты и системную инфраструктуру.

### CleanMyMac — принципиально другое

> CleanMyMac **Leftovers** — это раздел **Uninstaller**. Это не аналог нашего Orphan Finder — это аналог нашего **App Uninstaller** при удалении конкретного приложения.

| Параметр | byMakerCleaner Orphan Finder | CleanMyMac Leftovers |
|---|---|---|
| Принцип | Reverse scan любых брошенных файлов | Поиск файлов конкретного удалённого приложения |
| Область | Caches, Logs, HTTPStorages, WebKit | Containers (UUID!), Preferences, Group Containers |
| Привязка к приложению | Нет — общий поиск | Да — знает что было удалено |
| Аналог в нашем проекте | Orphan Finder | App Uninstaller |

### Итоговый рейтинг

```
Безопасность: byMakerCleaner ≥ PureMac > CleanMyMac Leftovers
Полнота:      CleanMyMac Leftovers > PureMac ≈ byMakerCleaner
```

---

## 4. Технический долг и план разработки

### Активный (текущий) технический долг

| Приоритет | Задача | Версия |
|---|---|---|
| 🟡 Средний | Сохранять `lastCleanDate` в `UserDefaults` при Clean | 1.1.x |
| 🟡 Средний | Удалить папку `byMakerCleanerHelper/` из репозитория | 1.1.x |
| 🟡 Средний | Уведомление при устаревшей Cask DB (> N дней) — триггер при старте приложения | 1.2.x |

> **Проблема 1: byMakerCleanerHelper/** — папка осталась в репозитории после объединения таргетов (ver.1.1.0). Содержит `@main` — потенциальный конфликт. В `project.yml` не включена, но создаёт путаницу.

> **Проблема 2: lastCleanDate** — дата последней очистки не сохраняется. Нужна для Health Score (ТЗ п. 3.6). Ключ `lastCleanDate` в `UserDefaults`, запись в `CleanerView` при нажатии Clean.

### Закрытый технический долг

| Задача | Закрыто в | Примечание |
|---|---|---|
| ~~Orphan Finder: небезопасные результаты~~ | ~~1.1.2~~ | ✅ Двухпроходный алгоритм |
| ~~SWIFT_VERSION: 5.0 → 6.0~~ | ~~1.1.2~~ | ✅ Исправлены Swift 6 warnings |
| ~~Мёртвая URL-scheme bymakercleaner://~~ | ~~1.1.2~~ | ✅ Удалена из project.yml |
| ~~Версия в project.yml не совпадала~~ | ~~1.1.2~~ | ✅ Правило: версия = версия коммита |

### Правила разработки (принято как стандарт)

- **Версионирование:** `CFBundleShortVersionString` и `MARKETING_VERSION` в `project.yml` = версия коммита
- **GPU-safe:** только `Text(...).onTapGesture {}` — никаких `Button`, `Toggle`, `ProgressView`
- **Swift 6:** никаких warnings о concurrency, всегда `let finalX` перед передачей в `@MainActor`
- **MIT-код PureMac:** копировать напрямую с сохранением copyright-хедеров
- **Мёртвый код:** удалять немедленно, не откладывать

### Roadmap

| Версия | Что | Категория |
|---|---|---|
| **1.2.0** | Bluetooth (`IOBluetooth.pairedDevices()`) | Фаза 2 |
| **1.2.1** | Скриншот-тул (OCLP-check → `ScreenCaptureKit` или `CGWindowListCreateImage`) | Фаза 2 |
| **1.3.0** | Maintenance вкладка + Free Up RAM в MenuBar | Фаза 3 |
| **1.3.1** | Flush DNS + Time Machine Snapshot Thinning | Фаза 3 |
| **1.4.0** | `HealthScoreCalculator` + `UNUserNotificationCenter` | Фаза 4 |
| **1.4.1** | Health гейдж UI (GPU-safe: `[██████░░░░] 72%`) | Фаза 4 |
| **2.x+** | libimobiledevice, WidgetKit, Privacy-аудит (TCC.db), SMC температура | Бэклог |

---

## 5. Ключевые технические решения и пояснения

### LSUIElement = false (текущее)

`LSUIElement` управляет видимостью иконки в Dock:
- `false` (текущий): иконка в Dock + полноценное главное окно — **оставляем**
- `true`: только menu-bar агент (без Dock-иконки) — не подходит для нашего случая

### OCLP / Kepler GPU — ограничения

Все компоненты UI **обязаны** использовать `Text(...).onTapGesture {}`:
- `Button` — вызывает Metal рендеринг → краш на Kepler GPU
- `ProgressView` — аналогично → заменён на текстовый `[████░░░░]`

Системные файлы OCLP (`Dortania`, `OpenCore`) внесены в `safeNameBlocklist` — **никогда не предлагаются к удалению**.

### PureMac как донор (MIT лицензия)

Условие использования: сохранить copyright-комментарий в файлах, взятых из PureMac.
Что взято напрямую: `AppPathFinder.swift`, `Conditions.swift`, `AppInfoFetcher.swift`, `Locations.swift`, `OrphanSafetyPolicy.swift`.
Что написано своего: вся UI-логика, MenuBar, Login Items, `OrphanFinderEngine.swift` (новый двухпроходный движок).

### ScreenCaptureKit — риск для OCLP

Перед реализацией скриншот-тула (ver.1.1.4): проверить, использует ли `ScreenCaptureKit` Metal/CoreImage overlays. Если да → `CGWindowListCreateImage` как безопасная альтернатива. Entitlement `com.apple.security.screen-recording` добавить только тогда.

---

## 6. История итераций (changelog)

| Версия | Ключевые изменения |
|---|---|
| 1.0.1 | Архитектура, PureMac в Vendor, App Uninstaller base |
| 1.0.2–1.0.4 | AppListView / AppDetailView, GPU-safe UI |
| 1.0.11 | System Cleaner, Smart Scan (10 категорий) |
| 1.0.12–1.0.15 | Trash Bins fix, OCLP exclusions |
| 1.0.16–1.0.18 | MenuBar Helper (CPU/RAM/Disk/Network) |
| 1.0.20–1.0.30 | Login Items Manager + Show in Finder |
| 1.1.0–1.1.1 | Объединение таргетов, настраиваемый интервал, сортировки, SettingsLink |
| **1.1.2** | **Orphan Finder v2** (двухпроходный AppPathFinder), **OrphanSafetyPolicy** (6 уровней, 50+ имён), SWIFT_VERSION 6.0, удалена URL-scheme, Swift 6 warnings fixed |
| **1.1.6** | **Cask Database v2** (5406 приложений), исправлен `normalize_key`, стандартные ключи с пробелами |
| **1.1.7** | **App Uninstaller v3** — двухуровневая архитектура: Verified (мгновенно) + Unknown (Deep Scan по запросу) |
| **1.1.8** | **User Custom DB** (`UserDatabase.json`), Bundle ID matching, `UserDatabase.shared` thread-safe (`NSLock`) |
| **1.1.9** | **Contribute to Community** (экспорт в Downloads с датой), **Cask DB In-App Update** (`CaskDatabaseUpdater`), `CaskDatabase` → singleton class, миграция User→Cask после обновления, настройка частоты проверок |
