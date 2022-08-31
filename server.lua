local ESX = nil;

TriggerEvent("esx:getSharedObject", function(obj)
	ESX = obj;
end);

RegisterNetEvent("ngTuning:PreviewValues", function(values)
	local playerPed = GetPlayerPed(source);
	local vehicle = GetVehiclePedIsIn(playerPed, false);
	local netId = NetworkGetNetworkIdFromEntity(vehicle);
	TriggerClientEvent("ngTuning:SetSyncValues", -1, netId, values);
	
	--print("setting", netId, values);
end);

local function GetPlate(vehicle)
	local plate = GetVehicleNumberPlateText(vehicle);
	
	if not plate then
		return nil;
	end
	
	return plate:gsub("^%s*(.-)%s*$", "%1");
end

local function GetCurrentPlate(src)
	local playerPed = GetPlayerPed(src);
	local vehicle = GetVehiclePedIsIn(playerPed, false);
	return GetPlate(vehicle);
end

ESX.RegisterServerCallback("ngTuning:GetDefaults", function(src, cb)
	local plate = GetCurrentPlate(src);

	if not plate then 
		return;
	end

	MySQL.Async.fetchAll("SELECT ngTuning FROM owned_vehicles WHERE plate = @plate", {
		["@plate"] = plate,
	}, function(results)
		if #results > 0 then
			local data = json.decode(results[1].ngTuning) or {};
			if data.default ~= nil then
				cb(data.default);
			else
				cb(nil);
			end
		else
			cb(nil);
		end
	end);
end);

ESX.RegisterServerCallback("ngTuning:RequestSyncValues", function(src, cb, netId)
	local vehicle = NetworkGetEntityFromNetworkId(netId);
	local plate = GetPlate(vehicle);	
	
	if not plate then
		return;
	end

	MySQL.Async.fetchAll("SELECT ngTuning FROM owned_vehicles WHERE plate = @plate", {
		["@plate"] = plate,
	}, function(results)
		if #results > 0 then
			local data = json.decode(results[1].ngTuning) or {};
			if data.current ~= nil then
				cb(data.current);
			elseif data.default ~= nil then
				cb(data.default);
			else
				cb({});
			end
		else
			cb({});
		end
	end);
end);

RegisterNetEvent("ngTuning:SaveDefaults", function(values)
	local plate = GetCurrentPlate(source);
	
	if not plate then
		return;
	end
	
	MySQL.Async.fetchAll("SELECT ngTuning FROM owned_vehicles WHERE plate = @plate", {
		["@plate"] = plate,
	}, function(results)
		if #results > 0 then
			local data = json.decode(results[1].ngTuning) or {};
			data.default = values;
			MySQL.Async.execute("UPDATE owned_vehicles SET ngTuning = @data WHERE plate = @plate", {
				["@plate"] = plate,
				["@data"] = json.encode(data),
			}, function() end);
		end
	end);
end);

ESX.RegisterServerCallback("ngTuning:ApplyValues", function(src, cb, values)
	local xPlayer = ESX.GetPlayerFromId(src);
	
	TriggerEvent('esx_addonaccount:getSharedAccount', "society_" .. xPlayer.getJob().name, function(account)
		if not account then
			xPlayer.showNotification(_U("account_not_found"));
			cb(false);
		end

		if account.money <= Config.Price then
			xPlayer.showNotification(_U("not_enough_money"));
			cb(false);
		end
		
		local plate = GetCurrentPlate(src);
		
		if not plate then
			return;
		end
		
		MySQL.Async.fetchAll("SELECT ngTuning FROM owned_vehicles WHERE plate = @plate", {
			["@plate"] = plate,
		}, function(results)
			if #results > 0 then
				local data = json.decode(results[1].ngTuning) or {};
				data.current = values;
				account.removeMoney(Config.Price);	
				
				MySQL.Async.execute("UPDATE owned_vehicles SET ngTuning = @data WHERE plate = @plate", {
					["@plate"] = plate,
					["@data"] = json.encode(data),
				}, function()
					xPlayer.showNotification(_U("apply_message", Config.Price));
					TriggerClientEvent("ngTuning:SetSyncValues", -1, values);
					cb(true);
				end);
			else
				-- this vehicle is not registered. just say okay.
				xPlayer.showNotification(_U("apply_message", Config.Price));
				TriggerClientEvent("ngTuning:SetSyncValues", -1, values);
				cb(true);
			end
		end);
	end);
end);