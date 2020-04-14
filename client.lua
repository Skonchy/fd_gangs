ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local player=ESX.GetPlayerData()
local currentAction

Citizen.CreateThread(function()
    while true do
        --if ESX.IsPlayerLoaded() then
            ESX.TriggerServerCallback('fd_gangs:whatGang',function(xPlayer)
            player.gang=xPlayer[1].gang
            player.gang_grade=xPlayer[1].gang_grade
            end)
            Citizen.Wait(1500)
        --end
    end
end)

local isHandcuffed = false
local handcuffTimer, dragStatus = {}, {}

function OpenGangActionsMenu()
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default',GetCurrentResourceName(),'gang_actions', {
        title = 'Hood Shit',
        align = 'top-left',
        elements = {
            {label = _U('id_card'), value = 'identity_card'},
            {label = _U('search'), value = 'search'},
            {label = _U('handcuff'), value = 'handcuff'},
            {label = _U('drag'), value = 'drag'},
            {label = _U('put_in_car'), value = 'put_in_car'},
            {label = _U('out_of_car'), value = 'out_of_car'},
            {label= _U('boss_actions'), value= 'boss_actions'}
        }
    }, function(data,menu)
        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
        local action = data.current.value
        
        if closestPlayer ~=-1 and closestDistance <= 3.0 then
            if action == 'identity_card' then
                OpenIdentityCardMenu(closestPlayer)
            elseif action == 'search' then
                OpenBodySearchMenu(closestPlayer)
            elseif action == 'handcuff' then
                TriggerServerEvent('fd_gangs:handcuff', GetPlayerServerId(closestPlayer))
            elseif action == 'drag' then
                TriggerServerEvent('fd_gangs:drag', GetPlayerServerId(closestPlayer))
            elseif action == 'put_in_car' then
                TriggerServerEvent('fd_gangs:putInCar', GetPlayerServerId(closestPlayer))
            elseif action == 'out_of_car' then
                TriggerServerEvent('fd_gangs:outOfCar', GetPlayerServerId(closestPlayer))
            end
        else
			if action == 'boss_actions' then 
                TriggerEvent('fd_gangs:openBossMenu',player.gang,function(data, menu)
                    menu.close()
                end, {wash = true})
            end
        end
        menu.close()
    end)

end

RegisterNetEvent('fd_gangs:openBossMenu')
AddEventHandler('fd_gangs:openBossMenu', function(gang,close,options)
	OpenBossMenu(gang,close,options)
end)

function OpenIdentityCardMenu(player)
	ESX.TriggerServerCallback('fd_gangs:getOtherPlayerData', function(data)
		local elements = {
			{label = _U('name', data.name)},
			{label = _U('job', ('%s - %s'):format(data.job, data.grade))}
		}

		if Config.EnableESXIdentity then
			table.insert(elements, {label = _U('sex', _U(data.sex))})
			table.insert(elements, {label = _U('dob', data.dob)})
			table.insert(elements, {label = _U('height', data.height)})
		end

		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gang_actions', {
			title    = _U('citizen_interaction'),
			align    = 'top-left',
			elements = elements
		}, nil, function(data, menu)
			menu.close()
		end)
	end, GetPlayerServerId(player))
end

