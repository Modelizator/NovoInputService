# NovoInputService

Клиентский модуль для унифицированной обработки ввода в Roblox.

Поддерживает клавиатуру, мышь, геймпад и тач-устройства (включая кастомные мобильные кнопки). Реализует одиночные действия, комбо-последовательности, tap/hold/charge, drag, аналоговый ввод и отслеживание движения мыши.

## Содержание

- [Требования](#требования)
- [Установка](#установка)
- [Атрибуты скрипта](#атрибуты-скрипта)
- [Поля модуля](#поля-модуля)
- [API](#api)
  - [SetReading](#setreading)
  - [SetReadTab](#setreadtab)
  - [RegisterCombo](#registercombo)
  - [BindAction](#bindaction)
  - [UnbindAction](#unbindaction)
- [Конфигурация действия](#конфигурация-действия)
  - [Колбэки](#колбэки)
  - [MobileUI](#mobileui)
- [Жизненный цикл нажатия](#жизненный-цикл-нажатия)
- [Комбо](#комбо)
- [Порядок проверок и фильтрация](#порядок-проверок-и-фильтрация)
- [Внутренние объекты](#внутренние-объекты)
- [Известные особенности](#известные-особенности)
- [Пример использования](#пример-использования)

---

## Требования

- Roblox Studio
- Модуль должен требовать только на клиенте (`LocalScript` / `ModuleScript`, запускаемый с клиента)
- `UserInputService`, `ContextActionService`, `Players` доступны из стандартного `game:GetService`

## Установка

1. Помести `NovoInputService.luau` (или `ModuleScript`) в `ReplicatedStorage` / `StarterPlayerScripts` / любую клиентскую папку.
2. Подключи модуль:

```lua
local NovoInputService = require(path.to.NovoInputService)# NovoInputService
