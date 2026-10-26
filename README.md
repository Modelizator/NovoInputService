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
local NovoInputService = require(path.to.NovoInputService)
```

3. (Опционально) настрой атрибуты скрипта, см. [Атрибуты скрипта](#атрибуты-скрипта).
4. Зарегистрируй действия через [`BindAction`](#bindaction) и комбо через [`RegisterCombo`](#registercombo).

---

## Атрибуты скрипта

Задаются в `Properties` скрипта. Читаются один раз при инициализации модуля.

| Атрибут | Тип | По умолчанию | Описание |
|---|---|---|---|
| `Debugging` | `boolean` | `false` | Включает отладочный вывод. При `false` модуль не пишет ничего. |
| `Input_Delay` | `number` | `0` | Минимальный интервал (сек) между регистрациями ввода одного действия. Защита от дребезга. Невалидное значение (`< 0` или не число) заменяется на `0` с предупреждением. |

> `Input_Delay` кэшируется в `NovoInputService.InputDelay` при загрузке. Изменение атрибута после инициализации не подхватится автоматически.

---

## Поля модуля

| Поле | Тип | Описание |
|---|---|---|
| `NovoInputService.Reading` | `boolean` | Глобальный флаг чтения ввода. При `false` модуль игнорирует все действия. |
| `NovoInputService.ReadTab` | `table<string, boolean>` | Пер-действие флаг. `ReadTab[actionName] == false` значит, что конкретное действие игнорируется. Отсутствие ключа трактуется как "разрешено". |
| `NovoInputService.InputDelay` | `number` | Кэш атрибута `Input_Delay`. |

---

## API

### SetReading

```lua
NovoInputService.SetReading(state: boolean)
```

Включает или выключает глобальное чтение ввода.

```lua
NovoInputService.SetReading(false) -- отключить весь ввод
NovoInputService.SetReading(true)  -- включить обратно
```

---

### SetReadTab

```lua
NovoInputService.SetReadTab(actionName: string, state: boolean)
```

Включает или выключает чтение для конкретного действия.

```lua
NovoInputService.SetReadTab("Shoot", false)
```

---

### RegisterCombo

```lua
NovoInputService.RegisterCombo(comboName: string, sequence: {string})
```

Регистрирует комбо: последовательность имён действий, которые нужно нажать подряд.

| Параметр | Тип | Описание |
|---|---|---|
| `comboName` | `string` | Уникальное имя комбо. Повторная регистрация даёт ошибку в лог и `return`. |
| `sequence` | `{string}` | Массив `actionName`, например `{"Kick", "Punch"}`. |

```lua
NovoInputService.RegisterCombo("Hadouken", {"Down", "Forward", "Punch"})
```

При срабатывании вызывается `OnCombo` у действия, чьё имя завершает последовательность. Буфер истории этого комбо очищается.

> `OnCombo` вызывается только у последнего действия из последовательности, не у всех участников.

---

### BindAction

```lua
NovoInputService.BindAction(actionName: string, config: table)
```

Регистрирует действие и (опционально) создаёт мобильную кнопку.

Если действие с таким именем уже зарегистрировано, в лог пишется предупреждение, конфиг перезаписывается. Старая CAS-привязка не снимается автоматически; для чистого перебиндинга вызывай [`UnbindAction`](#unbindaction) заранее.

Полный список полей `config`, см. [Конфигурация действия](#конфигурация-действия).

---

### UnbindAction

```lua
NovoInputService.UnbindAction(actionName: string)
```

Снимает действие:

1. Удаляет запись из внутреннего реестра.
2. Вызывает `ContextActionService:UnbindAction(actionName)`.
3. Удаляет мобильную кнопку `Btn_<actionName>`, если она была создана.

Если действие не зарегистрировано, тихо выходит.

---

## Конфигурация действия

`config` для [`BindAction`](#bindaction).

| Поле | Тип | Описание |
|---|---|---|
| `Keys` | `{Enum.KeyCode \| Enum.UserInputType}` | Клавиши/кнопки для `ContextActionService:BindAction`. Если пусто, CAS-биндинг не создаётся (полезно для чисто тач-кнопок). |
| `MobileUI` | `table?` | Конфиг мобильной кнопки. Создаётся только при `UserInputService.TouchEnabled`. |
| `TapThreshold` | `number` | Порог tap/hold в секундах. По умолчанию `0.2`. |
| `ChargeTime` | `number?` | Полное время заряда в секундах. Требуется для `OnCharge`. |
| `TrackMouse` | `boolean?` | Подписаться на движение мыши (ПК). |

### Колбэки

| Колбэк | Сигнатура | Когда вызывается |
|---|---|---|
| `OnPressed` | `(inputObject) -> ()` | На `Begin`. |
| `OnReleased` | `(inputObject, startPos: Vector2) -> ()` | На `End`, в самом конце. |
| `OnTap` | `(inputObject, startPos: Vector2) -> ()` | На `End`, если удержание `< TapThreshold`. |
| `OnHold` | `(inputObject, startPos: Vector2) -> ()` | На `End`, если удержание `>= TapThreshold`. |
| `OnCharge` | `(percent: number) -> ()` | На `End`, если задан `ChargeTime`. `percent` в диапазоне `[0, 1]`. |
| `OnAnalog` | `(pos: Vector2) -> ()` | На `Change` для любого типа ввода. |
| `OnDrag` | `(delta: Vector2) -> ()` | На `Change`, только Touch, если есть `StartPosition`. Передаёт вектор от точки нажатия. |
| `OnMouseMove` | `(pos: Vector3) -> ()` | При движении мыши, если `TrackMouse == true`. |
| `OnCombo` | `(comboName: string) -> ()` | При срабатывании комбо, где это действие последнее. |

### MobileUI

| Поле | Тип | По умолчанию | Описание |
|---|---|---|---|
| `IsText` | `boolean` | `false` | `true` даёт `TextButton`, `false` даёт `ImageButton`. |
| `Size` | `UDim2` | `UDim2.new(0, 60, 0, 60)` | Размер кнопки. |
| `Position` | `UDim2` | `UDim2.new(0.5, 0, 0.5, 0)` | Позиция кнопки. |
| `Color` | `Color3` | `Color3.fromRGB(255, 255, 255)` | `BackgroundColor3`. |
| `Transparency` | `number` | `0.5` | `BackgroundTransparency`. |
| `Text` | `string` | `""` | Текст (только при `IsText == true`). |
| `Image` | `string` | `""` | Картинка (только при `IsText == false`). |

**Поведение мобильной кнопки.** События `MouseButton1Down` / `MouseButton1Up` / `MouseMoved` прокидываются в общий обработчик как `UserInputType.Touch` с позицией `Vector3(x, y, 0)`. Благодаря этому работают `OnDrag`, `OnTap`, `OnHold`, `OnCharge` и комбо так же, как при реальном тач-вводе.

---

## Жизненный цикл нажатия

```
Begin
 ├─ проверка Reading / ReadTab / InputDelay
 ├─ PressStartTime = now, StartPosition = позиция
 ├─ OnPressed(input)
 └─ проверка комбо (может вызвать OnCombo у завершающего действия)