function OpenBodySearchMenu(player)
	ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(data)
		local elements = {}

		for i=1, #data.accounts, 1 do
			if data.accounts[i].name == 'black_money' and data.accounts[i].money > 0 then
				table.insert(elements, {
					label    = _U('confiscate_dirty', ESX.Math.Round(data.accounts[i].money)),
					value    = 'black_money',
					itemType = 'item_account',
					amount   = data.accounts[i].money
				})

				break
			end
		end

		table.insert(elements, {label = _U('guns_label')})

		for i=1, #data.weapons, 1 do
			table.insert(elements, {
				label    = _U('confiscate_weapon', ESX.GetWeaponLabel(data.weapons[i].name), data.weapons[i].ammo),
				value    = data.weapons[i].name,
				itemType = 'item_weapon',
				amount   = data.weapons[i].ammo
			})
		end

		table.insert(elements, {label = _U('inventory_label')})

		for i=1, #data.inventory, 1 do
			if data.inventory[i].count > 0 then
				table.insert(elements, {
					label    = _U('confiscate_inv', data.inventory[i].count, data.inventory[i].label),
					value    = data.inventory[i].name,
					itemType = 'item_standard',
					amount   = data.inventory[i].count
				})
			end
		end

		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'body_search', {
			title    = _U('search'),
			align    = 'top-left',
			elements = elements
		}, function(data, menu)
			if data.current.value then
				TriggerServerEvent('fd_gangs:confiscatePlayerItem', GetPlayerServerId(player), data.current.itemType, data.current.value, data.current.amount)
				OpenBodySearchMenu(player)
			end
		end, function(data, menu)
			menu.close()
		end)
	end, GetPlayerServerId(player))
end

RegisterNetEvent('fd_gangs:handcuff')
AddEventHandler('fd_gangs:handcuff', function()
    isHandcuffed = not isHandcuffed
	local playerPed = PlayerPedId()

	if isHandcuffed then
		RequestAnimDict('mp_arresting')
		while not HasAnimDictLoaded('mp_arresting') do
			Citizen.Wait(100)
		end

		TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)

		SetEnableHandcuffs(playerPed, true)
		DisablePlayerFiring(playerPed, true)
		SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true) -- unarm player
		SetPedCanPlayGestureAnims(playerPed, false)
		FreezeEntityPosition(playerPed, true)
		DisplayRadar(false)

		if Config.EnableHandcuffTimer then
			if handcuffTimer.active then
				ESX.ClearTimeout(handcuffTimer.task)
			end

			StartHandcuffTimer()
		end
	else
		if Config.EnableHandcuffTimer and handcuffTimer.active then
			ESX.ClearTimeout(handcuffTimer.task)
		end

		ClearPedSecondaryTask(playerPed)
		SetEnableHandcuffs(playerPed, false)
		DisablePlayerFiring(playerPed, false)
		SetPedCanPlayGestureAnims(playerPed, true)
		FreezeEntityPosition(playerPed, false)
		DisplayRadar(true)
	end
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

RegisterNetEvent('fd_gangs:drag')
AddEventHandler('fd_gangs:drag', function(id)
	if isHandcuffed then
		dragStatus.isDragged = not dragStatus.isDragged
		dragStatus.id = id
	end
end)

Citizen.CreateThread(function()
	local wasDragged

	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()

		if isHandcuffed and dragStatus.isDragged then
			local targetPed = GetPlayerPed(GetPlayerFromServerId(dragStatus.id))

			if DoesEntityExist(targetPed) and IsPedOnFoot(targetPed) and not IsPedDeadOrDying(targetPed, true) then
				if not wasDragged then
					AttachEntityToEntity(playerPed, targetPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
					wasDragged = true
				else
					Citizen.Wait(1000)
				end
			else
				wasDragged = false
				dragStatus.isDragged = false
				DetachEntity(playerPed, true, false)
			end
		elseif wasDragged then
			wasDragged = false
			DetachEntity(playerPed, true, false)
		else
			Citizen.Wait(500)
		end
	end
end)

RegisterNetEvent('fd_gangs:putInCar')
AddEventHandler('fd_gangs:putInCar', function()
	if isHandcuffed then
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)

		if IsAnyVehicleNearPoint(coords, 5.0) then
			local vehicle = GetClosestVehicle(coords, 5.0, 0, 71)

			if DoesEntityExist(vehicle) then
				local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)

				for i=maxSeats - 1, 0, -1 do
					if IsVehicleSeatFree(vehicle, i) then
						freeSeat = i
						break
					end
				end

				if freeSeat then
					TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
					dragStatus.isDragged = false
				end
			end
		end
	end
end)

