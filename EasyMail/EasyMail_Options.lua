
---------------------------------------------------
-- Global vars
---------------------------------------------------
EasyMail.clearAll = false;

---------------------------------------------------
-- Local vars
---------------------------------------------------
local curPlayer = "";
local curRealm = "";
local curFaction = "";

local EasyMail_Defaults =
{
	MailListLen = 15,
	AutoAdd = "N",
	Guild = "N",
	Friends = "N",
	Inclusive = "N",
	BlizzList = "N",
	HideDrop = "N",
	OpenAll = "N",
	ClickGet = "N",
	ClickDel = "N",
	DelPending = "N",
	Money = "Y",
	Total = "Y",
	TextTooltip = "N",
	DelPrompt = "Y",
-- Lemmoros Move History Frame
	MoveHFrame = "Y",
-- Lemmoros Move History Frame end
	HistLen = 100
}

-- Durability status warning dialog
StaticPopupDialogs["EASYMAIL_LENGTHWARNING"] = {
	text = "",
	button1 = OKAY,
	timeout = 0,
	showAlert = 1,
	whileDead = 1,
	exclusive = 1,
	hideOnEscape = 1
};

---------------------------------------------------
-- EasyMail.SetupOptions
---------------------------------------------------
function EasyMail.SetupOptions()
  curPlayer = UnitName("player");
  curRealm = GetRealmName();
	curFaction = UnitFactionGroup("player");
  
  -- Setup saved variables
  if (not EasyMail_SavedVars[curRealm]) then
    -- Separate saved variable sets for each realm
    EasyMail_SavedVars[curRealm] = {};
  end
  if (not EasyMail_SavedVars[curRealm][curFaction]) then
    -- Separate saved variable sets for each faction
    EasyMail_SavedVars[curRealm][curFaction] = {};
  end
  if (not EasyMail_SavedVars[curRealm][curFaction].EasyMailList) then
    -- List of all addresses mailed to recently
    EasyMail_SavedVars[curRealm][curFaction].EasyMailList = {};
  end
  if (not EasyMail_SavedVars[curRealm][curFaction].LastAddressee) then
    -- List of last addressee each character mailed to
    EasyMail_SavedVars[curRealm][curFaction].LastAddressee = {};
  end
  if (not EasyMail_SavedVars[curRealm][curFaction].LastAddressee[curPlayer]) then
    -- Set the default last addressee for this player to empty string
    EasyMail_SavedVars[curRealm][curFaction].LastAddressee[curPlayer] = "";
  end
  if (not EasyMail_SavedVars[curRealm][curFaction].MailListLen) then
    EasyMail_SavedVars[curRealm][curFaction].MailListLen = EasyMail_Defaults.MailListLen;
  end

  -- check all options
  for k,v in pairs(EasyMail_Defaults) do
    if (k ~= "MailListLen" and EasyMail_SavedVars[k] == nil) then
      EasyMail_SavedVars[k] = EasyMail_Defaults[k];
    end
  end
  
	--EasyMail.OptionsRefresh();
	--InterfaceOptionsFrameOkay:SetScript("OnClick", EasyMail.InterfaceOptionsFrameOkayOnClick);
end


---------------------------------------------------
-- EasyMail.SetDefaults
---------------------------------------------------
function EasyMail.SetDefaults()
	EasyMail_SavedVars[curRealm][curFaction].LastAddressee = {};
	EasyMail_SavedVars[curRealm][curFaction].MailListLen = EasyMail_Defaults.MailListLen;
	EasyMail_SavedVars.AutoAdd = EasyMail_Defaults.AutoAdd;
	EasyMail_SavedVars.Guild = EasyMail_Defaults.Guild;
	EasyMail_SavedVars.Friends = EasyMail_Defaults.Friends;
	EasyMail_SavedVars.Inclusive = EasyMail_Defaults.Inclusive;
	EasyMail_SavedVars.BlizzList = EasyMail_Defaults.BlizzList;
	EasyMail_SavedVars.HideDrop = EasyMail_Defaults.HideDrop;
	EasyMail_SavedVars.OpenAll = EasyMail_Defaults.OpenAll;
	EasyMail_SavedVars.ClickGet = EasyMail_Defaults.ClickGet;
	EasyMail_SavedVars.ClickDel = EasyMail_Defaults.ClickDel;
	EasyMail_SavedVars.DelPending = EasyMail_Defaults.DelPending;
	EasyMail_SavedVars.Money = EasyMail_Defaults.Money;
	EasyMail_SavedVars.Total = EasyMail_Defaults.Total;
	EasyMail_SavedVars.TextTooltip = EasyMail_Defaults.TextTooltip;
	EasyMail_SavedVars.DelPrompt = EasyMail_Defaults.DelPrompt;