Change (Touch)
 ├─ OnAnalog(pos)
 └─ OnDrag(pos - StartPosition)   -- если StartPosition задан

Change (Mouse, TrackMouse)
 └─ OnMouseMove(pos)               -- через отдельный InputChanged-хендлер

End
 ├─ held = now - PressStartTime
 ├─ held < TapThreshold ? OnTap : OnHold
 ├─ ChargeTime задан ? OnCharge(clamp(held / ChargeTime, 0, 1))
 ├─ OnReleased(input, StartPosition)
 └─ сброс PressStartTime / StartPosition
```

Все ветки возвращают `Enum.ContextActionResult.Pass`. Модуль не поглощает ввод, событие идёт дальше по цепочке CAS. Для блокировки ввода нужно доработать обработчик вручную (возврат `Sink`).

---

## Комбо

- Буфер каждого комбо это массив имён действий.
- На каждый `Begin` любого действия имя пушится во все зарегистрированные комбо; буфер обрезается до длины `sequence`.
- Комбо срабатывает, когда последние `#sequence` элементов буфера поэлементно совпали с `sequence`.
- После срабатывания буфер этого комбо очищается; буферы остальных комбо не затрагиваются.
- Одно действие может участвовать в нескольких комбо одновременно.
- `OnCombo` вызывается у действия, чьё имя совпало с последним элементом последовательности.

