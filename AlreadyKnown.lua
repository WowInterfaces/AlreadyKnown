local ADDON_NAME = ...
local _G = _G
local knownTable = {
	-- ["|cffa335ee|Hitem:22450::::::::53:::::::::|h[Void Crystal]|h|r"] = true -- Debug (Void Crystal)
} -- Save known items for later use
local db
local questItems = { -- Quest items and matching quests
	-- WoD
	-- Equipment Blueprint: Tuskarr Fishing Net
	[128491] = 39359, -- Alliance
	[128251] = 39359, -- Horde
	-- Equipment Blueprint: Unsinkable
	[128250] = 39358, -- Alliance
	[128489] = 39358, -- Horde
	-- Shadowlands
	-- Soulshapes (Data by Dairyman @ Github)
	[181313] = 62420, -- Snapper Soul
	[181314] = 62421, -- Gulper Soul
	[182165] = 62422, -- Ardenmoth Soul
	[182166] = 62423, -- Ursine soul
	-- [182167] = 0, -- Cobra Sape
	[182168] = 62424, -- Crane Soul
	[182169] = 62425, -- Veilwing Soul
	[182170] = 62426, -- Gryphon Soul
	[182171] = 62427, -- Hippogryph Soul
	[182172] = 62428, -- Equine Soul
	-- [182173] = 0, -- Hyena Sape
	[182174] = 62429, -- Leonine Soul
	[182175] = 62430, -- Moose Soul
	[182176] = 62431, -- Shadowstalker Soul
	[182177] = 62432, -- Owlcat Soul
	[182178] = 62433, -- Raptor Soul
	[182179] = 62434, -- Runestag Soul
	[182180] = 62435, -- Stag Soul
	[182181] = 62437, -- Tiger soul
	[182182] = 62438, -- Lupine Soul
	[182183] = 62439, -- Wolfhawk Soul
	[182184] = 62440, -- Wyvern Soul
	[182185] = 62436, -- Shrieker Soul
}
local specialItems = { -- Items needing special treatment
	-- Krokul Flute -> Flight Master's Whistle
	[152964] = { 141605, 11, 269 } -- 269 for Flute applied Whistle, 257 (or anything else than 269) for pre-apply Whistle
}
local containerItems = { -- These items are containers containing items we might know already, but don't get any marking about us knowing the contents already
	[21740] = { -- Small Rocket Recipes
		21724, -- Schematic: Small Blue Rocket
		21725, -- Schematic: Small Green Rocket
		21726 -- Schematic: Small Red Rocket
	},
	[21741] = { -- Cluster Rocket Recipes
		21730, -- Schematic: Blue Rocket Cluster
		21731, -- Schematic: Green Rocket Cluster
		21732 -- Schematic: Red Rocket Cluster
	},
	[21742] = { -- Large Rocket Recipes
		21727, -- Schematic: Large Blue Rocket
		21728, -- Schematic: Large Green Rocket
		21729 -- Schematic: Large Red Rocket
	},
	[21743] = { -- Large Cluster Rocket Recipes
		21733, -- Schematic: Large Blue Rocket Cluster
		21734, -- Schematic: Large Green Rocket Cluster
		21735 -- Schematic: Large Red Rocket Cluster
	},
	[128319] = { -- Void-Shrouded Satchel
		128318 -- Touch of the Void
	}
}

local isClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC)
local isBCClassic = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			print("|cffffcc00".. ADDON_NAME ..":|r " .. format(text, ...))
		else
			print("|cffffcc00".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

-- Tooltip and scanning by Phanx @ http://www.wowinterface.com/forums/showthread.php?p=271406
-- Search string by Phanx @ https://github.com/Phanx/BetterBattlePetTooltip/blob/master/Addon.lua
local S_PET_KNOWN = strmatch(_G.ITEM_PET_KNOWN, "[^%(]+")

-- Construct your search patterns based on the existing global strings:
local S_ITEM_MIN_LEVEL = "^" .. gsub(_G.ITEM_MIN_LEVEL, "%%d", "(%%d+)")
local S_ITEM_CLASSES_ALLOWED = "^" .. gsub(_G.ITEM_CLASSES_ALLOWED, "%%s", "(%%a+)")

local scantip = CreateFrame("GameTooltip", "AKScanningTooltip", nil, "GameTooltipTemplate")
scantip:SetOwner(UIParent, "ANCHOR_NONE")

local function _checkIfKnown(itemLink)
	if knownTable[itemLink] then -- Check if we have scanned this item already and it was known then
		return true
	end

	local itemId = tonumber(itemLink:match("item:(%d+)"))
	--if itemId == 82800 then Print("itemLink:", gsub(itemLink, "\124", "\124\124")) end
	-- How to handle Pet Cages inside GBanks? They look like this and don't have any information about the pet inside:
	-- |cff0070dd|Hitem:82800::::::::120:269::::::|h[Pet Cage]|h|r
	if itemId and questItems[itemId] then -- Check if item is a quest item.
		if (isClassic and IsQuestFlaggedCompleted(questItems[itemId])) or ((not isClassic) and C_QuestLog.IsQuestFlaggedCompleted(questItems[itemId])) then -- Check if the quest for item is already done.
			if db.debug and not knownTable[itemLink] then Print("%d - QuestItem", itemId) end
			knownTable[itemLink] = true -- Mark as known for later use
			return true -- This quest item is already known
		end
		return false -- Quest item is uncollected... or something went wrong
	elseif itemId and specialItems[itemId] then -- Check if we need special handling, this is most likely going to break with then next item we add to this
		local specialData = specialItems[itemId]
		local _, specialLink = GetItemInfo(specialData[1])
		if specialLink then
			local specialTbl = { strsplit(":", specialLink) }
			local specialInfo = tonumber(specialTbl[specialData[2]])
			if specialInfo == specialData[3] then
				if db.debug and not knownTable[itemLink] then Print("%d, %d - SpecialItem", itemId, specialInfo) end
				knownTable[itemLink] = true -- Mark as known for later use
				return true -- This specialItem is already known
			end
		end
		return false -- Item is specialItem, but data isn't special
	elseif itemId and containerItems[itemId] then -- Check the known contents of the item
		local knownCount, totalCount = 0, 0
		for ci = 1, #containerItems[itemId] do
			totalCount = totalCount + 1
			local thisItem = _checkIfKnown(format("item:%d", containerItems[itemId][ci])) -- Checkception
			if thisItem then
				knownCount = knownCount + 1
			end
		end
		if db.debug and not knownTable[itemLink] then Print("%d (%d/%d) - ContainerItem", itemId, knownCount, totalCount) end
		return (knownCount == totalCount)
	end

	if not (isClassic or isBCClassic) then -- No Pet Journal in (BC)Classic
		if itemLink:match("|H(.-):") == "battlepet" then -- Check if item is Caged Battlepet (dummy item 82800)
			local _, battlepetId = strsplit(":", itemLink)
			if C_PetJournal.GetNumCollectedInfo(battlepetId) > 0 then
				if db.debug and not knownTable[itemLink] then Print("%d - BattlePet: %s %d", itemId, battlepetId, C_PetJournal.GetNumCollectedInfo(battlepetId)) end
				knownTable[itemLink] = true -- Mark as known for later use
				return true -- Battlepet is collected
			end
			return false -- Battlepet is uncollected... or something went wrong
		end
	end

	scantip:ClearLines()
	scantip:SetHyperlink(itemLink)

	--for i = 2, scantip:NumLines() do -- Line 1 is always the name so you can skip it.
	local lines = scantip:NumLines()
	local comboLevelClass = 0
	local comboLevelTemp = 0
	for i = 2, lines do -- Line 1 is always the name so you can skip it.
		local text = _G["AKScanningTooltipTextLeft"..i]:GetText()
		if text == _G.ITEM_SPELL_KNOWN or strmatch(text, S_PET_KNOWN) then
			if db.debug and not knownTable[itemLink] then Print("%d - Tip %d/%d: %s (%s / %s)", itemId, i, lines, tostring(text), text == _G.ITEM_SPELL_KNOWN and "true" or "false", strmatch(text, S_PET_KNOWN) and "true" or "false") end
			--knownTable[itemLink] = true -- Mark as known for later use
			--return true -- Item is known and collected
			if isClassic or isBCClassic then -- Fix for (BC)Classic, hope this covers all the cases.
				knownTable[itemLink] = true -- Mark as known for later use
				return true -- Item is known and collected
			elseif lines - i <= 3 then -- Mounts have Riding skill and Reputation requirements under Already Known -line
				knownTable[itemLink] = true -- Mark as known for later use
			end
		elseif strmatch(text, S_ITEM_MIN_LEVEL) then
			if db.debug and not knownTable[itemLink] then Print("%d - Level %d/%d", itemId, strmatch(text, S_ITEM_MIN_LEVEL), UnitLevel("player")) end
			-- We found "Requires Level %d" item-line
			local minLevel = tonumber(strmatch(text, S_ITEM_MIN_LEVEL))
				
			if minLevel > 0 and minLevel <= UnitLevel("player") then -- Check if we have at least the required minimum level to use the item and allowed class
				--knownTable[itemLink] = minLevel
				--return true
				comboLevelClass = comboLevelClass + 1
				comboLevelTemp = minLevel
			end
		elseif strmatch(text, S_ITEM_CLASSES_ALLOWED) then
			if db.debug and not knownTable[itemLink] then Print("%d - Classes %s/%s", itemId, strmatch(text, S_ITEM_CLASSES_ALLOWED), UnitClass("player")) end
			-- We found "Classes: %s" item-line
			local itemClassesAllowed = {}
			for k, v in pairs({ strsplit(",", strmatch(text, S_ITEM_CLASSES_ALLOWED)) }) do
				if v then
					itemClassesAllowed[strtrim(v)] = true
				end
			end

			if itemClassesAllowed[UnitClass("player")] then
				comboLevelClass = comboLevelClass + 1
			end
		elseif text == _G.TOY and _G["AKScanningTooltipTextLeft"..i + 2] and _G["AKScanningTooltipTextLeft"..i + 2]:GetText() == _G.ITEM_SPELL_KNOWN then
			-- Check if items is Toy already known
			if db.debug and not knownTable[itemLink] then Print("%d - Toy %d", itemId, i) end
			knownTable[itemLink] = true
		end
	end

	if comboLevelClass > 1 then
		if db.debug and not knownTable[itemLink] then Print("comboLevelClass %d for %d.", comboLevelClass, itemId) end
		-- We matched level requirements and allowed classes

		--knownTable[itemLink] = comboLevelTemp
	end

	--return false -- Item is not known, uncollected... or something went wrong
	return knownTable[itemLink] and true or false
end

local function _hookNewAH(self) -- Most of this found from FrameXML/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseItemList.lua
	if isClassic or isBCClassic then return end -- Only for Retail 8.3 and newer

	-- https://www.townlong-yak.com/framexml/9.0.2/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseItemList.lua#340
	local numResults = self.getNumEntries()

	local buttons = HybridScrollFrame_GetButtons(self.ScrollFrame)
	local buttonCount = buttons and #buttons or 0
	local offset = self:GetScrollOffset()
	local populateCount = math.min(buttonCount, numResults)
	for i = 1, buttonCount do
		local visible = i + offset <= numResults
		local button = buttons[i]
		if visible then
			if button.rowData.itemKey.itemID then
				local itemLink
				if button.rowData.itemKey.itemID == 82800 then -- BattlePet
					itemLink = format("|Hbattlepet:%d::::::|h[Dummy]|h", button.rowData.itemKey.battlePetSpeciesID)
				else -- Normal item
					itemLink = format("item:%d", button.rowData.itemKey.itemID)
				end

				if itemLink and _checkIfKnown(itemLink) then
					-- Highlight
					button.SelectedHighlight:Show()
					button.SelectedHighlight:SetVertexColor(db.r, db.g, db.b)
					button.SelectedHighlight:SetAlpha(.2)
					-- Icon
					button.cells[2].Icon:SetVertexColor(db.r, db.g, db.b)
					button.cells[2].IconBorder:SetVertexColor(db.r, db.g, db.b)
					button.cells[2].Icon:SetDesaturated(db.monochrome)
				else
					-- Highlight
					button.SelectedHighlight:SetVertexColor(1, 1, 1)
					-- Icon
					button.cells[2].Icon:SetVertexColor(1, 1, 1)
					button.cells[2].IconBorder:SetVertexColor(1, 1, 1)
					button.cells[2].Icon:SetDesaturated(false)
				end
			end
		end
	end
end

local function _hookAH() -- Most of this found from FrameXML/Blizzard_AuctionUI/Blizzard_AuctionUI.lua
	if not (isClassic or isBCClassic) then return end -- Retail 8.3 changed the AH, this old one is still used for (BC)Classic

	-- https://www.townlong-yak.com/framexml/8.2.5/Blizzard_AuctionUI/Blizzard_AuctionUI.lua#763
	local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame)

	for i=1, _G.NUM_BROWSE_TO_DISPLAY do
		if (_G["BrowseButton"..i.."Item"] and _G["BrowseButton"..i.."ItemIconTexture"]) or _G["BrowseButton"..i].id then -- Something to do with ARL?
			local itemLink
			if _G["BrowseButton"..i].id then
				itemLink = GetAuctionItemLink('list', _G["BrowseButton"..i].id)
			else
				itemLink = GetAuctionItemLink('list', offset + i)
			end

			if itemLink and _checkIfKnown(itemLink) then
				if _G["BrowseButton"..i].id then
					_G["BrowseButton"..i].Icon:SetVertexColor(db.r, db.g, db.b)
				else
					_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(db.r, db.g, db.b)
				end

				if db.monochrome then
					if _G["BrowseButton"..i].id then
						_G["BrowseButton"..i].Icon:SetDesaturated(true)
					else
						_G["BrowseButton"..i.."ItemIconTexture"]:SetDesaturated(true)
					end
				end
			else
				if _G["BrowseButton"..i].id then
					_G["BrowseButton"..i].Icon:SetVertexColor(1, 1, 1)
					_G["BrowseButton"..i].Icon:SetDesaturated(false)
				else
					_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(1, 1, 1)
					_G["BrowseButton"..i.."ItemIconTexture"]:SetDesaturated(false)
				end
			end
		end
	end
