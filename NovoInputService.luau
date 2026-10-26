local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local NovoInputService = {}

NovoInputService.Reading = true
NovoInputService.ReadTab = {}
local boundActions = {}
local boundCombos = {}
local comboBuffers = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local inputOverlay = Instance.new("ScreenGui")
inputOverlay.Name = "NovoMobileInput"
inputOverlay.ResetOnSpawn = false
inputOverlay.IgnoreGuiInset = true
inputOverlay.Parent = playerGui

local function logMessage(kind, text)
	if not script:GetAttribute("Debugging") then return end
	local ts = os.date("%H:%M:%S")
	local w = 60
	local frame, writer, tag = {tl="-", tr="¬", bl="L", br="-", h="-", v="¦", ml="+", mr="+"}, print, "[OUT]"

	if kind == "Warning" then
		writer, tag = warn, "[WARNING]"
		frame = {tl="?", tr="?", bl="?", br="?", h="?", v="?", ml="?", mr="?"}
	elseif kind == "Error" then
		writer, tag = warn, "[ERROR]"
		frame = {tl="ã", tr="¬", bl="L", br="-", h="=", v="¦", ml="¦", mr="¦"}
	end

	local top = frame.tl .. string.rep(frame.h, w + 2) .. frame.tr
	local head = string.format("%s %s", tag, script.Name)
	local pad = w - #head - #ts - 1
	if pad < 0 then pad = 0 end
	local header = string.format("%s %s%s %s %s", frame.v, head, string.rep(" ", pad), ts, frame.v)
	local mid = frame.ml .. string.rep(frame.h, w + 2) .. frame.mr
	local body = " -> " .. text
	if #body > w then body = body:sub(1, w - 3) .. "..." end
	local bpad = w - #body + 1
	if bpad < 0 then bpad = 0 end
	local line = string.format("%s %s%s %s", frame.v, body, string.rep(" ", bpad), frame.v)
	local bot = frame.bl .. string.rep(frame.h, w + 2) .. frame.br

	writer(table.concat({"\n", top, header, mid, line, bot, "\n"}, "\n"))
end

local delayAttr = script:GetAttribute("Input_Delay") or 0
if type(delayAttr) ~= "number" or delayAttr < 0 then
	task.defer(function() logMessage("Warning", "Invalid Input_Delay attribute. Defaulting to 0.") end)
	NovoInputService.InputDelay = 0
else
	NovoInputService.InputDelay = delayAttr
end

function NovoInputService.SetReading(state)
	NovoInputService.Reading = state
	logMessage("Out", string.format("Global Reading state changed to: %s", tostring(state)))
end

function NovoInputService.SetReadTab(actionName, state)
	NovoInputService.ReadTab[actionName] = state
	logMessage("Out", string.format("Action '%s' reading state changed to: %s", actionName, tostring(state)))
end

function NovoInputService.RegisterCombo(comboName, sequence)
	if boundCombos[comboName] then
		logMessage("Error", string.format("Combo with name '%s' already exists!", comboName))
		return
	end
	boundCombos[comboName] = sequence
	comboBuffers[comboName] = {}
	logMessage("Out", string.format("Registered combo: '%s'", comboName))
end

local function matchCombo(actionName)
	for comboName, sequence in pairs(boundCombos) do
		local buf = comboBuffers[comboName]
		table.insert(buf, actionName)
		if #buf > #sequence then table.remove(buf, 1) end

		local matched = true
		for i = 1, #sequence do
			if buf[i] ~= sequence[i] then matched = false; break end
		end

		if matched and #buf == #sequence then
			logMessage("Out", string.format("Combo triggered: '%s'", comboName))
			comboBuffers[comboName] = {}
			local data = boundActions[actionName]
			if data and data.OnCombo then data.OnCombo(comboName) end
		end
	end
end