> Буфер пополняется на `Begin`, то есть комбо реагирует на сам факт начала нажатия, а не на tap/hold.

---

## Порядок проверок и фильтрация

Порядок проверок в обработчике ввода:

1. `NovoInputService.Reading == false` даёт `Pass`.
2. `NovoInputService.ReadTab[actionName] == false` даёт `Pass`.
3. Действие не зарегистрировано даёт `Pass`.
4. `(now - LastInputTime) < InputDelay` даёт `Pass`.

Только после этого вызываются колбэки.

`OnMouseMove` подчиняется `Reading` и `ReadTab`, но не подчиняется `InputDelay`: проверка задержки находится только в обработчике `handleInput`, а `OnMouseMove` вызывается из отдельного хендлера `InputChanged`.

---

## Внутренние объекты

Не предназначены для внешнего использования.

| Объект | Назначение |
|---|---|
| Реестр действий | `actionName -> config` плюс рантайм-поля (`PressStartTime`, `StartPosition`, `LastInputTime`). |
| Реестр комбо | `comboName -> sequence`. |
| Буферы комбо | `comboName -> {string}`: история нажатий. |
| `ScreenGui` `"NovoMobileInput"` | Создаётся в `PlayerGui` (`ResetOnSpawn = false`, `IgnoreGuiInset = true`). Родитель мобильных кнопок. |
| `logMessage(kind, text)` | Отладочный вывод в рамке. `kind` принимает `"Out"` / `"Warning"` / `"Error"`. |

---

## Известные особенности

1. **`MouseMoved` на мобильной кнопке.** На ПК `MouseMoved` не срабатывает при зажатой ЛКМ, поэтому `OnDrag` через `MouseMoved` может не приходить. На тач-устройствах работает штатно.
2. **Искусственный `InputObject` для мобильных кнопок.** `GetMouseLocation` возвращает `Vector2`, который конвертируется в `Vector3(x, y, 0)`. В колбэках передаётся таблица, а не настоящий `InputObject`, поэтому поля вроде `input.KeyCode` для мобильной кнопки недоступны.
3. **`OnCombo` не получает `inputObject`**, только имя комбо.
4. **`InputDelay` не действует на `OnMouseMove`**, см. [Порядок проверок](#порядок-проверок-и-фильтрация).
5. **`UnbindAction` не чистит комбо.** Если действие участвовало в последовательности, комбо останется зарегистрированным, но не будет срабатывать (буфер будет копить имена, совпадения не произойдёт). Публичного API для удаления комбо нет.
6. **Повторный `BindAction`** перезаписывает конфиг, но старая CAS-привязка остаётся. Вызывай `UnbindAction` перед повторным биндингом.
7. **`SetReading(false)` не снимает CAS-биндинги.** Ввод продолжает поступать в обработчик и отбрасывается на первой проверке, это дешевле, чем пересоздавать биндинги.
8. **Мобильные кнопки не удаляются при респавне.** `ScreenGui` создаётся с `ResetOnSpawn = false`, кнопки живут всю сессию, пока не вызовешь `UnbindAction` или не удалишь `ScreenGui`.

---

## Пример использования

```lua
local NovoInputService = require(script.Parent.NovoInputService)

script.Parent:SetAttribute("Debugging", true)
script.Parent:SetAttribute("Input_Delay", 0.05)

NovoInputService.RegisterCombo("DoubleJump", {"Jump", "Jump"})

NovoInputService.BindAction("Jump", {
    Keys = { Enum.KeyCode.Space },
    TapThreshold = 0.2,

    OnTap = function()
        print("jump tap")
    end,

    OnCombo = function(comboName)
        print("combo:", comboName) -- "DoubleJump"
    end,

    MobileUI = {
        IsText = true,
        Text = "JMP",
        Position = UDim2.new(1, -80, 1, -80),
    },
})

-- Отключить ввод при открытии меню
NovoInputService.SetReading(false)
-- ...
NovoInputService.SetReading(true)
```