end

local function _hookMerchant() -- Most of this found from FrameXML/MerchantFrame.lua
	-- https://www.townlong-yak.com/framexml/9.0.2/MerchantFrame.lua#197
	for i = 1, _G.MERCHANT_ITEMS_PER_PAGE do
		local index = (((MerchantFrame.page - 1) * _G.MERCHANT_ITEMS_PER_PAGE) + i)
		local itemButton = _G["MerchantItem"..i.."ItemButton"]
		local merchantButton = _G["MerchantItem"..i]
		local itemLink = GetMerchantItemLink(index)

		if itemLink and _checkIfKnown(itemLink) then
			SetItemButtonNameFrameVertexColor(merchantButton, db.r, db.g, db.b)
			SetItemButtonSlotVertexColor(merchantButton, db.r, db.g, db.b)
			SetItemButtonTextureVertexColor(itemButton, 0.9*db.r, 0.9*db.g, 0.9*db.b)
			SetItemButtonNormalTextureVertexColor(itemButton, 0.9*db.r, 0.9*db.g, 0.9*db.b)

			if db.monochrome then
				_G["MerchantItem"..i.."ItemButtonIconTexture"]:SetDesaturated(true)
			end
		else
			_G["MerchantItem"..i.."ItemButtonIconTexture"]:SetDesaturated(false)
		end
	end