-- Lemmoros Move History Frame
	EasyMail_SavedVars.MoveHFrame = EasyMail_Defaults.MoveHFrame;
-- Lemmoros Move History Frame end
	EasyMail_SavedVars.HistLen = EasyMail_Defaults.HistLen;
end


---------------------------------------------------
-- EasyMail.OptionsDefault
---------------------------------------------------
function EasyMail.OptionsDefault()
	EasyMail.SetDefaults();
	--EasyMail.clearAll = true;
  	EasyMail.OptionsRefresh()
	EasyMail.UpdateInterface();
end


---------------------------------------------------
-- EasyMail.OptionsRefresh
---------------------------------------------------
function EasyMail.OptionsRefresh(self)
	EasyMail_OptionsPanelAutoAdd:SetChecked(EasyMail_SavedVars.AutoAdd == "Y");
	EasyMail_OptionsPanelListLen:SetNumber(EasyMail_SavedVars[curRealm][curFaction].MailListLen);
	EasyMail_OptionsPanelListLen:SetCursorPosition(0);
	EasyMail_OptionsPanelFriends:SetChecked(EasyMail_SavedVars.Friends == "Y");
	EasyMail_OptionsPanelGuild:SetChecked(EasyMail_SavedVars.Guild == "Y");
	EasyMail_OptionsPanelInclusive:SetChecked(EasyMail_SavedVars.Inclusive == "Y");
	EasyMail_OptionsPanelBlizzList:SetChecked(EasyMail_SavedVars.BlizzList == "Y");
	EasyMail_OptionsPanelHideDrop:SetChecked(EasyMail_SavedVars.HideDrop == "Y");
	EasyMail_OptionsPanelOpenAll:SetChecked(EasyMail_SavedVars.OpenAll == "Y");
	EasyMail_OptionsPanelClickGet:SetChecked(EasyMail_SavedVars.ClickGet == "Y");
	EasyMail_OptionsPanelClickDel:SetChecked(EasyMail_SavedVars.ClickDel == "Y");
	EasyMail_OptionsPanelDelPending:SetChecked(EasyMail_SavedVars.DelPending == "Y");
	EasyMail_OptionsPanelMoney:SetChecked(EasyMail_SavedVars.Money == "Y");
	EasyMail_OptionsPanelTotal:SetChecked(EasyMail_SavedVars.Total == "Y");
	EasyMail_OptionsPanelTextTooltip:SetChecked(EasyMail_SavedVars.TextTooltip == "Y");
	EasyMail_OptionsPanelDelPrompt:SetChecked(EasyMail_SavedVars.DelPrompt == "Y");
-- Lemmoros Move History Frame
	EasyMail_OptionsPanel_L_MoveHistory:SetChecked(EasyMail_SavedVars.MoveHFrame == "Y");
-- Lemmoros Move History Frame end
	EasyMail_OptionsPanelHistLen:SetNumber(EasyMail_SavedVars.HistLen);

	EasyMail_OptionsPanelHistLen:SetCursorPosition(0)
end


---------------------------------------------------
-- EasyMail.InterfaceOptionsFrameOkayOnClick
---------------------------------------------------
--[[function EasyMail.InterfaceOptionsFrameOkayOnClick(self, button, isApply)
	-- Check for valid entries
	local listlen = EasyMail_OptionsPanelListLen:GetNumber();

	if (listlen < EasyMail.minListLen or listlen > EasyMail.maxListLen) then
		StaticPopupDialogs["EASYMAIL_LENGTHWARNING"].text 
			= format(EASYMAIL_ERROUTOFRANGE, EasyMail.minListLen, EasyMail.maxListLen);
		StaticPopup_Show("EASYMAIL_LENGTHWARNING");
		EasyMail_OptionsPanelListLen:SetFocus();
		return;
	end
	
	InterfaceOptionsFrameOkay_OnClick(self, button, isApply);
end]]--


