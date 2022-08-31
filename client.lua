local menuPool = NativeUI.CreatePool();
local ESX = nil;

Citizen.CreateThread(function()
	TriggerEvent("esx:getSharedObject", function(obj)
		ESX = obj;
	end);
	
	Citizen.Wait(0);
end);

local syncValues = {};

local function SetSyncValues(netId, values)
	syncValues[netId] = values;
end
RegisterNetEvent("ngTuning:SetSyncValues", SetSyncValues);

Citizen.CreateThread(function()
	while true do
		for netId,values in pairs(syncValues) do
			if NetworkDoesEntityExistWithNetworkId(netId) then
				--[[if values.WheelWidth and values.WheelSize then
					local vehicle = NetworkGetEntityFromNetworkId(netId);
					
					SetVehicleWheelWidth(vehicle, values.WheelWidth);
					SetVehicleWheelSize(vehicle, values.WheelSize);
				end]]--
			else
				if not NetworkDoesNetworkIdExist(netId) then
					syncValues[netId] = nil;
				end
			end
		end
		
		-- every 100 ticks: request syncValues for one vehicle where syncValues are missing
		for _,vehicle in pairs(GetGamePool("CVehicle")) do
			local netId = NetworkGetNetworkIdFromEntity(vehicle);
			
			if syncValues[netId] == nil then
				--print("requesting", netId);
				ESX.TriggerServerCallback("ngTuning:RequestSyncValues", function(values)
					--print("received", netId);
					SetSyncValues(netId, values);
				end, netId);
				break;
				-- we break here so we only send one RequestSyncValues event per 100ticks to prevent a net event overflow
			end
		end
		
		Citizen.Wait(1000);
	end
end);

Citizen.CreateThread(function()
    while true do		
		for netId,values in pairs(syncValues) do
			if NetworkDoesEntityExistWithNetworkId(netId) then
				local vehicle = NetworkGetEntityFromNetworkId(netId);
				
				if values.FrontTrackWidth then
					SetFrontTrackWidth(vehicle, values.FrontTrackWidth);
				end
				if values.RearTrackWidth then
					SetRearTrackWidth(vehicle, values.RearTrackWidth);
				end
				if values.FrontCamber then
					SetFrontCamber(vehicle, values.FrontCamber);
				end
				if values.RearCamber then
					SetRearCamber(vehicle, values.RearCamber);
				end
				if values.WheelWidth then
					SetVehicleWheelWidth(vehicle, values.WheelWidth);
				end
				if values.WheelSize then
					SetVehicleWheelSize(vehicle, values.WheelSize);
				end
			end
		end
		
		if IsPedInAnyVehicle(PlayerPedId(), false) then
			local coords = GetEntityCoords(PlayerPedId());
			
			for _, zone in pairs(Config.Zones) do
				if not zone.Job or (ESX.GetPlayerData().job and ESX.GetPlayerData().job.name == zone.Job) then
					if GetDistanceBetweenCoords(coords, zone.x, zone.y, zone.z, true) < zone.Radius then
						if not menuPool:IsAnyMenuOpen() then
							ESX.ShowHelpNotification(_U("open_menu_hint"));
							
							if IsControlJustPressed(0, 38) then
								OpenMenu();
							end
						end
					end
				end
			end
		end
	
        Citizen.Wait(0)
		
        menuPool:ProcessMenus()
    end
end)

function SetFrontTrackWidth(vehicle, value)
	local wheelsCount = GetVehicleNumberOfWheels(vehicle);
	local frontCount = CalculateFrontWheelsCount(wheelsCount);
	
    for index = 0, frontCount - 1, 1 do
        if index % 2 == 0 then
	        SetVehicleWheelXOffset(vehicle, index, value);
        else
            SetVehicleWheelXOffset(vehicle, index, -value);
        end
    end
end

