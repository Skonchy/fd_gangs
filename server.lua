ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function StartHandcuffTimer()
	if Config.EnableHandcuffTimer and handcuffTimer.active then
		ESX.ClearTimeout(handcuffTimer.task)
    end
    handcuffTimer.active = true

	handcuffTimer.task = ESX.SetTimeout(Config.HandcuffTimer, function()
		ESX.ShowNotification(_U('unrestrained_timer'))
		TriggerEvent('fd_gangs:unrestrain')
		handcuffTimer.active = false
	end)
end

ESX.RegisterServerCallback('fd_gangs:isBoss', function(source,cb,gang)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.Async.fetchAll("SELECT * FROM users WHERE gang IS NOT NULL AND identifier=@identifier", {
		['@identifier']=xPlayer.identifier
	}, function(result)
		xPlayer.gang=result[1].gang
		xPlayer.gang_grade=result[1].gang_grade
	end)

	while xPlayer.gang == nil do
		Citizen.Wait(100)
	end

	if xPlayer.gang == gang and xPlayer.gang_grade == 5 then
		cb(true)
	else
		cb(false)
	end
end)

ESX.RegisterServerCallback('fd_gangs:whatGang', function(source, cb, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	if(xPlayer~=nil) then
    	MySQL.Async.fetchAll("SELECT * FROM users WHERE gang IS NOT NULL AND identifier = @identifier", {['@identifier']=xPlayer.identifier}, function(result)
        	cb(result)
		end)
	end
end)

ESX.RegisterServerCallback('fd_gangs:getOnlinePlayers', function(source, cb)
	local xPlayers = ESX.GetPlayers()
	local players  = {}

	for i=1, #xPlayers, 1 do
		local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
		table.insert(players, {
			source     = xPlayer.source,
			identifier = xPlayer.identifier,
			name       = xPlayer.name,
			job        = xPlayer.job
		})
	end

	cb(players)
end)

ESX.RegisterServerCallback('fd_gangs:getMembers', function(source, cb, society)
	if Config.EnableESXIdentity then
		local res
		MySQL.Async.fetchAll('SELECT firstname, lastname, identifier, gang, gang_grade FROM users WHERE gang = @job ORDER BY gang_grade DESC', {
			['@job'] = society
		}, function (results)
			MySQL.Async.fetchAll("SELECT name FROM ganglist WHERE id=@id",{
				['@id'] = society
			}, function(result)
				res=result
			end)
			local employees = {}

			for i=1, #results, 1 do
				table.insert(employees, {
					name       = results[i].firstname .. ' ' .. results[i].lastname,
					identifier = results[i].identifier,
					job = {
						name        = results[i].gang,
						label       = res,
						grade       = results[i].gang_grade,
					}
				})
			end

			cb(employees)
		end)
	else
	end
end)


function setGang(target, gang, grade)
    local identifier = target[1].identifier
    MySQL.Async.execute("UPDATE users SET gang =@gang, grade=@grade WHERE identifier=@identifier",{
        ['@gang']=gang,
        ['@grade']=grade,
        ['@identifier']=identifier
    }, function(result)
    
    end)

end

function getGang(target)
    local identifier = target.identifier
    local gangName
    MySQL.Async.fetchAll("SELECT gang FROM users WHERE identifier=@identifier",{
        ['@identifier']=identifier
    }, function(result)
        MySQL.Async.fetchAll("SELECT name FROM ganglist WHERE id=@id",{
            ['@id']=result
        }, function(res)
            gangName=res
        end)
    end)

end

ESX.RegisterServerCallback('fd_gangs:setGang', function(source, cb, identifier, gang, grade, type)
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)

    if xTarget then
        setGang(target, gang, grade)

        if type == 'hire' then
            xTarget.showNotification(_U('you_have_been_hired', gang))
        elseif type == 'promote' then
            xTarget.showNotification(_U('you_have_been_promoted'))
        elseif type == 'fire' then
            xTarget.showNotification(_U('you_have_been_fired', getGang(xTarget)))
        end

        cb()
    else
        MySQL.Async.execute('UPDATE users SET gang = @job, gang_grade = @job_grade WHERE identifier = @identifier', {
            ['@job']        = gang,
            ['@job_grade']  = grade,
            ['@identifier'] = identifier
        }, function(rowsChanged)
            cb()
        end)
    end
end)