end

local AK_SLOTS_PER_TAB = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98 -- These ain't Globals anymore in the new Mixin version so fallback for hardcoded version
local AK_SLOTS_PER_GROUP = _G.NUM_SLOTS_PER_GUILDBANK_GROUP or 14
local function _hookGBank() -- FrameXML/Blizzard_GuildBankUI/Blizzard_GuildBankUI.lua
	-- https://www.townlong-yak.com/framexml/9.0.2/Blizzard_GuildBankUI/Blizzard_GuildBankUI.lua#203 -- Old version (Classic and pre-9.1.5)
	-- https://www.townlong-yak.com/framexml/9.1.5/Blizzard_GuildBankUI/Blizzard_GuildBankUI.lua#135 -- New Mixin-version (BCClassic and 9.1.5 ->)
	local tab = GetCurrentGuildBankTab()
	for i = 1, AK_SLOTS_PER_TAB do
		local index = mod(i, AK_SLOTS_PER_GROUP)
		if (index == 0) then
			index = AK_SLOTS_PER_GROUP
		end
		local column = math.ceil((i - .5) / AK_SLOTS_PER_GROUP)
		local button
		if GuildBankFrameMixin then
			button = GuildBankFrame.Columns[column].Buttons[index] -- New Mixin-version
		else
			button = _G["GuildBankColumn" .. column .. "Button" .. index] -- Old Classic/Pre-9.1.5 -version
		end
		--local texture = GetGuildBankItemInfo(tab, i)
		local itemLink = GetGuildBankItemLink(tab, i)

		--if texture and texture == 132599 then -- Inv_box_petcarrier_01 (BattlePet, itemId 82800)
		if itemLink and itemLink:match("item:82800") then -- Check if item is Caged Battlepet (dummy item 82800)
			-- Combining the Hook New AH -way and suggestion made by Dairyman @ Github to improve the detection of caged battlepets in GBank
			scantip:ClearLines()
			local speciesId = scantip:SetGuildBankItem(tab, i)

			if speciesId and speciesId > 0 then
				itemLink = format("|Hbattlepet:%d::::::|h[Dummy]|h", speciesId)
			end
		end

		if itemLink and _checkIfKnown(itemLink) then
			SetItemButtonTextureVertexColor(button, 0.9*db.r, 0.9*db.g, 0.9*db.b)
			if GuildBankFrameMixin then -- Mixin version doesn't have names for the buttons and SetItemButtonNormalTextureVertexColor requires buttons to have names to work
				button:GetNormalTexture():SetVertexColor(0.9*db.r, 0.9*db.g, 0.9*db.b)
			else
				SetItemButtonNormalTextureVertexColor(button, 0.9*db.r, 0.9*db.g, 0.9*db.b)
			end

			SetItemButtonDesaturated(button, db.monochrome)
		else
			SetItemButtonTextureVertexColor(button, 1, 1, 1)
			if GuildBankFrameMixin then
				button:GetNormalTexture():SetVertexColor(1, 1, 1)
			else
				SetItemButtonNormalTextureVertexColor(button, 1, 1, 1)
			end

			SetItemButtonDesaturated(button, false)
		end
	end