RegisterNetEvent('fd_gangs:outOfCar')
AddEventHandler('fd_gangs:outOfCar', function()
    local playerPed = PlayerPedId()

	if IsPedSittingInAnyVehicle(playerPed) then
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		TaskLeaveVehicle(playerPed, vehicle, 16)
	end
end)

-- Handcuff
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()

		if isHandcuffed then
			DisableControlAction(0, 1, false) -- Disable pan
			DisableControlAction(0, 2, false) -- Disable tilt
			DisableControlAction(0, 24, true) -- Attack
			DisableControlAction(0, 257, true) -- Attack 2
			DisableControlAction(0, 25, true) -- Aim
			DisableControlAction(0, 263, true) -- Melee Attack 1
			DisableControlAction(0, 32, false) -- W
			DisableControlAction(0, 34, false) -- A
			DisableControlAction(0, 31, false) -- S
			DisableControlAction(0, 30, false) -- D

			DisableControlAction(0, 45, true) -- Reload
			DisableControlAction(0, 22, true) -- Jump
			DisableControlAction(0, 44, true) -- Cover
			DisableControlAction(0, 37, true) -- Select Weapon
			DisableControlAction(0, 23, true) -- Also 'enter'?

			DisableControlAction(0, 288,  true) -- Disable phone
			DisableControlAction(0, 289, true) -- Inventory
			DisableControlAction(0, 170, true) -- Animations
			DisableControlAction(0, 167, true) -- Job

			DisableControlAction(0, 0, false) -- Disable changing view
			DisableControlAction(0, 26, false) -- Disable looking behind
			DisableControlAction(0, 73, true) -- Disable clearing animation
			DisableControlAction(2, 199, true) -- Disable pause screen

			DisableControlAction(0, 59, true) -- Disable steering in vehicle
			DisableControlAction(0, 71, true) -- Disable driving forward in vehicle
			DisableControlAction(0, 72, true) -- Disable reversing in vehicle

			DisableControlAction(2, 36, true) -- Disable going stealth

			DisableControlAction(0, 47, true)  -- Disable weapon
			DisableControlAction(0, 264, true) -- Disable melee
			DisableControlAction(0, 257, true) -- Disable melee
			DisableControlAction(0, 140, true) -- Disable melee
			DisableControlAction(0, 141, true) -- Disable melee
			DisableControlAction(0, 142, true) -- Disable melee
			DisableControlAction(0, 143, true) -- Disable melee
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle

			if IsEntityPlayingAnim(playerPed, 'mp_arresting', 'idle', 3) ~= 1 then
				ESX.Streaming.RequestAnimDict('mp_arresting', function()
					TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0.0, false, false, false)
				end)
			end
		else
			Citizen.Wait(500)
		end
	end
end)