ESX.RegisterServerCallback('fd_gangs:getOtherPlayerData', function(source, cb, target, notify)
    local xPlayer = ESX.GetPlayerFromId(target)

	if notify then
		xPlayer.showNotification(_U('being_searched'))
	end

	if xPlayer then
		local data = {
			name = xPlayer.getName(),
			job = xPlayer.job.label,
            grade = xPlayer.job.grade_label,
			inventory = xPlayer.getInventory(),
			accounts = xPlayer.getAccounts(),
			weapons = xPlayer.getLoadout()
		}

		if Config.EnableESXIdentity then
			data.dob = xPlayer.get('dateofbirth')
			data.height = xPlayer.get('height')

			if xPlayer.get('sex') == 'm' then data.sex = 'male' else data.sex = 'female' end
		end
        cb(data)
	end
end)


RegisterNetEvent('fd_gangs:confiscatePlayerItem')
AddEventHandler('fd_gangs:confiscatePlayerItem', function(target, itemType, itemName, amount)
	local _source = source
	local sourceXPlayer = ESX.GetPlayerFromId(_source)
	local targetXPlayer = ESX.GetPlayerFromId(target)

	if itemType == 'item_standard' then
		local targetItem = targetXPlayer.getInventoryItem(itemName)
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)

		-- does the target player have enough in their inventory?
		if targetItem.count > 0 and targetItem.count <= amount then

			-- can the player carry the said amount of x item?
			if sourceXPlayer.canCarryItem(itemName, sourceItem.count) then
				targetXPlayer.removeInventoryItem(itemName, amount)
				sourceXPlayer.addInventoryItem   (itemName, amount)
				sourceXPlayer.showNotification(_U('you_confiscated', amount, sourceItem.label, targetXPlayer.name))
				targetXPlayer.showNotification(_U('got_confiscated', amount, sourceItem.label, sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('quantity_invalid'))
			end
		else
			sourceXPlayer.showNotification(_U('quantity_invalid'))
		end

	elseif itemType == 'item_account' then
		targetXPlayer.removeAccountMoney(itemName, amount)
		sourceXPlayer.addAccountMoney   (itemName, amount)

		sourceXPlayer.showNotification(_U('you_confiscated_account', amount, itemName, targetXPlayer.name))
		targetXPlayer.showNotification(_U('got_confiscated_account', amount, itemName, sourceXPlayer.name))

	elseif itemType == 'item_weapon' then
		if amount == nil then amount = 0 end
		targetXPlayer.removeWeapon(itemName, amount)
		sourceXPlayer.addWeapon   (itemName, amount)

		sourceXPlayer.showNotification(_U('you_confiscated_weapon', ESX.GetWeaponLabel(itemName), targetXPlayer.name, amount))
		targetXPlayer.showNotification(_U('got_confiscated_weapon', ESX.GetWeaponLabel(itemName), amount, sourceXPlayer.name))
	end
end)

RegisterNetEvent('fd_gangs:handcuff')
AddEventHandler('fd_gangs:handcuff', function(target)
	TriggerClientEvent('fd_gangs:handcuff', target)
end)

RegisterNetEvent('fd_gangs:drag')
AddEventHandler('fd_gangs:drag', function(target)
    TriggerClientEvent('fd_gangs:drag', target, source)
end)

RegisterNetEvent('fd_gangs:putInCar')
AddEventHandler('fd_gangs:putInCar', function(target)
    TriggerClientEvent('fd_gangs:putInCar', target)
end)

RegisterNetEvent('fd_gangs:outOfCar')
AddEventHandler('fd_gangs:outOfCar', function(target)
    TriggerClientEvent('fd_gangs:outOfCar', target)
end)

RegisterNetEvent('fd_gangs:unrestrain')
AddEventHandler('fd_gangs:unrestrain', function()
	if isHandcuffed then
		local playerPed = PlayerPedId()
		isHandcuffed = false

		ClearPedSecondaryTask(playerPed)
		SetEnableHandcuffs(playerPed, false)
		DisablePlayerFiring(playerPed, false)
		SetPedCanPlayGestureAnims(playerPed, true)
		FreezeEntityPosition(playerPed, false)
		DisplayRadar(true)

		-- end timer
		if Config.EnableHandcuffTimer and handcuffTimer.active then
			ESX.ClearTimeout(handcuffTimer.task)
		end
	end
end)

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end