end

local alreadyHookedAddOns = {
	[ADDON_NAME] = false,
	["Blizzard_AuctionUI"] = false, -- => 8.2.5
	["Blizzard_AuctionHouseUI"] = false, -- 8.3 =>
	["Blizzard_GuildBankUI"] = false -- 2.3 =>
}
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and alreadyHookedAddOns[(...)] == false then
		local addOnName = ...
		if addOnName == "Blizzard_AuctionHouseUI" then -- New AH
			hooksecurefunc(AuctionHouseFrame.BrowseResultsFrame.ItemList, "RefreshScrollFrame", _hookNewAH)
			alreadyHookedAddOns["Blizzard_AuctionHouseUI"] = true

		elseif addOnName == "Blizzard_AuctionUI" then -- Old AH
			if IsAddOnLoaded("Auc-Advanced") and _G.AucAdvanced.Settings.GetSetting("util.compactui.activated") then
				hooksecurefunc("GetNumAuctionItems", _hookAH)
			else
				hooksecurefunc("AuctionFrameBrowse_Update", _hookAH)
			end
			alreadyHookedAddOns["Blizzard_AuctionUI"] = true

		elseif addOnName == "Blizzard_GuildBankUI" then -- GBank
			if GuildBankFrameMixin then -- New Mixin-version for BCClassic/9.1.5 =>
				hooksecurefunc(GuildBankFrame, "Update", _hookGBank) -- GuildBankFrameMixin:Update()
			else -- Classic/Pre-9.1.5 version not using the Mixin
				hooksecurefunc("GuildBankFrame_Update", _hookGBank) -- Old pre-9.1.5 -version
			end
			alreadyHookedAddOns["Blizzard_GuildBankUI"] = true

		elseif addOnName == ADDON_NAME then -- Self
			if type(AlreadyKnownSettings) ~= "table" then
				AlreadyKnownSettings = { r = 0, g = 1, b = 0, monochrome = false }
			end
			db = AlreadyKnownSettings

			if isClassic or isBCClassic then -- These weren't/aren't in the Classic
				alreadyHookedAddOns["Blizzard_AuctionHouseUI"] = nil
				if not isBCClassic then -- GuildBank should be in BCClassic (at least in the end of TBC it was)
					alreadyHookedAddOns["Blizzard_GuildBankUI"] = nil
				end
			else -- These aren't in the Retail anymore
				alreadyHookedAddOns["Blizzard_AuctionUI"] = nil
			end

			hooksecurefunc("MerchantFrame_UpdateMerchantInfo", _hookMerchant)

			self:RegisterEvent("PLAYER_LEVEL_UP")
		end
		alreadyHookedAddOns[addOnName] = true -- Mark addOnName as hooked

		local everythingHooked = true
		for _, hooked in pairs(alreadyHookedAddOns) do -- Check if everything is hooked already
			if not hooked then -- Something isn't hooked yet, keep on listening
				everythingHooked = false 
				break
			end
		end
		if everythingHooked then -- No need to listen to the event anymore
			if db.debug then Print("UnregisterEvent", event) end
			self:UnregisterEvent(event)
		end
		if db.debug then Print("ADDON_LOADED:", alreadyHookedAddOns[ADDON_NAME], alreadyHookedAddOns["Blizzard_AuctionHouseUI"], alreadyHookedAddOns["Blizzard_AuctionUI"], alreadyHookedAddOns["Blizzard_GuildBankUI"]) end

	elseif event == "PLAYER_LEVEL_UP" then -- Player leveled up
		local newLevel = ...

		for itemLink, minLevel in pairs(knownTable) do -- Check the saved itemLinks for items we can use now
			if type(minLevel) == "number" and minLevel <= newLevel then -- We can use this item now, so we take it out of the list
				knownTable[itemLink] = nil
			end
		end
	end