local function handleInput(actionName, inputState, inputObject)
	if not NovoInputService.Reading then return Enum.ContextActionResult.Pass end
	if NovoInputService.ReadTab[actionName] == false then return Enum.ContextActionResult.Pass end

	local data = boundActions[actionName]
	if not data then return Enum.ContextActionResult.Pass end

	local t = tick()
	if data.LastInputTime and (t - data.LastInputTime) < NovoInputService.InputDelay then
		return Enum.ContextActionResult.Pass
	end
	data.LastInputTime = t

	if inputState == Enum.UserInputState.Change then
		if data.OnAnalog then
			data.OnAnalog(Vector2.new(inputObject.Position.X, inputObject.Position.Y))
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch and data.StartPosition then
			if data.OnDrag then
				local cur = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
				data.OnDrag(cur - data.StartPosition)
			end
		end
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		data.PressStartTime = t
		data.StartPosition = Vector2.new(inputObject.Position.X, inputObject.Position.Y)

		if data.OnPressed then data.OnPressed(inputObject) end
		matchCombo(actionName)

	elseif inputState == Enum.UserInputState.End then
		local held = t - (data.PressStartTime or t)
		local thresh = data.TapThreshold or 0.2

		if held < thresh then
			if data.OnTap then data.OnTap(inputObject, data.StartPosition) end
		else
			if data.OnHold then data.OnHold(inputObject, data.StartPosition) end
		end

		if data.ChargeTime and data.OnCharge then
			data.OnCharge(math.clamp(held / data.ChargeTime, 0, 1))
		end

		if data.OnReleased then data.OnReleased(inputObject, data.StartPosition) end
		data.PressStartTime = nil
		data.StartPosition = nil
	end

	return Enum.ContextActionResult.Pass
end

local function casWrapper(actionName, inputState, inputObject)
	return handleInput(actionName, inputState, inputObject)
end

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		for actionName, data in pairs(boundActions) do
			if data.TrackMouse and data.OnMouseMove then
				if NovoInputService.Reading and NovoInputService.ReadTab[actionName] ~= false then
					data.OnMouseMove(input.Position)
				end
			end
		end
	end
end)

function NovoInputService.BindAction(actionName, config)
	if boundActions[actionName] then
		logMessage("Warning", string.format("Action '%s' is already bound. Overwriting.", actionName))
	end

	boundActions[actionName] = config
	local keys = config.Keys or {}

	if #keys > 0 then
		ContextActionService:BindAction(actionName, casWrapper, false, table.unpack(keys))
	end

	if config.MobileUI and UserInputService.TouchEnabled then
		local useText = config.MobileUI.IsText == true
		local btn = Instance.new(useText and "TextButton" or "ImageButton")
		btn.Name = "Btn_" .. actionName
		btn.Size = config.MobileUI.Size or UDim2.new(0, 60, 0, 60)
		btn.Position = config.MobileUI.Position or UDim2.new(0.5, 0, 0.5, 0)
		btn.BackgroundColor3 = config.MobileUI.Color or Color3.fromRGB(255, 255, 255)
		btn.BackgroundTransparency = config.MobileUI.Transparency or 0.5

		if useText then
			btn.Text = config.MobileUI.Text or ""
		else
			btn.Image = config.MobileUI.Image or ""
		end

		btn.Parent = inputOverlay

		btn.MouseButton1Down:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			handleInput(actionName, Enum.UserInputState.Begin, {
				Position = Vector3.new(pos.X, pos.Y, 0),
				UserInputType = Enum.UserInputType.Touch
			})
		end)

		btn.MouseButton1Up:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			handleInput(actionName, Enum.UserInputState.End, {
				Position = Vector3.new(pos.X, pos.Y, 0),
				UserInputType = Enum.UserInputType.Touch
			})
		end)

		btn.MouseMoved:Connect(function(x, y)
			handleInput(actionName, Enum.UserInputState.Change, {
				Position = Vector3.new(x, y, 0),
				UserInputType = Enum.UserInputType.Touch
			})
		end)

		logMessage("Out", string.format("Created custom mobile UI for: '%s'", actionName))
	end

	logMessage("Out", string.format("Successfully bound action: '%s'", actionName))
end

function NovoInputService.UnbindAction(actionName)
	if not boundActions[actionName] then return end
	boundActions[actionName] = nil
	ContextActionService:UnbindAction(actionName)

	local btn = inputOverlay:FindFirstChild("Btn_" .. actionName)
	if btn then btn:Destroy() end

	logMessage("Out", string.format("Successfully unbound action: '%s'", actionName))
end

logMessage("Out", "NovoInputService Initialized (v3.0)")
return NovoInputService