---------------------------------------------------
-- EasyMail.OptionsOkay
---------------------------------------------------
function EasyMail.OptionsOkay()
  local listlen = EasyMail_OptionsPanelListLen:GetNumber()
  
  if (listlen < EasyMail.minListLen) then
    listlen = EasyMail.minListLen
  end
  
  if (listlen > EasyMail.maxListLen) then
    listlen = EasyMail.maxListLen
  end
  
  local histlen = EasyMail_OptionsPanelHistLen:GetNumber()

  if (histlen < 0) then
	histlen = 0
  end

	EasyMail_SavedVars.AutoAdd = ((EasyMail_OptionsPanelAutoAdd:GetChecked() and "Y") or "N");
	EasyMail_SavedVars[curRealm][curFaction].MailListLen = listlen;
	EasyMail_SavedVars.Guild = ((EasyMail_OptionsPanelGuild:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.Friends = ((EasyMail_OptionsPanelFriends:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.Inclusive = ((EasyMail_OptionsPanelInclusive:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.BlizzList = ((EasyMail_OptionsPanelBlizzList:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.HideDrop = ((EasyMail_OptionsPanelHideDrop:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.OpenAll = ((EasyMail_OptionsPanelOpenAll:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.ClickGet = ((EasyMail_OptionsPanelClickGet:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.ClickDel = ((EasyMail_OptionsPanelClickDel:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.DelPending = ((EasyMail_OptionsPanelDelPending:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.Money = ((EasyMail_OptionsPanelMoney:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.Total = ((EasyMail_OptionsPanelTotal:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.TextTooltip = ((EasyMail_OptionsPanelTextTooltip:GetChecked() and "Y") or "N");
	EasyMail_SavedVars.DelPrompt = ((EasyMail_OptionsPanelDelPrompt:GetChecked() and "Y") or "N");
-- Lemmoros Move History Frame
	EasyMail_SavedVars.MoveHFrame = ((EasyMail_OptionsPanel_L_MoveHistory:GetChecked() and "Y") or "N");
-- Lemmoros Move History Frame end
	EasyMail_SavedVars.HistLen = histlen
	
	EasyMail.UpdateInterface();
end


---------------------------------------------------
-- EasyMail.UpdateInterface
---------------------------------------------------
function EasyMail.UpdateInterface()
	if (EasyMail.clearAll) then
		EasyMail_SavedVars[curRealm][curFaction].EasyMailList = {};
		EasyMail.clearAll = false;
	else
		local newLen = EasyMail_SavedVars[curRealm][curFaction].MailListLen;
		
		if (newLen < #EasyMail_SavedVars[curRealm][curFaction].EasyMailList) then
			-- Remove oldest entries on list when the list is longer than the new length
			for i = 1, #EasyMail_SavedVars[curRealm][curFaction].EasyMailList - newLen do
				tremove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, 1)
			end
		end
	end
	
	if (EasyMail_SavedVars.AutoAdd == "Y") then
		EasyMail.SaveAddressee(UnitName("player"), true);
	end;
	
	if (IsInGuild() and EasyMail_SavedVars.Guild == "Y") then
		TimeSinceLastGuildQuery = 3;
		GuildQueryInterval = .5;
	end

	if (EasyMail_SavedVars.Friend == "Y") then
		TimeSinceLastFriendQuery = 3;
		FriendQueryInterval = .5;
	end
	
	EasyMail.HideDropdown(EasyMail_SavedVars.HideDrop == "Y");
	EasyMail.HideOpenAllButton(EasyMail_SavedVars.OpenAll ~= "Y");
-- Lemmoros Move History Frame
	EASYMAIL_L_ToggleMoveWindows(EasyMail_SavedVars.MoveHFrame == "Y");
-- Lemmoros Move History Frame end
	EasyMail.SortList();

	EasyMail.TruncateHistory(EasyMail_SavedVars.HistLen)
end