function SetFrontCamber(vehicle, value) 
	local wheelsCount = GetVehicleNumberOfWheels(vehicle);
	local frontCount = CalculateFrontWheelsCount(wheelsCount);
    for index = 0, frontCount - 1, 1 do
        if index % 2 == 0 then
            SetVehicleWheelYRotation(vehicle, index, value);
        else
            SetVehicleWheelYRotation(vehicle, index, -value);
        end
    end
end

function SetRearTrackWidth(vehicle, value)
	local wheelsCount = GetVehicleNumberOfWheels(vehicle);
	local frontCount = CalculateFrontWheelsCount(wheelsCount);
    for index = frontCount, wheelsCount - 1, 1 do
        if index % 2 == 0 then
            SetVehicleWheelXOffset(vehicle, index, value);
        else
            SetVehicleWheelXOffset(vehicle, index, -value);
        end
    end
end

function SetRearCamber(vehicle, value)
	local wheelsCount = GetVehicleNumberOfWheels(vehicle);
	local frontCount = CalculateFrontWheelsCount(wheelsCount);
    for index = frontCount, wheelsCount - 1, 1 do
        if index % 2 == 0 then
            SetVehicleWheelYRotation(vehicle, index, value);
        else
            SetVehicleWheelYRotation(vehicle, index, -value);
        end
    end
end

function CalculateFrontWheelsCount(wheelsCount)
    local frontWheelsCount = wheelsCount / 2;
    if frontWheelsCount % 2 ~= 0 then
        frontWheelsCount = frontWheelsCount - 1;
    end

    return math.floor(frontWheelsCount);
end

function CopyTableShallow(original)
    ret = {}
    for k,v in pairs(original) do
        ret[k] = v;
    end
    return ret;
end

-- Can return 0 for default wheels.
-- SetVehicleWheelWidth(vehicle, value);

-- Can return 0 for default wheels.
-- SetVehicleWheelSize(vehicle, value);

function GetCurrentVehicleValues()
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false);
	local wheelsCount = GetVehicleNumberOfWheels(vehicle);
	local frontCount = CalculateFrontWheelsCount(wheelsCount);

	return {
		FrontCamber = GetVehicleWheelYRotation(vehicle, 0),
		RearCamber = GetVehicleWheelYRotation(vehicle, frontCount),
		FrontTrackWidth = GetVehicleWheelXOffset(vehicle, 0),
		RearTrackWidth = GetVehicleWheelXOffset(vehicle, frontCount),
		WheelWidth = GetVehicleWheelWidth(vehicle),
		WheelSize = GetVehicleWheelSize(vehicle),
	};
end

function GetOptions(center, increment)
	local options = {};
	for i = 0, Config.SliderResolution, 1 do
		options[i] = center + (i - Config.SliderResolution / 2) * increment
	end
	
	return options;
end