function OpenBossMenu(society, close, options)
	local isBoss = nil
	local options  = options or {}
	local elements = {}
	
	ESX.TriggerServerCallback('fd_gangs:isBoss', function(result)
		isBoss = result
	end, society)

	while isBoss == nil do
		Citizen.Wait(100)
	end
	print(isBoss)
	if not isBoss then
		return
	end

	local defaultOptions = {
		withdraw  = true,
		deposit   = true,
		wash      = true,
		members = true,
		grades    = true
	}

	for k,v in pairs(defaultOptions) do
		if options[k] == nil then
			options[k] = v
		end
	end

	if options.withdraw then
		table.insert(elements, {label = _U('withdraw_society_money'), value = 'withdraw_society_money'})
	end

	if options.deposit then
		table.insert(elements, {label = _U('deposit_society_money'), value = 'deposit_money'})
	end

	if options.wash then
		table.insert(elements, {label = _U('wash_money'), value = 'wash_money'})
	end

	if options.members then
		table.insert(elements, {label = _U('member_management'), value = 'manage_employees'})
	end

	if options.grades then
		table.insert(elements, {label = _U('salary_management'), value = 'manage_grades'})
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'boss_actions_' .. society, {
		title    = _U('boss_menu'),
		align    = 'top-left',
		elements = elements
	}, function(data, menu)

		if data.current.value == 'withdraw_society_money' then

			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'withdraw_society_money_amount_' .. society, {
				title = _U('withdraw_amount')
			}, function(data, menu)

				local amount = tonumber(data.value)

				if amount == nil then
					ESX.ShowNotification(_U('invalid_amount'))
				else
					menu.close()
					TriggerServerEvent('esx_society:withdrawMoney', society, amount)
				end

			end, function(data, menu)
				menu.close()
			end)

		elseif data.current.value == 'deposit_money' then

			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'deposit_money_amount_' .. society, {
				title = _U('deposit_amount')
			}, function(data, menu)

				local amount = tonumber(data.value)

				if amount == nil then
					ESX.ShowNotification(_U('invalid_amount'))
				else
					menu.close()
					TriggerServerEvent('esx_society:depositMoney', society, amount)
				end

			end, function(data, menu)
				menu.close()
			end)

		elseif data.current.value == 'wash_money' then

			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'wash_money_amount_' .. society, {
				title = _U('wash_money_amount')
			}, function(data, menu)

				local amount = tonumber(data.value)

				if amount == nil then
					ESX.ShowNotification(_U('invalid_amount'))
				else
					menu.close()
					TriggerServerEvent('esx_society:washMoney', society, amount)
				end

			end, function(data, menu)
				menu.close()
			end)

		elseif data.current.value == 'manage_employees' then
			OpenManageEmployeesMenu(society)
		elseif data.current.value == 'manage_grades' then
			OpenManageGradesMenu(society)
		end

	end, function(data, menu)
		if close then
			close(data, menu)
		end
	end)

end

function OpenManageEmployeesMenu(society)

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'manage_employees_' .. society, {
		title    = _U('employee_management'),
		align    = 'top-left',
		elements = {
			{label = _U('employee_list'), value = 'employee_list'},
			{label = _U('recruit'),       value = 'recruit'}
		}
	}, function(data, menu)

		if data.current.value == 'employee_list' then
			OpenEmployeeList(society)
		end

		if data.current.value == 'recruit' then
			OpenRecruitMenu(society)
		end

	end, function(data, menu)
		menu.close()
	end)
end

function OpenEmployeeList(society)

	ESX.TriggerServerCallback('fd_gangs:getMembers', function(employees)

		local elements = {
			head = {_U('employee'), _U('grade'), _U('actions')},
			rows = {}
		}

		for i=1, #employees, 1 do
			local gradeLabel = (employees[i].gang == '' and employees[i].gang or employees[i].gang_grade)

			table.insert(elements.rows, {
				data = employees[i],
				cols = {
					employees[i].name,
					gradeLabel,
					'{{' .. _U('promote') .. '|promote}} {{' .. _U('fire') .. '|fire}}'
				}
			})
		end

		ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'employee_list_' .. society, elements, function(data, menu)
			local employee = data.data

			if data.value == 'promote' then
				menu.close()
				OpenPromoteMenu(society, employee)
			elseif data.value == 'fire' then
				ESX.ShowNotification(_U('you_have_fired', employee.name))

				ESX.TriggerServerCallback('fd_gangs:setGang', function()
					OpenEmployeeList(society)
				end, employee.identifier,nil, 0, 'fire')
			end
		end, function(data, menu)
			menu.close()
			OpenManageEmployeesMenu(society)
		end)

	end, society)

end

-- function OpenRecruitMenu(society)