end)

local function _RGBToHex(r, g, b)
	r = r <= 255 and r >= 0 and r or 0
	g = g <= 255 and g >= 0 and g or 0
	b = b <= 255 and b >= 0 and b or 0
	return format("%02x%02x%02x", r, g, b)
end

local function _changedCallback(restore)
	local R, G, B
	if restore then -- The user bailed, we extract the old color from the table created by ShowColorPicker.
		R, G, B = unpack(restore)
	else -- Something changed
		R, G, B = ColorPickerFrame:GetColorRGB()
	end

	db.r, db.g, db.b = R, G, B
	Print("|cff%scustom|r, Monochrome: %s", _RGBToHex(db.r*255, db.g*255, db.b*255), (db.monochrome and "|cff00ff00true|r" or "|cffff0000false|r"))
end

local function _ShowColorPicker(r, g, b, a, changedCallback)
	ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = false, 1
	ColorPickerFrame.previousValues = { r, g, b }
	ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changedCallback, changedCallback, changedCallback
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Hide() -- Need to run the OnShow handler.
	ColorPickerFrame:Show()
end

SLASH_ALREADYKNOWN1 = "/alreadyknown"
SLASH_ALREADYKNOWN2 = "/ak"

SlashCmdList.ALREADYKNOWN = function(...)
	if (...) == "green" then
		db.r = 0; db.g = 1; db.b = 0
	elseif (...) == "blue" then
		db.r = 0; db.g = 0; db.b = 1
	elseif (...) == "yellow" then
		db.r = 1; db.g = 1; db.b = 0
	elseif (...) == "cyan" then
		db.r = 0; db.g = 1; db.b = 1
	elseif (...) == "purple" then
		db.r = 1; db.g = 0; db.b = 1
	elseif (...) == "gray" then
		db.r = 0.5; db.g = 0.5; db.b = 0.5
	elseif (...) == "custom" then
		_ShowColorPicker(db.r, db.g, db.b, false, _changedCallback)
	elseif (...) == "monochrome" then
		db.monochrome = not db.monochrome
		Print("Monochrome: %s", (db.monochrome and "|cff00ff00true|r" or "|cffff0000false|r"))
	elseif (...) == "debug" then
		db.debug = not db.debug
		if db.debug then wipe(knownTable) end
		Print("Debug: %s", (db.debug and "|cff00ff00true|r" or "|cffff0000false|r"))
	else
		Print("/alreadyknown ( green | blue | yellow | cyan | purple | gray | custom | monochrome )")
	end

	if (...) ~= "" and (...) ~= "custom" and (...) ~= "monochrome" and (...) ~= "debug" then
		Print("|cff%s%s|r, Monochrome: %s", _RGBToHex(db.r*255, db.g*255, db.b*255), (...), (db.monochrome and "|cff00ff00true|r" or "|cffff0000false|r"))
		if db.debug then Print("Debug: |cff00ff00true|r") end
	end

	if ColorPickerFrame:IsShown() and (...) ~= "custom" then
		_ShowColorPicker(db.r, db.g, db.b, false, _changedCallback)
	end
end