function GetSelectedIndex(options, value)
	if value >= options[#options] then
		return #options;
	end
	
	if value < options[1] then
		return 1;
	end

	for k,v in pairs(options) do
		if v >= value then
			return k;
		end
	end
	
	return math.floor(Config.SliderResolution / 2);
end

function OpenMenu()
	local playerPed = GetPlayerPed(PlayerId());
	local vehicle = GetVehiclePedIsIn(playerPed, false);
	local current = GetCurrentVehicleValues();
	local persistent = GetCurrentVehicleValues();
	
	ESX.TriggerServerCallback("ngTuning:GetDefaults", function(default)
		if default == nil then
			default = CopyTableShallow(current);
			TriggerServerEvent("ngTuning:SaveDefaults", default);
		end		
		
		local menu = NativeUI.CreateMenu(_U("menu_title"), _U("menu_subtitle"));
		menuPool:Clear();
		menuPool:Add(menu);
		collectgarbage();
		
		local frontTrackWidthOptions = GetOptions(default.FrontTrackWidth, Config.Increments.FrontTrackWidth);
		local selectedFrontTrackWidth = GetSelectedIndex(frontTrackWidthOptions, current.FrontTrackWidth);
		local frontTrackWidth = NativeUI.CreateSliderItem(_U("front_track_width"), frontTrackWidthOptions, selectedFrontTrackWidth, false);
		menu:AddItem(frontTrackWidth);
		
		local rearTrackWidthOptions = GetOptions(default.RearTrackWidth, Config.Increments.RearTrackWidth);
		local selectedRearTrackWidth = GetSelectedIndex(rearTrackWidthOptions, current.RearTrackWidth);
		local rearTrackWidth = NativeUI.CreateSliderItem(_U("rear_track_width"), rearTrackWidthOptions, selectedRearTrackWidth, false);
		menu:AddItem(rearTrackWidth);
		
		local frontCamberOptions = GetOptions(default.FrontCamber, Config.Increments.FrontCamber);
		local selectedFrontCamber = GetSelectedIndex(frontCamberOptions, current.FrontCamber);
		local frontCamber = NativeUI.CreateSliderItem(_U("front_camber"), frontCamberOptions, selectedFrontCamber, false);
		menu:AddItem(frontCamber);
		
		local rearCamberOptions = GetOptions(default.RearCamber, Config.Increments.RearCamber);
		local selectedRearCamber = GetSelectedIndex(rearCamberOptions, current.RearCamber);
		local rearCamber = NativeUI.CreateSliderItem(_U("rear_camber"), rearCamberOptions, selectedRearCamber, false);
		menu:AddItem(rearCamber);
		
		local wheelWidth = nil;
		local wheelSize = nil;
		
		--print(current.WheelWidth);
		if current.WheelWidth then
			local wheelWidthOptions = GetOptions(default.WheelWidth, Config.Increments.WheelWidth);
			local selectedWheelWidth = GetSelectedIndex(wheelWidthOptions, current.WheelWidth);
			wheelWidth = NativeUI.CreateSliderItem(_U("wheel_width"), wheelWidthOptions, selectedWheelWidth, false);
			menu:AddItem(wheelWidth);
			
			local wheelSizeOptions = GetOptions(default.WheelSize, Config.Increments.WheelSize);
			local selectedWheelSize = GetSelectedIndex(wheelSizeOptions, current.WheelSize);
			wheelSize = NativeUI.CreateSliderItem(_U("wheel_size"), wheelSizeOptions, selectedWheelSize, false);
			menu:AddItem(wheelSize);
		end
		
		local buyButton = NativeUI.CreateItem(_U("apply"), _U("apply_description", Config.Price));
		buyButton:SetRightBadge(BadgeStyle.Tick);
		menu:AddItem(buyButton);
		
		menu.OnItemSelect = function(sender, item, index) 
			if item == buyButton then
				ESX.TriggerServerCallback("ngTuning:ApplyValues", function(success)
					if success then
						menuPool:CloseAllMenus();
					end
				end, current);
			end
		end
		
		menu.OnSliderChange = function(sender, item, index)
			local value = item:IndexToItem(index);
			if item == frontTrackWidth then
				current.FrontTrackWidth = value;
			elseif item == rearTrackWidth then
				current.RearTrackWidth = value;
			elseif item == frontCamber then
				current.FrontCamber = value;
			elseif item == rearCamber then
				current.RearCamber = value;
			elseif item == wheelWidth then
				current.WheelWidth = value;
			elseif item == wheelSize then
				current.WheelSize = value;
			end
		
			TriggerServerEvent("ngTuning:PreviewValues", current);
		end
		
		local originalGoBack = menu.GoBack;
		menu.GoBack = function(self)
			originalGoBack(self);
			TriggerServerEvent("ngTuning:PreviewValues", persistent);
		end
		
		menu.OnMenuClosed = function()
		end
		
		menu:Visible(true);

		menuPool:MouseControlsEnabled(false);
		menuPool:MouseEdgeEnabled(false);
		menuPool:RefreshIndex();
	end);
end