-- 	ESX.TriggerServerCallback('fd_gangs:getOnlinePlayers', function(players)

-- 		local elements = {}

-- 		for i=1, #players, 1 do
-- 			if players[i].job.name ~= society then
-- 				table.insert(elements, {
-- 					label = players[i].name,
-- 					value = players[i].source,
-- 					name = players[i].name,
-- 					identifier = players[i].identifier
-- 				})
-- 			end
-- 		end

-- 		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'recruit_' .. society, {
-- 			title    = _U('recruiting'),
-- 			align    = 'top-left',
-- 			elements = elements
-- 		}, function(data, menu)

-- 			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'recruit_confirm_' .. society, {
-- 				title    = _U('do_you_want_to_recruit', data.current.name),
-- 				align    = 'top-left',
-- 				elements = {
-- 					{label = _U('no'),  value = 'no'},
-- 					{label = _U('yes'), value = 'yes'}
-- 				}
-- 			}, function(data2, menu2)
-- 				menu2.close()

-- 				if data2.current.value == 'yes' then
-- 					ESX.ShowNotification(_U('you_have_hired', data.current.name))

-- 					ESX.TriggerServerCallback('fd_gangs:setGang', function()
-- 						OpenRecruitMenu(society)
-- 					end, data.current.identifier, society, 0, 'hire')
-- 				end
-- 			end, function(data2, menu2)
-- 				menu2.close()
-- 			end)

-- 		end, function(data, menu)
-- 			menu.close()
-- 		end)

-- 	end)

-- end

-- function OpenPromoteMenu(society, employee)

-- 	ESX.TriggerServerCallback('fd_gangs:getGang', function(gang)

-- 		local elements = {}

-- 		for i=1, #gang.grades, 1 do
-- 			local gradeLabel = (gang.grades[i].label == '' and gang.label or gang.grades[i].label)

-- 			table.insert(elements, {
-- 				label = gradeLabel,
-- 				value = job.grades[i].grade,
-- 				selected = (employee.job.grade == job.grades[i].grade)
-- 			})
-- 		end

-- 		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'promote_employee_' .. society, {
-- 			title    = _U('promote_employee', employee.name),
-- 			align    = 'top-left',
-- 			elements = elements
-- 		}, function(data, menu)
-- 			menu.close()
-- 			ESX.ShowNotification(_U('you_have_promoted', employee.name, data.current.label))

-- 			ESX.TriggerServerCallback('fd_gangs:setGang', function()
-- 				OpenEmployeeList(society)
-- 			end, employee.identifier, society, data.current.value, 'promote')
-- 		end, function(data, menu)
-- 			menu.close()
-- 			OpenEmployeeList(society)
-- 		end)

-- 	end, society)

-- end

-- function OpenManageGradesMenu(society)

-- 	ESX.TriggerServerCallback('esx_society:getJob', function(job)

-- 		local elements = {}

-- 		for i=1, #job.grades, 1 do
-- 			local gradeLabel = (job.grades[i].label == '' and job.label or job.grades[i].label)

-- 			table.insert(elements, {
-- 				label = ('%s - <span style="color:green;">%s</span>'):format(gradeLabel, _U('money_generic', ESX.Math.GroupDigits(job.grades[i].salary))),
-- 				value = job.grades[i].grade
-- 			})
-- 		end

-- 		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'manage_grades_' .. society, {
-- 			title    = _U('salary_management'),
-- 			align    = 'top-left',
-- 			elements = elements
-- 		}, function(data, menu)

-- 			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'manage_grades_amount_' .. society, {
-- 				title = _U('salary_amount')
-- 			}, function(data2, menu2)

-- 				local amount = tonumber(data2.value)

-- 				if amount == nil then
-- 					ESX.ShowNotification(_U('invalid_amount'))
-- 				elseif amount > Config.MaxSalary then
-- 					ESX.ShowNotification(_U('invalid_amount_max'))
-- 				else
-- 					menu2.close()

-- 					ESX.TriggerServerCallback('fd_gangs:setGangSalary', function()
-- 						OpenManageGradesMenu(society)
-- 					end, society, data.current.value, amount)
-- 				end

-- 			end, function(data2, menu2)
-- 				menu2.close()
-- 			end)

-- 		end, function(data, menu)
-- 			menu.close()
-- 		end)

-- 	end, society)

-- end


--Key Controls
Citizen.CreateThread(function ()
    while true do
        Citizen.Wait(0)

        if IsControlJustReleased(0,167) and player.gang ~= nil and not ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'gang_actions') then
            OpenGangActionsMenu()
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