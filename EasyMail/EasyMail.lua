--[[

EasyMail

Mail frame mod that remembers last mail addressee for each character and allows the user to select addressee from 
a list of recently mailed players. Also allows the user to automatically take all attachments from an open mail or
get all attachments from all selected mails.

]]--
 
---------------------------------------------------
-- Global vars
---------------------------------------------------
EasyMail = {};

EASYMAIL_ADDONNAME = "EasyMail";

-- wow version
EasyMail.isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC);
EasyMail.isMists = (WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC);
EasyMail.isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE);

-- List length default and constraints
EasyMail.minListLen = 8;
EasyMail.maxListLen = 40;

EasyMail.curListMaxLen = 15;
EasyMail.buttonHeight = 16;

-- Default addressee width
EasyMail.addrWidth = 0;

-- Clear list dialog
StaticPopupDialogs["EASYMAIL_CLEARLIST"] = {
    text = EASYMAIL_CLEARQUESTION,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        EasyMail.ClearList();
    end,
    timeout = 0,
    showAlert = 1,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["EASYMAIL_DELETENAME"] = {
    text = "temp",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        EasyMail.DeleteName();
    end,
    timeout = 0,
    showAlert = 1,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["EASYMAIL_DELETEMAIL"] = {
    text = EASYMAIL_DELETEQUESTION,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        EasyMail.ClickDelete();
    end,
    timeout = 0,
    showAlert = 1,
    exclusive = 1,
    hideOnEscape = 1
};

-- Add Name dialog
StaticPopupDialogs["EASYMAIL_ADDNAME"] = {
    text = EASYMAIL_ADDNAMETEXT,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 12,
    OnAccept = function(self)
        local text = self:GetEditBox():GetText();
        EasyMail.SaveAddressee(text, 2);
    end,
    EditBoxOnEnterPressed = function(self)
        local text = self:GetText();
        EasyMail.SaveAddressee(text, 2);
        self:GetParent():Hide();
    end,
    OnShow = function(self)
        self:GetEditBox():SetFocus();
    end,
    OnHide = function(self)
        ChatEdit_FocusActiveWindow();
        self:GetEditBox():SetText("");
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["EASYMAIL_ADDNAMEMSG"] = {
    text = "temp",
    button1 = OKAY,
    button2 = nil,
    timeout = 0,
    OnAccept = function()
    end,
    OnCancel = function()
    end,
    whileDead = 1,
    hideOnEscape = 1
};

-- Set up saved variables
EasyMail_SavedVars = {};
-- Create message history saved variable (Lemmoros)
EasyMail_Maillog = {};
-- Lemmoros end
---------------------------------------------------
-- Local vars
---------------------------------------------------

-- Holds the current text from the addressee field as the user types it
local currentAddressee = "";

-- Holds the sorted recently-mailed list
local sortedList = {};

local dropdownTimer = 0;
local isDropdownCounting = false;

-- Holds the complete dropdown list
local fullList = {};
local menuResized = false;

local curPlayer = "";
local curRealm = "";
local curFaction = "";

-- Name to delete from the addressee list
local nameToDel = "";

-- Take all attachments variables
local gettingAtt = false;
local attIndex = 0;
local timeSinceLastAtt = 0;
local attInterval = .5;
local attTimeout = 10;
local attTimer = 0;
local curAtt = nil;

-- Checkbox table
local checkBoxes = {};
-- local CheckAll = true;
-- local CheckPage = true;

-- Get all mail attachment variables
local gettingAll = false;
local curMail = nil;
local deleteCount = 0;

-- Save settings of default inbox
local mailItemX, mailItemY, expireTimeX, expireTimeY, mailItemWidth, subjectWidth;
local inboxTitleText = InboxTitleText;

-- Guild and friends variables
local timeSinceLastGuildQuery = 0;
local guildQueryInterval = 3;
local timeSinceLastFriendQuery = 0;
local friendQueryInterval = 3;
local guildList = {};
local friendList = {};
local topButtonLoc = nil;

-- Mail to delete through right-click
local deleteMail = 0;

local moneySubject = false;
local totalMoney = 0;

local maxTooltipWidth = 40;

-- Money constants
local easyMail_Copper = "";
local easyMail_Silver = "";
local easyMail_Gold = "";

local sendingMail = false;

local mailBoxFull = false;

local function RemoveSpaces(str)
    return gsub(str, " ", "");
end

-- history frames (Lemmoros)
EASYMAIL_L_Sowframe_HistoryFrame = CreateFrame("Frame", "EASYMAIL_L_Sowframeort-Frame", UIParent,
    BackdropTemplateMixin and "BackdropTemplate")
EASYMAIL_L_Sowframe_HistoryFrame:SetPoint("CENTER", 0, 0);
EASYMAIL_L_Sowframe_HistoryFrame:SetWidth(450);
EASYMAIL_L_Sowframe_HistoryFrame:SetHeight(535);
EASYMAIL_L_Sowframe_HistoryFrame:SetFrameStrata("DIALOG")
EASYMAIL_L_Sowframe_HistoryFrame:SetBackdrop({
    bgFile = "Interface/AddOns/EasyMail/Images/back.tga",
    tile = false
})

EASYMAIL_L_Sowframe_HistoryFrame:Hide()

local EASYMAIL_L_Sowframe_HistoryFrameboxTitle = EASYMAIL_L_Sowframe_HistoryFrame:CreateFontString(nil, "OVERLAY",
    "GameFontNormalHuge")
EASYMAIL_L_Sowframe_HistoryFrameboxTitle:SetPoint("TOP", 0, -15)
EASYMAIL_L_Sowframe_HistoryFrameboxTitle:SetSize(400, 40)
EASYMAIL_L_Sowframe_HistoryFrameboxTitle:SetTextColor(0.5, 0.3, 0.1, 1)
EASYMAIL_L_Sowframe_HistoryFrameboxTitle:SetText(EASYMAIL_L_HistoryTitle)
-- EASYMAIL_L_Sowframe_HistoryFrameboxTitle:Show()

local EASYMAIL_L_SowframeCloseButton =
    CreateFrame("Button", nil, EASYMAIL_L_Sowframe_HistoryFrame, "UIPanelCloseButton")
EASYMAIL_L_SowframeCloseButton = EASYMAIL_L_SowframeCloseButton
if (EasyMail.isRetail) then
    EASYMAIL_L_SowframeCloseButton:SetSize(24, 24)
    EASYMAIL_L_SowframeCloseButton:SetPoint("TOPRIGHT", -5, -5)
else
    EASYMAIL_L_SowframeCloseButton:SetSize(32, 32)
    EASYMAIL_L_SowframeCloseButton:SetPoint("TOPRIGHT", 0, 2)
end
EASYMAIL_L_SowframeCloseButton:SetScript("OnClick", function()
    EASYMAIL_L_Sowframe_HistoryFrame:Hide()
end)

local EASYMAIL_L_Sowframe_scrollFrame = CreateFrame("ScrollFrame", nil, EASYMAIL_L_Sowframe_HistoryFrame,
    "UIPanelScrollFrameTemplate")
EASYMAIL_L_Sowframe_scrollFrame:SetPoint("TOP", -10, -70)
EASYMAIL_L_Sowframe_scrollFrame:SetSize(370, 430)
EASYMAIL_L_Sowframe_scrollFrame:Show()

local EASYMAIL_L_Sowframe_resultframe = CreateFrame("EditBox", nil, EASYMAIL_L_Sowframe_scrollFrame)
EASYMAIL_L_Sowframe_resultframe:SetPoint("CENTER", 0, 0)
EASYMAIL_L_Sowframe_resultframe:SetSize(370, 430)
EASYMAIL_L_Sowframe_resultframe:SetText("")
EASYMAIL_L_Sowframe_resultframe:SetFont("Fonts\\ARIALN.TTF", 15, "")
EASYMAIL_L_Sowframe_resultframe:SetAutoFocus(false)
EASYMAIL_L_Sowframe_resultframe:SetMultiLine(true)
EASYMAIL_L_Sowframe_resultframe:SetScript("OnEscapePressed", function()
    EASYMAIL_L_Sowframe_HistoryFrame:Hide()
end)
EASYMAIL_L_Sowframe_resultframe:Show()

EASYMAIL_L_Sowframe_scrollFrame:SetScrollChild(EASYMAIL_L_Sowframe_resultframe)
EASYMAIL_L_Sowframe_HistoryFrame:EnableMouse(true)
EASYMAIL_L_Sowframe_HistoryFrame:EnableKeyboard(true)

-- make movable

function EASYMAIL_L_ToggleMoveWindows(switch)
    if switch then
        EASYMAIL_L_Sowframe_HistoryFrame:SetMovable(true)
        EASYMAIL_L_Sowframe_HistoryFrame:RegisterForDrag("LeftButton")
        EASYMAIL_L_Sowframe_HistoryFrame:SetScript("OnDragStart", EASYMAIL_L_Sowframe_HistoryFrame.StartMoving)
        EASYMAIL_L_Sowframe_HistoryFrame:SetScript("OnDragStop", EASYMAIL_L_Sowframe_HistoryFrame.StopMovingOrSizing)
    else
        EASYMAIL_L_Sowframe_HistoryFrame:SetMovable(false)
        EASYMAIL_L_Sowframe_HistoryFrame:RegisterForDrag()
        EASYMAIL_L_Sowframe_HistoryFrame:SetScript("OnDragStart", nil)
        EASYMAIL_L_Sowframe_HistoryFrame:SetScript("OnDragStop", nil)
    end
end

-- EASYMAIL_L_ToggleMoveWindows(true)

-- end History frames (Lemmoros)

---------------------------------------------------
-- EasyMail.OnLoad
-- Register events when the addon is loaded - Frame: EasyMail_MainFrame
---------------------------------------------------
function EasyMail.OnLoad(self)
    -- Register event that fires when the player logs in
    self:RegisterEvent("PLAYER_LOGIN");
end

---------------------------------------------------
-- EasyMail.OnEvent
-- Handle registered events - Frame: EasyMail_MainFrame
---------------------------------------------------

function EasyMail.OnEvent(self, event, ...)
    local arg1 = ...;

    -- PLAYER_LOGIN fires after all addons have loaded and just before the player enters the world
    if (event == "PLAYER_LOGIN") then
        if (GameLimitedMode_IsActive()) then
            -- inactive account, hide stuff to show message and dont do anything
            EasyMail_CheckAllButton:Hide()
            EasyMail_ClearAllButton:Hide()
            EasyMail_CheckPageButton:Hide()
            EasyMail_ClearPageButton:Hide()
            EasyMail_GetAllButton:Hide()

            return
        end

        curPlayer = UnitName("player");
        curRealm = GetRealmName();
        curFaction = UnitFactionGroup("player");

        -- Register event that fires when the mail frame is opened
        self:RegisterEvent("MAIL_SHOW");

        -- Register event that fires when a mail is sent successfully
        self:RegisterEvent("MAIL_SEND_SUCCESS");

        -- Register event that fires when the attachments are redrawn to check to see if attachment was taken
        self:RegisterEvent("MAIL_INBOX_UPDATE");

        -- Register events that fire after querying for guild and friends lists
        self:RegisterEvent("FRIENDLIST_UPDATE");
        self:RegisterEvent("GUILD_ROSTER_UPDATE");
        self:RegisterEvent("PLAYER_GUILD_UPDATE");

        EasyMail.SetupOptions();

        -- Hide Open All button
        EasyMail.HideOpenAllButton(EasyMail_SavedVars.OpenAll ~= "Y");

        -- Place dropdown button and set field width
        EasyMail.addrWidth = SendMailNameEditBox:GetWidth();
        EasyMail.HideDropdown(EasyMail_SavedVars.HideDrop == "Y");

        -- Lemmoros Move History Frame
        if EasyMail_SavedVars.MoveHFrame == nil then
            EasyMail_SavedVars.MoveHFrame = "Y"
        end
        EASYMAIL_L_ToggleMoveWindows(EasyMail_SavedVars.MoveHFrame == "Y");

        -- Create the sorted recently-mailed list
        EasyMail.SortList();

        -- Hook to the send mail button to know what addressee was entered since Blizzard clears it on a successful 
        -- mailing
        -- hooksecurefunc("SendMailMailButton_OnClick", EasyMail_GetAddressee);
        SendMailMailButton:HookScript("OnClick", EasyMail.GetAddressee);

        -- Hook to the SendMailFrame OnShow to hightlight the addressee text when showing frame
        SendMailFrame:HookScript("OnShow", function() SendMailNameEditBox:HighlightText() end)

        -- Hook to Blizzard's mail reset function to fill in the addressee field with the last mailed name
        hooksecurefunc("SendMailFrame_Reset", function()
            EasyMail.SetAddressee(nil, currentAddressee);
        end);

        -- Hook to the redraw function for the open mail to move the attachments down a bit to make room for the 
        -- Take All button
        hooksecurefunc("OpenMail_Update", EasyMail.AdjustAtt);

        -- Replace inbox onclick to cancel Take All if user changes open emails and to handle right-click
        for t = 1, INBOXITEMS_TO_DISPLAY do
            _G["MailItem" .. t .. "Button"]:SetScript("OnClick", EasyMail.MailItemOnClickHandler);
        end

        -- Place the Take All button
        EasyMail_AttButton:SetParent(OpenMailFrame);

        -- Hook the inbox update function to draw the checkboxes
        hooksecurefunc("InboxFrame_Update", EasyMail.InboxUpdate);

        -- Hook the prev and next buttons to reset the Mark Page button
        InboxPrevPageButton:HookScript("OnClick", EasyMail.ResetMarkPage);
        InboxNextPageButton:HookScript("OnClick", EasyMail.ResetMarkPage);

        -- Save settings for default inbox
        _, _, _, mailItemX, mailItemY = MailItem1:GetPoint(1);
        mailItemWidth = MailItem1:GetWidth();
        subjectWidth = MailItem1Subject:GetWidth();
        _, _, _, expireTimeX, expireTimeY = MailItem1ExpireTime:GetPoint(1);

        -- Adjust inbox to accomodate checkboxes
        EasyMail.ShowCheckBoxes();

        -- Hook the mail frame hide function to cancel the get all process
        MailFrame:HookScript("OnHide", EasyMail.StopGetAll);

        -- Hook the mail frame show function to reset the Mark All button
        MailFrame:SetScript("OnShow", EasyMail.ResetMarkAll);

        -- Hook the take money function to display money received
        OpenMailMoneyButton:HookScript("OnClick", function()
            if (EasyMail_SavedVars.Money == "Y") then
                EasyMail.PrintMoney();
            end
        end);

        -- Set scroll frame so that it resets the dropdown hide counter
        EasyMailDropdownScrollFrameScrollBar:SetScript("OnEnter", EasyMail.ScrollOnEnter);
        EasyMailDropdownScrollFrameScrollBar:SetScript("OnLeave", EasyMail.ScrollOnLeave);
        EasyMailDropdownScrollFrameScrollBarScrollUpButton:SetScript("OnEnter", EasyMail.ScrollOnEnter);
        EasyMailDropdownScrollFrameScrollBarScrollUpButton:SetScript("OnLeave", EasyMail.ScrollOnLeave);
        EasyMailDropdownScrollFrameScrollBarScrollDownButton:SetScript("OnEnter", EasyMail.ScrollOnEnter);
        EasyMailDropdownScrollFrameScrollBarScrollDownButton:SetScript("OnLeave", EasyMail.ScrollOnLeave);

        -- Create invis buttons for scrollbar to hide dropdown
        CreateFrame("Button", "EasyMail_UpButton", EasyMailDropdownScrollFrameScrollBarScrollUpButton,
            "EasyMailInvisibleButtonTemplate");
        EasyMail_UpButton:SetAllPoints(EasyMailDropdownScrollFrameScrollBarScrollUpButton);
        CreateFrame("Button", "EasyMail_DownButton", EasyMailDropdownScrollFrameScrollBarScrollDownButton,
            "EasyMailInvisibleButtonTemplate");
        EasyMail_DownButton:SetAllPoints(EasyMailDropdownScrollFrameScrollBarScrollDownButton);
        local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate");
        Mixin(EasyMail_MailDropdown, BackdropTemplateMixin)
        EasyMail_MailDropdown:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {
                left = 4,
                right = 4,
                top = 4,
                bottom = 4
            }
        });
        EasyMail_MailDropdown:SetBackdropColor(0, 0, 0, 1);
        -- Hook to money frame to set subject automatically
        SendMailMoneyGold:HookScript("OnTextChanged", EasyMail.MoneySubject);
        SendMailMoneySilver:HookScript("OnTextChanged", EasyMail.MoneySubject);
        SendMailMoneyCopper:HookScript("OnTextChanged", EasyMail.MoneySubject);

        -- Hook to inbox item tooltip to display text
        hooksecurefunc("InboxFrameItem_OnEnter", EasyMail.Tooltip);

        -- Hooks to addressee edit box for custom auto-complete
        SendMailNameEditBox:SetScript("OnTabPressed", EasyMail.OnTabPressed);
        SendMailNameEditBox:SetScript("OnEditFocusLost", EasyMail.OnEditFocusLost);
        SendMailNameEditBox:SetScript("OnCharComposition", EasyMail.OnCharComposition);
        SendMailNameEditBox:SetScript("OnChar", EasyMail.OnChar);
        SendMailNameEditBox:SetScript("OnEnterPressed", EasyMail.OnEnterPressed);
        SendMailNameEditBox:SetScript("OnEscapePressed", EasyMail.OnEscapePressed);
        SendMailNameEditBox:SetScript("OnTextChanged", EasyMail.OnTextChanged);

        -- Reposition too many mails warning at top of inbox
        -- InboxTooMuchMail:SetPoint("CENTER", InboxTooMuchMail:GetParent(), "CENTER", 7, 232);
        InboxTooMuchMail:SetPoint("TOP", InboxFrame, "TOP", -13, 4)

        if (EasyMail.isRetail) then
            inboxTitleText = MailFrame.TitleContainer
            InboxTooMuchMail:SetFrameStrata("HIGH")

            -- hook tabs to hide title
            hooksecurefunc("MailFrameTab_OnClick", EasyMail.UpdateTitleText)

            -- adjust addressee button location
            EasyMail_MailButton:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 5, 0)
        end

        -- Add logged-in character to list if option is enabled
        if (EasyMail_SavedVars.AutoAdd == "Y") then
            EasyMail.SaveAddressee(curPlayer, 1);
        end

        easyMail_Copper = EasyMail.Trim(gsub(COPPER_AMOUNT, "%%d", ""));
        easyMail_Silver = EasyMail.Trim(gsub(SILVER_AMOUNT, "%%d", ""));
        easyMail_Gold = EasyMail.Trim(gsub(GOLD_AMOUNT, "%%d", ""));

        -- Hook to open bags when Send Mail tab is clicked
        hooksecurefunc("MailFrameTab_OnClick", EasyMail.OpenBags);
        
        if (not EasyMail.isRetail) then
            -- Hook to fix send mail scrollbar
            hooksecurefunc("SendMailFrame_Update", EasyMail.SendMailFrameUpdate)

            if (EasyMail.isClassic) then
                -- Fix send mail editbox to properly handle escape and enter
                MailEditBox.ScrollBox.EditBox:SetScript("OnEscapePressed", function()
                    MailEditBox.ScrollBox.EditBox:ClearFocus()
                end)
                MailEditBox.ScrollBox.EditBox:SetScript("OnEnterPressed", function()
                    MailEditBox.ScrollBox.EditBox:Insert("\n")
                end)
            end
        end

        -- InterfaceOptions_AddCategory(EasyMail_OptionsPanel);
        easymail_options_category = Settings.RegisterCanvasLayoutCategory(EasyMail_OptionsPanel,
            EasyMail_OptionsPanel.name);
        Settings.RegisterAddOnCategory(easymail_options_category);
        -- EasyMail.OptionsRefresh();

        -- set up history frame to close with escape
        hooksecurefunc("CloseAllWindows", function()
            EASYMAIL_L_Sowframe_HistoryFrame:Hide()
        end)

        -- truncate excess history
        EasyMail.TruncateHistory(EasyMail_SavedVars.HistLen)

        -- fix location of calendar button
        if (EasyMail.isMists) then
            GameTimeFrame:SetPoint("TOPRIGHT", -1, -24)
        end

        -- fix location of send money radio buttons
        if (EasyMail.isRetail) then
            SendMailSendMoneyButton:SetPoint("TOPLEFT", SendMailMoney, "TOPRIGHT", 25, 12)
        end
    end

    -- MAIL_SHOW fires when the mailbox is opened and when the user opens a mail
    if (event == "MAIL_SHOW") then
        -- Set the addressee field to the last mailed name when the user opens the mail frame
        EasyMail.SetAddressee(nil, EasyMail_SavedVars[curRealm][curFaction].LastAddressee[curPlayer]);
    end

    -- MAIL_SEND_SUCCESS fires when a mail is successfully sent (check for nil arg1 since it also fires at other
    -- odd times)
    if (event == "MAIL_SEND_SUCCESS" and sendingMail) then
        -- Save the addressee to the list and set the last mailed addressee for the current character
        EasyMail.SaveAddressee(currentAddressee);
        -- Print Mail sent (Lemmoros)
        print("|cff40FB40EasyMail|r|cffFCE94F: " .. EASYMAIL_L_MESSAGETO .. " |r|cff9CBADA" .. currentAddressee ..
                  "|r|cffFCE94F " .. EASYMAIL_L_WSUBJ .. " |r|cff9CBADA\"" .. currenMailSubjectsee .. "\"|r|cffFCE94F " ..
                  EASYMAIL_L_SENT .. ".|r")
        if (EasyMail_SavedVars.HistLen > 0) then
            EasyMail_CreateStoreMessage()
        end
        EASYMAIL_L_ShowAll(false, "LeftButton")
        -- Print Mail sent end
    end

    -- MAIL_INBOX_UPDATE fires many times during mail work, but I only care about it if we are taking an attachment
    if (event == "MAIL_INBOX_UPDATE" and gettingAtt and curAtt) then
        -- User is trying to take all attachments - make sure the window is still open
        if (OpenMailFrame:IsVisible() and InboxFrame.openMailID and InboxFrame.openMailID >= 1) then
            -- If the current attachment button is not visible, the take was successful
            if (not curAtt:IsVisible()) then
                -- Reset the take timer, clear the current button, increase index to next button, and run the next
                -- take immediately
                curAtt = nil;
                timeSinceLastAtt = attInterval;
            end
        else
            -- User or take all process closed the mail - stop trying to take all
            if (OpenMailFrame:IsVisible()) then
                HideUIPanel(OpenMailFrame);
            end

            if (gettingAtt) then
                -- Take all probably completed, uncheck the checkbox
                checkBoxes[curMail] = false;
                InboxFrame_Update();
            end

            gettingAtt = false;
        end
    end

    -- Process guild list
    if (IsInGuild() and (event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE") and EasyMail_SavedVars.Guild ==
        "Y") then
        EasyMail.GetGuildNames();
    end

    -- Process friend list
    if (event == "FRIENDLIST_UPDATE" and EasyMail_SavedVars.Friends == "Y") then
        EasyMail.GetFriends();
    end
end

---------------------------------------------------
-- EasyMail.HideDropdown
-- Hide the dropdown button
---------------------------------------------------
function EasyMail.HideDropdown(hide)
    if (hide) then
        EasyMail_MailButton:Hide();
        SendMailNameEditBox:SetWidth(EasyMail.addrWidth);
        SendMailNameEditBoxMiddle:SetWidth(EasyMail.addrWidth)
    else
        EasyMail_MailButton:Show();
        SendMailNameEditBox:SetWidth(EasyMail.addrWidth - 18);
        SendMailNameEditBoxMiddle:SetWidth(EasyMail.addrWidth - 18)
    end
end

-- save message (Lemmoros)
function EasyMail_CreateStoreMessage()
    local message = {
        subject = currenMailSubjectsee,
        mailto = currentAddressee,
        creator = UnitName("player"),
        location = GetRealZoneText() or "Unknown Location",
        subzone = GetMinimapZoneText() or "Unknown Location",
        stamp = date(),
        timestamp = time()
    }

    EasyMail.TruncateHistory(EasyMail_SavedVars.HistLen - 1)
    local mail_our_pos = table.getn(EasyMail_Maillog) + 1;
    EasyMail_Maillog[mail_our_pos] = message;
    return mail_our_pos;
end
-- save message end (Lemmoros)

---------------------------------------------------
-- EasyMail.TruncateHistory
-- Remove history entries in excess of history length
---------------------------------------------------
function EasyMail.TruncateHistory(count)
    local total_mails = table.getn(EasyMail_Maillog)
    while (total_mails > count) do
        table.remove(EasyMail_Maillog, 1);
        total_mails = table.getn(EasyMail_Maillog);
    end
end

---------------------------------------------------
-- EasyMail.HideOpenAllButton
-- Hide the Open All button
---------------------------------------------------
function EasyMail.HideOpenAllButton(hide)
    if (hide) then
        OpenAllMail:Hide();
    else
        OpenAllMail:Show();
    end
end

---------------------------------------------------
-- EasyMail.OnClick
-- Process the mail dropdown button click
---------------------------------------------------
function EasyMail.OnClick()
    -- Set cursor focus to the addressee field
    SendMailNameEditBox:SetFocus();

    -- Show the addressee dropdown list
    if (EasyMail_MailDropdown:IsShown()) then
        EasyMail_MailDropdown:Hide();
    else
        EasyMail_MailDropdown:Show();
        FauxScrollFrame_SetOffset(EasyMailDropdownScrollFrame, 0);
        EasyMailDropdownScrollFrame:SetVerticalScroll(0);
    end

    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

---------------------------------------------------
-- EasyMail.DropdownOnShow
-- Build the full dropdown list
---------------------------------------------------
function EasyMail.DropdownOnShow(self)
    local t, r;
    fullList = {};

    -- Copy sorted list into final display array
    for t = 1, #sortedList do
        r = #fullList + 1;
        fullList[r] = {};
        fullList[r].text = sortedList[t];
    end

    -- Create Add Name entry
    r = #fullList + 1;
    fullList[r] = {};
    fullList[r].text = "|cff00ee00" .. EASYMAIL_ADDNAMEOPTION;
    fullList[r].value = "^" .. EASYMAIL_ADDNAMEOPTION;

    -- Add friends
    if (EasyMail_SavedVars.Friends == "Y" and #friendList > 0) then
        r = #fullList + 1;
        fullList[r] = {};
        fullList[r].text = NORMAL_FONT_COLOR_CODE .. EASYMAIL_FRIENDSTEXT;
        fullList[r].noclick = true;

        for t = 1, #friendList do
            r = #fullList + 1;
            fullList[r] = {};
            fullList[r].text = "    " .. friendList[t];
            fullList[r].value = friendList[t];
        end
    end

    -- Add guild members
    if (IsInGuild() and EasyMail_SavedVars.Guild == "Y" and #guildList > 0) then
        r = #fullList + 1;
        fullList[r] = {};
        fullList[r].text = NORMAL_FONT_COLOR_CODE .. EASYMAIL_GUILDTEXT;
        fullList[r].noclick = true;

        for t = 1, #guildList do
            r = #fullList + 1;
            fullList[r] = {};
            fullList[r].text = "    " .. guildList[t];
            fullList[r].value = guildList[t];
        end
    end

    -- Create Clear Field final entry
    r = #fullList + 1;
    fullList[r] = {};
    fullList[r].text = "|cff00ffff" .. EASYMAIL_CLEAROPTION;
    fullList[r].value = "^" .. EASYMAIL_CLEAROPTION;

    menuResized = false;

    EasyMail.DropdownUpdate();

    -- Add scrolling capability to the dropdown list
    if (#fullList > EasyMail.curListMaxLen) then
        EasyMailDropdownScrollFrame:SetParent(EasyMail_MailDropdown);
        EasyMailDropdownScrollFrame:SetPoint("TOPRIGHT", EasyMail_MailDropdown, "TOPRIGHT", -33, -12);
        EasyMailDropdownScrollFrame:SetPoint("BOTTOMLEFT", EasyMail_MailDropdown, "BOTTOMLEFT", 12, 10);
        EasyMailDropdownScrollFrame:Show();
    else
        EasyMailDropdownScrollFrame:Hide();
    end

    -- EasyMail.StartCounting();
end

---------------------------------------------------
-- EasyMail.DropdownUpdate
-- Scroll the dropdown list
---------------------------------------------------
function EasyMail.DropdownUpdate()
    local t, index;
    local numButtons = #fullList;
    local button, buttonText, invisButton;
    local maxwidth = 0;

    if (numButtons > EasyMail.curListMaxLen) then
        numButtons = EasyMail.curListMaxLen;
    end

    local offset = FauxScrollFrame_GetOffset(EasyMailDropdownScrollFrame);

    for t = 1, EasyMail.curListMaxLen do
        index = t + offset;
        button = _G["EasyMail_MailDropdownButton" .. t];

        if (index <= #fullList) then
            invisButton = _G["EasyMail_MailDropdownButton" .. t .. "InvisibleButton"];
            buttonText = _G["EasyMail_MailDropdownButton" .. t .. "NormalText"];
            button:SetText(fullList[index].text or fullList[index].value);

            if (fullList[index].noclick) then
                button:Disable();
                invisButton:Show();
            else
                button.value = (fullList[index].value or fullList[index].text);
                button:Enable();
                invisButton:Hide();
            end

            width = buttonText:GetWidth() + 10;

            if (width > maxwidth) then
                maxwidth = width;
            end

            button:Show();
        else
            button:Hide();
        end
    end

    -- Adjust menu width
    if (not menuResized) then
        for t = 1, EasyMail.curListMaxLen do
            button = _G["EasyMail_MailDropdownButton" .. t];
            button:SetWidth(maxwidth);
        end

        if (#fullList > EasyMail.curListMaxLen) then
            maxwidth = maxwidth + 15;
        end

        EasyMail_MailDropdown:SetWidth(maxwidth + 25);

        menuResized = true;

        -- Adjust menu height
        EasyMail_MailDropdown:SetHeight((numButtons * EasyMail.buttonHeight) + 27);
    end

    if (#fullList > EasyMail.curListMaxLen) then
        -- Show or hide scrollbar invis buttons
        if (offset == 0) then
            EasyMail_UpButton:Show();
        else
            EasyMail_UpButton:Hide();
        end

        if (offset == #fullList - EasyMail.curListMaxLen) then
            EasyMail_DownButton:Show();
        else
            EasyMail_DownButton:Hide();
        end
    end

    -- ScrollFrame stuff
    FauxScrollFrame_Update(EasyMailDropdownScrollFrame, #fullList, EasyMail.curListMaxLen, EasyMail.buttonHeight);
end

---------------------------------------------------
-- EasyMail.DropdownButtonOnClick
-- Called when a dropdown entry is clicked (had to enhance blizzard's version to pass the mouse button param)
---------------------------------------------------
function EasyMail.DropdownButtonOnClick(self, button)
    local value = self.value;

    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);

    if (button == "RightButton") then
        if (EasyMail.InMailList(value) > 0) then
            nameToDel = value;
            StaticPopupDialogs["EASYMAIL_DELETENAME"].text = format(EASYMAIL_DELNAMEQUESTION, value);
            StaticPopup_Show("EASYMAIL_DELETENAME");
        else
            return;
        end
    end

    if (button == "LeftButton") then
        -- Call the SetAddressee function
        EasyMail.SetAddressee(nil, value);
    end

    EasyMail_MailDropdown:Hide();
end

---------------------------------------------------
-- EasyMail.DeleteName
-- Remove the right-clicked name from the addressee list
---------------------------------------------------
function EasyMail.DeleteName()
    table.remove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, EasyMail.InMailList(nameToDel));
    EasyMail.SortList();
    EasyMail.Print(format(EASYMAIL_DELNAMEMSG, nameToDel));
end

---------------------------------------------------
-- EasyMail.ScrollOnEnter
-- Stop the dropdown list hide counter
---------------------------------------------------
function EasyMail.ScrollOnEnter()
    EasyMail.StopCounting();
end

---------------------------------------------------
-- EasyMail.ScrollOnLeave
-- Restart the dropdown list hide counter
---------------------------------------------------
function EasyMail.ScrollOnLeave()
    EasyMail.StartCounting();
end

---------------------------------------------------
-- EasyMail.StartCounting
-- Start the dropdown hide countdown 
---------------------------------------------------
function EasyMail.StartCounting()
    dropdownTimer = UIDROPDOWNMENU_SHOW_TIME;
    isDropdownCounting = true;
end

---------------------------------------------------
-- EasyMail.StopCounting
-- Stop the dropdown hide countdown 
---------------------------------------------------
function EasyMail.StopCounting()
    isDropdownCounting = false;
end

---------------------------------------------------
-- EasyMail.GetAddressee
-- Get the addressee last mailed from the text field
---------------------------------------------------
function EasyMail.GetAddressee()
    sendingMail = true;

    local text = SendMailNameEditBox:GetText();
    -- Get mail subject (Lemmoros)
    currenMailSubjectsee = SendMailSubjectEditBox:GetText()
    -- end get mail subject (Lemmoros)
    currentAddressee = EasyMail.NameCase(text);
end

---------------------------------------------------
-- EasyMail.SetAddressee
-- Update the addressee field with the string passed to the function
---------------------------------------------------
function EasyMail.SetAddressee(self, namestr, arg2, checked, button)
    if (not namestr or namestr == "^" .. EASYMAIL_CLEAROPTION) then
        -- User selected the Clear Field option on the dropdown
        SendMailNameEditBox:SetText("");
        return;
    end

    if (namestr == "^" .. EASYMAIL_ADDNAMEOPTION) then
        -- User selected the Add Name option on the dropdown
        StaticPopup_Show("EASYMAIL_ADDNAME");
        return;
    end

    SendMailNameEditBox:SetText(namestr);
    SendMailNameEditBox:SetCursorPosition(0)

    -- Highlight the text in the field to make it easy for the user to change it by typing
    SendMailNameEditBox:HighlightText();
end

---------------------------------------------------
-- EasyMail.SaveAddressee
-- Save the last mailed addressee to the list and to the last addressee variable for the current character
---------------------------------------------------
function EasyMail.SaveAddressee(namestr, type)
    -- type = nil for name used when mailing, 1 for adding current logged in char, 2 for manual add
    local index, t;
    local listlen = #EasyMail_SavedVars[curRealm][curFaction].EasyMailList;

    -- Make sure the first letter is uppercase and the rest are lower
    local namestr = EasyMail.NameCase(namestr);

    -- Locate the name in the list if it's there
    index = EasyMail.InMailList(namestr);

    -- If we are trying to add a logged-in char, don't do it if the list is at max length or if the name already exists
    if (type == 1 and (index > 0 or listlen >= EasyMail_SavedVars[curRealm][curFaction].MailListLen)) then
        return;
    end

    -- If the manually added name already exists alert the user
    if (type == 2 and index > 0) then
        StaticPopupDialogs["EASYMAIL_ADDNAMEMSG"].text = format(EASYMAIL_ADDNAMEERR, namestr);
        StaticPopup_Show("EASYMAIL_ADDNAMEMSG");
        return
    end

    -- Add names that don't already exist in the list, or if the name exists, move it to the top
    if (index == 0) then
        -- if the list is at max length, delete the first (oldest) entry
        if (listlen >= EasyMail_SavedVars[curRealm][curFaction].MailListLen) then
            table.remove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, 1);
            listlen = listlen - 1;
        end

        -- Add the name to the end of the list
        EasyMail_SavedVars[curRealm][curFaction].EasyMailList[listlen + 1] = namestr;
    else
        -- Only move the name if it's not already at the top
        if (index < listlen) then
            -- Move the name to the top of the list, maintaining list order
            table.remove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, index);
            EasyMail_SavedVars[curRealm][curFaction].EasyMailList[listlen] = namestr;
        end
    end

    -- Save the name as the last mailed addressee for the current character only if the name passed was used in a mail
    if (not type) then
        EasyMail_SavedVars[curRealm][curFaction].LastAddressee[curPlayer] = namestr;
    end

    -- Output message on successful manual add
    if (type == 2) then
        EasyMail.Print(format(EASYMAIL_ADDNAMEMSG, namestr));
    end

    EasyMail.SortList();
end

---------------------------------------------------
-- EasyMail.InMailList
-- Returns the table index if the specified name exists in the list, 0 otherwise
---------------------------------------------------
function EasyMail.InMailList(namestr)
    local t;

    for t = 1, #EasyMail_SavedVars[curRealm][curFaction].EasyMailList do
        if (EasyMail_SavedVars[curRealm][curFaction].EasyMailList[t] == namestr) then
            return t;
        end
    end

    return 0;
end

---------------------------------------------------
-- EasyMail.SortList
-- Sort the recently-mailed list
---------------------------------------------------
function EasyMail.SortList()
    local t = 1;
    local count = 1;

    -- Clean the list first in case problems remain from bugs
    while (t <= #EasyMail_SavedVars[curRealm][curFaction].EasyMailList) do
        if (not EasyMail_SavedVars[curRealm][curFaction].EasyMailList[t]) then
            -- Remove nil
            table.remove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, t);
        else
            -- Remove duplicates
            local r;
            local removed = false

            for r = t + 1, #EasyMail_SavedVars[curRealm][curFaction].EasyMailList do
                if (EasyMail_SavedVars[curRealm][curFaction].EasyMailList[t] ==
                    EasyMail_SavedVars[curRealm][curFaction].EasyMailList[r]) then
                    table.remove(EasyMail_SavedVars[curRealm][curFaction].EasyMailList, t);
                    removed = true;
                    break
                end
            end

            if (not removed) then
                t = t + 1;
            end
        end
    end

    -- Copy list entries into table for sorting, ignoring the entry for the current player
    sortedList = {};

    for t = 1, #EasyMail_SavedVars[curRealm][curFaction].EasyMailList do
        if (EasyMail_SavedVars[curRealm][curFaction].EasyMailList[t] ~= curPlayer) then
            sortedList[count] = EasyMail_SavedVars[curRealm][curFaction].EasyMailList[t];
            count = count + 1;
        end
    end

    -- Sort list by name
    table.sort(sortedList);
end

---------------------------------------------------
-- EasyMail.GetGuildNames
-- Build guild list to add to dropdown
---------------------------------------------------
function EasyMail.GetGuildNames()
    local t;
    local count = 1;
    guildList = {};

    -- Copy list entries into temporary table for sorting, ignoring the entry for the current player
    for t = 1, GetNumGuildMembers(true) do
        local name = GetGuildRosterInfo(t)

        if (name) then
            name = Ambiguate(name, "none");

            if (name ~= curPlayer) then
                guildList[count] = name;
                count = count + 1
            end
        end
    end

    -- Sort list by name
    table.sort(guildList);

    guildQueryInterval = 0;
end

---------------------------------------------------
-- EasyMail.GetFriends
-- Build friend list to add to dropdown
---------------------------------------------------
function EasyMail.GetFriends()
    local counter = 1;
    friendList = {};

    -- Copy list entries into temporary table for sorting
    -- Battlenet friends
    for t = 1, BNGetNumFriends() do
        local gameInfo;

        if (EasyMail.isRetail) then
            local accountInfo = C_BattleNet.GetAccountInfoByID(t);

            if (accountInfo) then
                gameInfo = accountInfo.gameAccountInfo;
            end
        else
            gameInfo = select(6, BNGetFriendInfo(t));
        end

        if (gameInfo) then
            local name, realm;

            if (EasyMail.isRetail) then
                name = gameInfo.characterName;
                realm = gameInfo.realmName;

                if (not realm or strlen(realm) < 1) then
                    name = nil;
                end
            else
                _, name, _, realm = BNGetGameAccountInfo(gameInfo);

                if (not realm or strlen(realm) < 1 or realm ~= RemoveSpaces(curRealm)) then
                    name = nil;
                end
            end

            if (name and strlen(name) > 0) then
                if (realm and strlen(realm) > 0 and realm ~=
                    ((EasyMail.isRetail and curRealm) or RemoveSpaces(curRealm))) then
                    name = name .. "-" .. realm;
                end

                friendList[counter] = name;
                counter = counter + 1;
            end
        end
    end

    -- WoW friends
    for t = 1, C_FriendList.GetNumFriends() do
        friendList[counter] = C_FriendList.GetFriendInfoByIndex(t).name;
        counter = counter + 1;
    end

    -- Sort list by name
    table.sort(friendList);

    friendQueryInterval = 0;
end

---------------------------------------------------
-- EasyMail.AdjustAtt
-- Move the attachments down to make room for the Take All button
---------------------------------------------------
function EasyMail.AdjustAtt()
    if (not InboxFrame.openMailID) then
        return;
    end

    -- Resize the scroll frame (taken from MailFrame.lua)
    local scrollHeight = OpenMailScrollFrame:GetHeight() - 8

    OpenMailScrollFrame:SetHeight(scrollHeight);
    OpenMailScrollChildFrame:SetHeight(scrollHeight);
    OpenMailHorizontalBarLeft:SetPoint("TOPLEFT", "OpenMailFrame", "TOPLEFT", 2,
        0 - OpenMailScrollFrame:GetHeight() - 80);
    if (not EasyMail.isRetail) then
        OpenScrollBarBackgroundTop:SetHeight(min(scrollHeight, 256));
        OpenScrollBarBackgroundTop:SetTexCoord(0, 0.484375, 0, min(scrollHeight, 256) / 256);
    end
    OpenStationeryBackgroundLeft:SetHeight(scrollHeight);
    OpenStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256);
    OpenStationeryBackgroundRight:SetHeight(scrollHeight);
    OpenStationeryBackgroundRight:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256);

    -- Adjust the attchment text
    if (OpenMailFrame.itemButtonCount > 0) then
        OpenMailAttachmentText:SetPoint("TOPLEFT", "OpenMailHorizontalBarLeft", "BOTTOMLEFT", 12, -2);
    else
        OpenMailAttachmentText:SetPoint("TOPLEFT", "OpenMailFrame", "BOTTOMLEFT",
            (OpenMailFrame:GetWidth() - OpenMailAttachmentText:GetWidth()) / 2, 62);
    end

    -- Position Take All button
    EasyMail_AttButton:SetPoint("TOPRIGHT", "OpenMailHorizontalBarLeft", "BOTTOMRIGHT", 67, 5);

    -- Hide or disable the button when mail is COD, there are no money or item attachments, or we are taking attachments
    if (not (OpenMailFrame.money or EasyMail.HasAttachments())) then
        EasyMail_AttButton:Hide();
    else
        EasyMail_AttButton:Show();

        if (gettingAtt or OpenMailFrame.cod) then
            EasyMail_AttButton:Disable();
        else
            EasyMail_AttButton:Enable();
        end
    end
end

---------------------------------------------------
-- EasyMail.HasAttachments
-- Check to see if the mail has attachments to take
---------------------------------------------------
function EasyMail.HasAttachments()
    if (InboxFrame.openMailID and InboxFrame.openMailID > 0) then
        -- Loop through list of attachment buttons
        for t = 1, ATTACHMENTS_MAX do
            if (GetInboxItem(InboxFrame.openMailID, t)) then
                -- There is an item attachment
                return true;
            end
        end
    end

    return false;
end

---------------------------------------------------
-- EasyMail.GetAll
-- Start process to take all attachments from all checked mails
---------------------------------------------------
function EasyMail.GetAll()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

    if (gettingAll) then
        return;
    end

    HideUIPanel(OpenMailFrame);

    gettingAll = true;
    -- CheckAll = true;
    -- CheckPage = true;
    curMail = GetInboxNumItems() + 1;
    totalMoney = 0;
end

---------------------------------------------------
-- EasyMail.MailAtt
-- Start the process to take all attachments from the specified mail
---------------------------------------------------
function EasyMail.MailAtt(mailid)
    if (gettingAtt) then
        return;
    end

    -- Set the mail window to not redraw the attachment buttons - this is what the window does when the buttons are 
    -- manually clicked, so we will do it too
    OpenMailFrame.updateButtonPositions = false;

    -- Disable the Take All button
    EasyMail_AttButton:Disable();

    -- Start at button 1, execute onupdate code immediately, reset the take timeout (tracks how long we have been
    -- trying to take the current attachment), clear the button, and set the flag to indicate we are taking
    -- attachments
    attIndex = 0;
    timeSinceLastAtt = attInterval;
    curAtt = nil;
    gettingAtt = true;
    curMail = mailid;
end

---------------------------------------------------
-- EasyMail.OnUpdate
-- Process all attachments for single open mail or for checked mails, also process guild and friend list
---------------------------------------------------
function EasyMail.OnUpdate(self, elapsed)
    if (not EasyMail_MailDropdown:IsShown() and not MailFrame:IsShown()) then
        return;
    end

    timeSinceLastAtt = timeSinceLastAtt + elapsed

    -- Execute only at the specified interval
    if (timeSinceLastAtt >= attInterval) then
        -- Check if we are taking attachments
        if (gettingAtt) then
            -- Check if we are not currently trying to take an attachment
            if (not curAtt) then
                -- Take next attachment
                attIndex = attIndex + 1;

                -- Use for loop to skip the buttons we don't want
                for t = attIndex, ATTACHMENTS_MAX do
                    -- Use list of buttons that MailFrame.lua builds
                    curAtt = OpenMailFrame.activeAttachmentButtons[attIndex];

                    -- skip the buttons that are hidden and the letter attachment button
                    if (curAtt and curAtt:GetName() ~= "OpenMailLetterButton" and curAtt:IsVisible()) then
                        -- The index is pointing to a button we want to take
                        break
                    end

                    -- Try next button
                    attIndex = attIndex + 1;
                end

                -- Reset timer - we only want to wait for the successful take for a specified period of time
                attTimer = 0;
            end

            -- Try to take the current attachment (in curAtt) if the index has not gone off the top of the list,
            -- the mail frame is still open, a valid mail is selected, and we have not timed out trying to
            -- take an attachment
            if (attIndex <= ATTACHMENTS_MAX and attTimer <= attTimeout and OpenMailFrame:IsVisible() and
                InboxFrame.openMailID and InboxFrame.openMailID >= 1) then

                if (attTimer == 0) then
                    -- Attempt take
                    if (curAtt:GetName() == "OpenMailMoneyButton") then
                        TakeInboxMoney(InboxFrame.openMailID);

                        if (gettingAll and EasyMail_SavedVars.Total == "Y") then
                            totalMoney = totalMoney + OpenMailFrame.money;
                        end

                        if (EasyMail_SavedVars.Money == "Y") then
                            EasyMail.PrintMoney();
                        end
                    else
                        TakeInboxItem(InboxFrame.openMailID, _G[curAtt:GetName()]:GetID());
                    end
                end

                -- update timer - we dont try to take the same attachment forever
                attTimer = attTimer + attInterval;
            else
                -- The user has closed the mail, we finished taking all attachments, or we timed out getting one
                -- of the attachments
                if (attTimer > attTimeout) then
                    -- Timed out
                    EasyMail.PrintError(format(EASYMAIL_ERRTIMEOUT, attTimeout));

                    -- Stop the Get all process also - something bad is happening
                    EasyMail.StopGetAll();
                else
                    if (OpenMailFrame:IsVisible()) then
                        HideUIPanel(OpenMailFrame);
                    end
                end

                if (attIndex > ATTACHMENTS_MAX and gettingAtt) then
                    -- Completed take all successully, uncheck the checkbox
                    checkBoxes[curMail] = false;
                    InboxFrame_Update();
                end

                gettingAtt = false;
            end
        end

        timeSinceLastAtt = 0
    end

    if (gettingAll and not gettingAtt and deleteCount == 0 and not OpenMailFrame:IsVisible()) then
        -- We are getting all attachments from all mails and the mail window is closed, so find the next mail for
        -- processing and open it.
        if (curMail > 1) then
            curMail = curMail - 1;

            local packageIcon, stationeryIcon, sender, subject, money, CODAmount = GetInboxHeaderInfo(curMail);
            local pending = (subject and EasyMail.MatchTemplate(AUCTION_INVOICE_MAIL_SUBJECT, subject));

            -- Skip unchecked, COD mails, and pending auction mails if the option is selected
            if (checkBoxes[curMail] and (not CODAmount or CODAmount == 0) and subject and
                (not pending or EasyMail_SavedVars.DelPending == "Y")) then
                -- Page the inbox to the correct page
                InboxFrame.pageNum = floor((curMail - 1) / INBOXITEMS_TO_DISPLAY) + 1;
                InboxFrame_Update();

                -- Actually open the mail
                _G["MailItem" .. (((curMail - 1) % INBOXITEMS_TO_DISPLAY) + 1) .. "Button"]:Click("LeftButton");

                if (pending) then
                    OpenMail_Delete();
                    deleteCount = GetInboxNumItems();
                end
            else
                checkBoxes[curMail] = false;
                InboxFrame_Update();
            end
        else
            -- Done processing mails
            EasyMail.StopGetAll();
        end
    end

    if (gettingAll and not gettingAtt and deleteCount == 0 and OpenMailFrame:IsVisible()) then
        -- Start the take process for the selected open mail
        EasyMail.MailAtt(curMail);
    end

    if (deleteCount > 0) then
        if (GetInboxNumItems() < deleteCount) then
            deleteCount = 0;

            -- Just in case...
            if (OpenMailFrame:IsVisible()) then
                HideUIPanel(OpenMailFrame);
            end
        end
    end

    if (guildQueryInterval > 0 and IsInGuild() and EasyMail_SavedVars.Guild == "Y") then
        -- Execute Query for guild list
        timeSinceLastGuildQuery = timeSinceLastGuildQuery + elapsed

        if (timeSinceLastGuildQuery >= guildQueryInterval) then
            -- Query guild members
            if (GuildRoster) then
                GuildRoster()
            else
                C_GuildInfo.GuildRoster()
            end

            guildQueryInterval = 3;
            timeSinceLastGuildQuery = 0
        end
    end

    if (friendQueryInterval > 0 and EasyMail_SavedVars.Friends == "Y") then
        -- Execute Query for friend list
        timeSinceLastFriendQuery = timeSinceLastFriendQuery + elapsed

        if (timeSinceLastFriendQuery >= friendQueryInterval) then
            -- Query friends
            C_FriendList.ShowFriends();

            friendQueryInterval = 3;
            timeSinceLastFriendQuery = 0
        end
    end

    -- Hide dropdown if the send mail frame is not visible
    if (EasyMail_MailDropdown:IsShown() and not SendMailFrame:IsVisible()) then
        EasyMail_MailDropdown:Hide();
    end

    -- Hide dropdown after 2 seconds
    if (isDropdownCounting) then
        dropdownTimer = dropdownTimer - elapsed;

        if (dropdownTimer < 0) then
            EasyMail_MailDropdown:Hide();
            isDropdownCounting = false;
        end
    end
end

---------------------------------------------------
-- EasyMail.StopGetAll
-- Stop the attachment getting process
---------------------------------------------------
function EasyMail.StopGetAll()
    sendingMail = false;

    if (not gettingAll) then
        return;
    end

    if (totalMoney > 0) then
        EasyMail.PrintTotal();
        totalMoney = 0;
    end

    gettingAtt = false;
    gettingAll = false;
end

---------------------------------------------------
-- EasyMail.MailItemOnClickHandler
-- Stop the attachment getting process if the user clicks an inbox button
-- Also drives right-click inbox functionality
---------------------------------------------------
function EasyMail.MailItemOnClickHandler(self, button)
    local index = self.index;
    local modifiedClick = IsModifiedClick("MAILAUTOLOOTTOGGLE");

    if (gettingAtt) then
        EasyMail.StopGetAll();
    end

    if (modifiedClick) then
        InboxFrame_OnModifiedClick(self, index);
        return;
    end

    if (button ~= "RightButton") then
        -- Execute standard onclick
        InboxFrame_OnClick(self, index);
        return;
    end

    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead =
        GetInboxHeaderInfo(index);

    local doGet = (money > 0 or hasItem);
    local doDel = not (money > 0 or hasItem);

    if ((doGet and EasyMail_SavedVars.ClickGet ~= "Y") or
        (doDel and EasyMail_SavedVars.ClickDel ~= "Y" or CODAmount > 0)) then
        InboxFrame_OnClick(self, index);
        return;
    end

    self:SetChecked(not self:GetChecked());

    if (doDel) then
        deleteMail = index;

        if (wasRead and EasyMail_SavedVars.DelPrompt ~= "Y") then
            EasyMail.ClickDelete();
        else
            if (not wasRead) then
                StaticPopupDialogs["EASYMAIL_DELETEMAIL"].text = format(EASYMAIL_DELETEUNREADQUESTION, sender);
            else
                StaticPopupDialogs["EASYMAIL_DELETEMAIL"].text = format(EASYMAIL_DELETEQUESTION, sender);
            end

            StaticPopup_Show("EASYMAIL_DELETEMAIL");
        end

        return;
    end

    EasyMail.OpenMail(index);

    if (doGet) then
        EasyMail.MailAtt(index);
    end
end

---------------------------------------------------
-- EasyMail.OpenMail
-- Open a mail using its index (from MailFrame.lua InboxFrame_OnClick)
---------------------------------------------------
function EasyMail.OpenMail(index)
    local isShown = OpenMailFrame:IsShown();

    InboxFrame.openMailID = index;
    OpenMailFrame.updateButtonPositions = true;
    OpenMail_Update();
    -- OpenMailFrame:Show();
    ShowUIPanel(OpenMailFrame);

    if (not isShown) then
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN);
    end

    InboxFrame_Update();
end

---------------------------------------------------
-- EasyMail.ClickDelete
-- Processes the right click deletion
---------------------------------------------------
function EasyMail.ClickDelete()
    EasyMail.OpenMail(deleteMail);
    OpenMail_Delete();
end

---------------------------------------------------
-- EasyMail.ShowCheckBoxes
-- Show or hide the checkboxes when addon is enabled or disabled
---------------------------------------------------
function EasyMail.ShowCheckBoxes()
    -- Move the inbox frames over to the right to make room for the checkboxes
    MailItem1:SetPoint("TOPLEFT", "InboxFrame", "TOPLEFT", 30, -70);

    for t = 1, INBOXITEMS_TO_DISPLAY do
        -- Shorten the widths of the inbox frames, shorten the subject, and move the expire time text over
        _G["MailItem" .. t]:SetWidth(288);
        _G["MailItem" .. t .. "Subject"]:SetWidth(231);
        -- _G["MailItem"..t.."ExpireTime"]:SetPoint("TOPRIGHT", "MailItem"..t, "TOPRIGHT", 10, -4);

        -- Create checkboxes and locate them
        local frame;

        if (not _G["EasyMail_CheckButton" .. t]) then
            frame = CreateFrame("CheckButton", "EasyMail_CheckButton" .. t, _G["MailItem" .. t],
                "EasyMail_CheckButtonTemplate");
            frame:SetPoint("TOPLEFT", "MailItem" .. t, "TOPLEFT", -25, -9);
            frame:Hide();
        end
    end
end

---------------------------------------------------
-- EasyMail.InboxUpdate
-- Draw the inbox checkboxes
---------------------------------------------------
function EasyMail.InboxUpdate()
    -- EasyMail_CheckAllButton:SetText((CheckAll and EASYMAIL_CHECKALLTEXT) or EASYMAIL_CLEARALLTEXT);
    -- EasyMail_CheckPageButton:SetText((CheckPage and EASYMAIL_CHECKPAGETEXT) or EASYMAIL_CLEARPAGETEXT);

    local numItems, totalItems = GetInboxNumItems();

    if (numItems > 0) then
        EasyMail_CheckAllButton:Enable();
        EasyMail_ClearAllButton:Enable();
        EasyMail_CheckPageButton:Enable();
        EasyMail_ClearPageButton:Enable();
        OpenAllMail:Enable();
    else
        EasyMail_CheckAllButton:Disable();
        EasyMail_ClearAllButton:Disable();
        EasyMail_CheckPageButton:Disable();
        EasyMail_ClearPageButton:Disable();
        OpenAllMail:Disable();
    end

    EasyMail.EnableGetButton();

    -- Trim the checkbox table if necessary
    while numItems < #checkBoxes do
        tremove(checkBoxes, numItems + 1);
    end

    -- Add entries to the checkbox table if necessary defaulting them off (new mails appear at front of list)
    for t = #checkBoxes + 1, numItems do
        tinsert(checkBoxes, 1, false);
    end

    local index = ((InboxFrame.pageNum - 1) * INBOXITEMS_TO_DISPLAY) + 1;

    for i = 1, INBOXITEMS_TO_DISPLAY do
        if (index <= numItems) then
            -- Show the box as checked if the corresponding table entry is true
            _G["EasyMail_CheckButton" .. i]:SetChecked(checkBoxes[index]);
            _G["EasyMail_CheckButton" .. i]:Show();
        else
            _G["EasyMail_CheckButton" .. i]:Hide();
        end

        index = index + 1;
    end

    mailBoxFull = totalItems > numItems

    EasyMail.UpdateTitleText()
end

---------------------------------------------------
-- EasyMail.UpdateTitleText
-- Hide the inbox title text if mailbox full
---------------------------------------------------
function EasyMail.UpdateTitleText()
    if (mailBoxFull and (not EasyMail.isRetail or InboxFrame:IsShown())) then
        inboxTitleText:Hide()
    else
        inboxTitleText:Show()
    end
end

---------------------------------------------------
-- EasyMail.EnableGetButton
-- Enable or disable the get attachments button
---------------------------------------------------
function EasyMail.EnableGetButton()
    local t;
    local val = false;

    for t = 1, GetInboxNumItems() do
        if (checkBoxes[t]) then
            val = true;
            break
        end
    end

    if (val) then
        EasyMail_GetAllButton:Enable();
    else
        EasyMail_GetAllButton:Disable();
    end
end

---------------------------------------------------
-- EasyMail.CheckButtonOnMouseUp
-- Toggle the check box for the inbox item
---------------------------------------------------
function EasyMail.CheckButtonOnMouseUp(self)
    -- Get the inbox button for the selected mail
    local index = gsub(self:GetName(), "EasyMail_CheckButton(%d+)", "%1");
    local button = _G["MailItem" .. index .. "Button"];

    -- Toggle the table entry indicated by the mail index field on the inbox button
    checkBoxes[button.index] = not checkBoxes[button.index];

    EasyMail.EnableGetButton();
end

---------------------------------------------------
-- EasyMail.CheckAll
-- Check or uncheck all checkboxes
---------------------------------------------------
function EasyMail.CheckAll(flag)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

    if (not gettingAll) then
        for t = 1, #checkBoxes do
            checkBoxes[t] = flag;
        end

        -- CheckAll = not CheckAll;

        EasyMail.InboxUpdate();
    end
end

---------------------------------------------------
-- EasyMail.CheckPage
-- Check or uncheck all checkboxes on current inbox page
---------------------------------------------------
function EasyMail.CheckPage(flag)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

    if (not gettingAll) then
        local index = ((InboxFrame.pageNum - 1) * INBOXITEMS_TO_DISPLAY) + 1;

        for i = 1, INBOXITEMS_TO_DISPLAY do
            if (index > #checkBoxes) then
                break
            end

            checkBoxes[index] = flag;
            index = index + 1;
        end

        -- CheckPage = not CheckPage;

        EasyMail.InboxUpdate();
    end
end

---------------------------------------------------
-- EasyMail.ResetMarkAll
-- Set the Mark All button back to Mark All rather than Clear All when the user opens the mail box
-- Also execute friend and quild queries to refresh the lists when the inbox is opened
---------------------------------------------------
function EasyMail.ResetMarkAll()
    -- CheckAll = true;
    -- CheckPage = true;
    -- EasyMail_CheckAllButton:Disable();
    -- EasyMail_CheckPageButton:Disable();
    -- EasyMail_GetAllButton:Disable();

    -- Query for the friends and guild lists
    if (IsInGuild() and EasyMail_SavedVars.Guild == "Y") then
        guildQueryInterval = .5;
    end

    if (EasyMail_SavedVars.Friends == "Y") then
        friendQueryInterval = .5;
    end
end

---------------------------------------------------
-- EasyMail.ResetMarkPage
-- Set the Clear Page button back to Mark Page when paging in inbox
---------------------------------------------------
function EasyMail.ResetMarkPage()
    CheckPage = true;
    EasyMail.InboxUpdate();
end

---------------------------------------------------
-- EasyMail.MatchTemplate
-- Determine if a string matches a Blizzard text template
---------------------------------------------------
function EasyMail.MatchTemplate(template, str)
    local loc = strfind(template, "%s", 1, true);
    local front = strsub(template, 1, loc - 1);
    local back = strsub(template, loc + 2);

    local matchfront = (strsub(str, 1, strlen(front)) == front);
    local matchback = (strsub(str, strlen(str) - strlen(back) + 1) == back);

    return (matchfront and matchback);
end

---------------------------------------------------
-- EasyMail.PrintMoney
-- Output money received from mail
---------------------------------------------------
function EasyMail.PrintMoney()
    local fromtext = "";
    local auctiontext = AUCTION_SOLD_MAIL_SUBJECT;
    local subject = OpenMailSubject:GetText();

    local loc = strfind(auctiontext, "%s", 1, true);
    local front = strsub(auctiontext, 1, loc - 1);
    local back = strsub(auctiontext, loc + 2);

    if (subject and EasyMail.MatchTemplate(auctiontext, subject)) then
        fromtext = format(EASYMAIL_FROMAUCTION, gsub(subject, front .. "(.+)" .. back, "%1"));
    else
        fromtext = format(EASYMAIL_FROM, OpenMailSender.Name:GetText());
    end

    EasyMail.Print("|cffffff00" ..
                       format(EASYMAIL_RECEIVEMONEY, EasyMail.GetLongMoneyString(OpenMailFrame.money), fromtext));
end

---------------------------------------------------
-- EasyMail.PrintTotal
-- Output money received from mail
---------------------------------------------------
function EasyMail.PrintTotal()
    EasyMail.Print("|cffffff00" ..
                       format(EASYMAIL_TOTALMONEY, HIGHLIGHT_FONT_COLOR_CODE .. EasyMail.GetLongMoneyString(totalMoney)));
end

---------------------------------------------------
-- EasyMail.MoneySubject
-- Set the subject of a new mail to automatically indicate amount sent
---------------------------------------------------
function EasyMail.MoneySubject()
    if (moneySubject or SendMailSubjectEditBox:GetText() == "") then
        local copper = MoneyInputFrame_GetCopper(SendMailMoney)

        if (copper > 0) then
            SendMailSubjectEditBox:SetText(format(EASYMAIL_MONEYSUBJECT, EasyMail.GetShortMoneyString(copper)));
            moneySubject = true;
        else
            SendMailSubjectEditBox:SetText("");
            moneySubject = false;
        end
    end
end

---------------------------------------------------
-- EasyMail.GetLongMoneyString
-- Return a long string version of an amount in copper
---------------------------------------------------
function EasyMail.GetLongMoneyString(money)
    local moneytext = "";

    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
    local copper = mod(money, COPPER_PER_SILVER);

    if (copper > 0) then
        moneytext = copper .. " " .. easyMail_Copper;
    end

    if (silver > 0) then
        if (copper > 0) then
            moneytext = ", " .. moneytext;
        end

        moneytext = silver .. " " .. easyMail_Silver .. moneytext
    end

    if (gold > 0) then
        if (copper > 0 or silver > 0) then
            moneytext = ", " .. moneytext;
        end

        moneytext = gold .. " " .. easyMail_Gold .. moneytext
    end

    return moneytext;
end

---------------------------------------------------
-- EasyMail.GetShortMoneyString
-- Return a short string version of an amount in copper
---------------------------------------------------
function EasyMail.GetShortMoneyString(money)
    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
    local copper = mod(money, COPPER_PER_SILVER);

    local copperString = "";
    if (copper > 0) then
        copperString = copper .. EasyMail.Lower(strsub(easyMail_Copper, 1, 1));
    end

    local silverString = "";
    if (silver > 0) then
        silverString = silver .. EasyMail.Lower(strsub(easyMail_Silver, 1, 1));
        if (copper > 0) then
            silverString = silverString .. " ";
        end
    end

    local goldString = "";
    if (tonumber(gold) > 0) then
        goldString = gold .. EasyMail.Lower(strsub(easyMail_Gold, 1, 1));
        if (copper > 0 or silver > 0) then
            goldString = goldString .. " ";
        end
    end
    return goldString .. silverString .. copperString;
end

---------------------------------------------------
-- EasyMail.Tooltip
-- Show the mail text in the inbox item tooltip
---------------------------------------------------
function EasyMail.Tooltip(self)
    if (EasyMail_SavedVars.TextTooltip ~= "Y") then
        return;
    end

    if (not GameTooltip:IsOwned(self)) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    end

    bodyText = GetInboxText(self.index);

    if (bodyText and strfind(bodyText, "%S")) then
        if (self.hasItem or self.money or self.cod) then
            GameTooltip:AddLine(" ");
        end

        GameTooltip:AddLine("Mail Text");

        local lines = {strsplit("\n", bodyText)};
        local t;

        for t = 1, #lines do
            local line;
            local remainder = lines[t];

            while (remainder) do
                if (strlen(remainder) > maxTooltipWidth) then
                    local lastchar, nextstart;
                    local lastspace = EasyMail.ReverseFind(strsub(remainder, 1, maxTooltipWidth + 1), " ");

                    if (lastspace and lastspace ~= maxTooltipWidth + 1) then
                        lastchar = lastspace - 1;
                        nextstart = lastspace + 1;
                    else
                        lastchar = maxTooltipWidth;
                        nextstart = lastchar +
                                        (((strsub(remainder, maxTooltipWidth + 1, maxTooltipWidth + 1) == " ") and 2) or
                                            1);
                    end

                    line = strsub(remainder, 1, lastchar);
                    remainder = strsub(remainder, nextstart);
                else
                    line = remainder;
                    remainder = nil;
                end

                GameTooltip:AddLine(line, .85, .85, .85);
            end
        end
    else
        GameTooltip:AddLine(EASYMAIL_NOTEXT, .85, .85, .85);
    end

    GameTooltip:Show();
end

---------------------------------------------------
-- EasyMail.ReverseFind
-- Locate the last occurrance of a char in a string
---------------------------------------------------
function EasyMail.ReverseFind(str, ch)
    local t;
    local location;

    for t = strlen(str), 1, -1 do
        if (strsub(str, t, t) == ch) then
            location = t;
            break
        end
    end

    return location;
end

---------------------------------------------------
-- EasyMail.OnTabPressed
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnTabPressed(self)
    if (EasyMail_SavedVars.BlizzList ~= "Y" or not AutoCompleteEditBox_OnTabPressed(self)) then
        EditBox_HandleTabbing(self, SEND_MAIL_TAB_LIST);
    end
end

---------------------------------------------------
-- EasyMail.OnEditFocusLost
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnEditFocusLost(self)
    if (EasyMail_SavedVars.BlizzList == "Y") then
        AutoCompleteEditBox_OnEditFocusLost(self);
    end

    EditBox_ClearHighlight(self);
end

---------------------------------------------------
-- EasyMail.OnCharComposition
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnCharComposition(self, text)
    if (EasyMail_SavedVars.BlizzList ~= "Y") then
        EasyMail.AutoComplete(self, text);
    end
end

---------------------------------------------------
-- EasyMail.OnChar
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnChar(self, text)
    if (EasyMail_SavedVars.BlizzList == "Y") then
        AutoCompleteEditBox_OnChar(self, text);
        return;
    end

    if (not self:IsInIMECompositionMode()) then
        EasyMail.AutoComplete(self, text);
    end
end

---------------------------------------------------
-- EasyMail.OnEnterPressed
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnEnterPressed(self)
    if (EasyMail_SavedVars.BlizzList ~= "Y" or not AutoCompleteEditBox_OnEnterPressed(self)) then
        SendMailSubjectEditBox:SetFocus();
    end
end

---------------------------------------------------
-- EasyMail.OnEscapePressed
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnEscapePressed(self)
    if (EasyMail_MailDropdown:IsVisible()) then
        EasyMail_MailDropdown:Hide();
        return;
    end

    if (EasyMail_SavedVars.BlizzList ~= "Y" or not AutoCompleteEditBox_OnEscapePressed(self)) then
        EditBox_ClearFocus(self);
    end
end

---------------------------------------------------
-- EasyMail.OnTextChanged
-- Standard Blizzard or custom auto-complete
---------------------------------------------------
function EasyMail.OnTextChanged(self, userInput)
    if (EasyMail_SavedVars.BlizzList == "Y") then
        AutoCompleteEditBox_OnTextChanged(self, userInput);
    end

    SendMailFrame_CanSend(self);
end

---------------------------------------------------
-- EasyMail.AutoComplete
-- Build name in addressee field while typing
---------------------------------------------------
function EasyMail.AutoComplete(self, char, skipFriends, skipGuild)
    local text = self:GetText();
    local textlen = strlen(text);

    if (textlen < 1) then
        return;
    end

    local numFriends, name;

    if (EasyMail_SavedVars.Inclusive == "Y") then
        -- new inclusive search
        local namelist = {};

        for i = 1, #sortedList do
            tinsert(namelist, sortedList[i]);
        end

        if (not skipFriends) then
            for i = 1, BNGetNumFriends() do
                local gameInfo;

                if (EasyMail.isRetail) then
                    local accountInfo = C_BattleNet.GetAccountInfoByID(i);

                    if (accountInfo) then
                        gameInfo = accountInfo.gameAccountInfo;
                    end
                else
                    gameInfo = select(6, BNGetFriendInfo(i));
                end

                if (gameInfo) then
                    local name, realm;

                    if (EasyMail.isRetail) then
                        name = gameInfo.characterName;
                        realm = gameInfo.realmName;

                        if (not realm or strlen(realm) < 1) then
                            name = nil;
                        end
                    else
                        _, name, _, realm = BNGetGameAccountInfo(gameInfo);

                        if (not realm or strlen(realm) < 1 or realm ~= RemoveSpaces(curRealm)) then
                            name = nil;
                        end
                    end

                    if (name and strlen(name) > 0) then
                        if (realm and strlen(realm) > 0 and realm ~=
                            ((EasyMail.isRetail and curRealm) or RemoveSpaces(curRealm))) then
                            name = name .. "-" .. realm;
                        end

                        if (not tContains(namelist, name)) then
                            tinsert(namelist, name);
                        end
                    end
                end
            end

            numFriends = C_FriendList.GetNumFriends();
            if (numFriends > 0) then
                for i = 1, numFriends do
                    name = C_FriendList.GetFriendInfoByIndex(i).name;
                    if (name and not tContains(namelist, name)) then
                        tinsert(namelist, name);
                    end
                end
            end
        end

        if (not skipGuild) then
            numFriends = GetNumGuildMembers(true); -- true to include offline members
            if (numFriends > 0) then
                for i = 1, numFriends do
                    name = Ambiguate(GetGuildRosterInfo(i), "none");
                    if (name and not tContains(namelist, name)) then
                        tinsert(namelist, name);
                    end
                end
            end
        end

        sort(namelist);

        -- Check addressee list
        for i = 1, #namelist do
            if (strfind(EasyMail.Upper(namelist[i]), EasyMail.Upper(text), 1, 1) == 1) then
                self:SetText(namelist[i]);

                if (self:IsInIMECompositionMode()) then
                    self:HighlightText(textlen - strlen(char), -1);
                else
                    self:HighlightText(textlen, -1);
                end

                return;
            end
        end
    else
        -- Check addressee list
        for i = 1, #sortedList do
            if (strfind(EasyMail.Upper(sortedList[i]), EasyMail.Upper(text), 1, 1) == 1) then
                self:SetText(sortedList[i]);

                if (self:IsInIMECompositionMode()) then
                    self:HighlightText(textlen - strlen(char), -1);
                else
                    self:HighlightText(textlen, -1);
                end

                return;
            end
        end

        -- First check your friends list
        if (not skipFriends) then
            local fList = {};

            for i = 1, BNGetNumFriends() do
                local gameInfo;

                if (EasyMail.isRetail) then
                    local accountInfo = C_BattleNet.GetAccountInfoByID(i);

                    if (accountInfo) then
                        gameInfo = accountInfo.gameAccountInfo;
                    end
                else
                    gameInfo = select(6, BNGetFriendInfo(i));
                end

                if (gameInfo) then
                    local name, realm;

                    if (EasyMail.isRetail) then
                        name = gameInfo.characterName;
                        realm = gameInfo.realmName;

                        if (not realm or strlen(realm) < 1) then
                            name = nil;
                        end
                    else
                        _, name, _, realm = BNGetGameAccountInfo(gameInfo);

                        if (not realm or strlen(realm) < 1 or realm ~= RemoveSpaces(curRealm)) then
                            name = nil;
                        end
                    end

                    if (name and strlen(name) > 0) then
                        if (realm and strlen(realm) > 0 and realm ~=
                            ((EasyMail.isRetail and curRealm) or RemoveSpaces(curRealm))) then
                            name = name .. "-" .. realm;
                        end

                        tinsert(fList, name);
                    end
                end
            end

            numFriends = C_FriendList.GetNumFriends();
            if (numFriends > 0) then
                for i = 1, numFriends do
                    name = C_FriendList.GetFriendInfoByIndex(i).name;
                    if (name and not tContains(fList, name)) then
                        tinsert(fList, name);
                    end
                end
            end

            sort(fList);

            for i = 1, #fList do
                local name = fList[i];

                if (strfind(strupper(name), strupper(text), 1, 1) == 1) then
                    self:SetText(name);
                    if (self:IsInIMECompositionMode()) then
                        self:HighlightText(textlen - strlen(char), -1);
                    else
                        self:HighlightText(textlen, -1);
                    end
                    return;
                end
            end
        end

        -- No match, check your guild list
        if (not skipGuild) then
            numFriends = GetNumGuildMembers(true); -- true to include offline members
            if (numFriends > 0) then
                for i = 1, numFriends do
                    name = Ambiguate(GetGuildRosterInfo(i), "none");
                    if (name and (strfind(strupper(name), strupper(text), 1, 1) == 1)) then
                        self:SetText(name);
                        if (self:IsInIMECompositionMode()) then
                            self:HighlightText(textlen - strlen(char), -1);
                        else
                            self:HighlightText(textlen, -1);
                        end
                        return;
                    end
                end
            end
        end
    end
end

---------------------------------------------------
-- EasyMail.Forward
-- Make forwarding easier
---------------------------------------------------
function EasyMail.Forward()
    MailFrameTab_OnClick(nil, 2);
    SendMailNameEditBox:SetText("");
    local subject = OpenMailSubject:GetText();
    local prefix = EASYMAIL_FORWARD_PREFIX .. " ";
    if (strsub(subject, 1, strlen(prefix)) ~= prefix) then
        subject = prefix .. subject;
    end
    SendMailSubjectEditBox:SetText(subject);
    local bodytext = "";
    local currentText = GetInboxText(InboxFrame.openMailID);
    if (strfind(currentText, "%S")) then
        bodytext = "\n---\n" .. currentText;
    end
    -- SendMailBodyEditBox:SetText(bodytext);
    -- SendMailNameEditBox:SetFocus();
    -- SendMailBodyEditBox:SetCursorPosition(0);
    local editbox = (EasyMail.isRetail and SendMailBodyEditBox) or MailEditBox

    editbox:SetText(bodytext);
    editbox:SetFocus();
    editbox:SetCursorPosition(0);

    -- Set the send mode so the work flow can change accordingly
    SendMailFrame.sendMode = "reply";
end

---------------------------------------------------
-- EasyMail.OpenBags
-- Open bags when Send Mail tab is clicked
---------------------------------------------------
function EasyMail.OpenBags(self, tabID)
    if (tabID ~= 1) then
        OpenAllBags(MailFrame);
    end
end

---------------------------------------------------
-- EasyMail.SendMailFrameUpdate
-- Resize edit box properly when adding attachments (Blizzard UI bug)
---------------------------------------------------
function EasyMail.SendMailFrameUpdate()
    MailEditBox:SetSize(MailEditBox:GetWidth(), MailEditBox:GetTop() - SendMailHorizontalBarLeft2:GetTop() + 6)
end

---------------------------------------------------
-- EasyMail.Trim
-- Trim spaces from front and back of string (why doesn't strtrim work!?!?)
---------------------------------------------------
function EasyMail.Trim(str)
    return gsub(str, "%s*(.*)%s*", "%1");
end

---------------------------------------------------
-- EasyMail.NameCase
-- Force first letter of player name to uppercase, lower case the rest
---------------------------------------------------
function EasyMail.NameCase(instr)
    if (not strfind("koKRzhCNzhTW", GetLocale())) then
        local ch = strbyte(strsub(instr, 1, 1));
        local pos = 1;

        if (ch >= 240) then
            pos = 4;
        elseif (ch >= 224) then
            pos = 3;
        elseif (ch >= 192) then
            pos = 2;
        end

        return strupper(strsub(instr, 1, pos)) .. strlower(strsub(instr, pos + 1));
    end

    return instr;
end

---------------------------------------------------
-- EasyMail.Upper
-- Upper case only if casing is used in locale
---------------------------------------------------
function EasyMail.Upper(str)
    return ((strfind("koKRzhCNzhTW", GetLocale()) and str) or strupper(str));
end

---------------------------------------------------
-- EasyMail.Lower
-- Lower case only if casing is used in locale
---------------------------------------------------
function EasyMail.Lower(str)
    return ((strfind("koKRzhCNzhTW", GetLocale()) and str) or strlower(str));
end

---------------------------------------------------
-- EasyMail.PrintError
-- Output a message to Blizzard's error frame
---------------------------------------------------
function EasyMail.PrintError(errMsg)
    PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST);
    DEFAULT_CHAT_FRAME:AddMessage(EASYMAIL_ADDONNAME .. ": " .. errMsg, 1.0, 0.1, 0.1);
end

---------------------------------------------------
-- EasyMail.Print
-- Output a message to the chat frame
---------------------------------------------------
function EasyMail.Print(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage(msg, 0, 1, 0);
    end
end

-- UI Functions (Lemmoros)
function EASYMAIL_L_ShowAll(open, button)
    if button == "LeftButton" then
        local ml = EasyMail_Maillog
        local historyout = ""
        local spacer = "  "
        for i, j in pairs(ml) do
            if i > 9 then
                spacer = " "
            end
            if i > 99 then
                spacer = ""
            end
            --        historyout = historyout .. "\n|cffCA4D2B" .. EASYMAIL_L_MessageShort .. "" .. i .. " |r|cff9CBADA" .. ml[i].stamp .. "|r|cffFCE94F " .. EASYMAIL_L_To .. " |r|cff9CBADA" .. ml[i].mailto .. "|r|cffFCE94F " .. EASYMAIL_L_From .." |r|cff9CBADA" .. ml[i].creator .. "|r\n|cffFCE94F       " .. EASYMAIL_L_Subject .. " |r|cff9CBADA" .. ml[i].subject .. "|r\n"
            historyout =
                historyout .. "\n|cffAE0000" .. spacer .. i .. ".    |r|cff121377" .. ml[(#ml + 1 - i)].creator .. ", " ..
                    date("%Y-%m-%d %H:%M", ml[(#ml + 1 - i)].timestamp) .. "|r|cff204200 " .. EASYMAIL_L_To ..
                    " |r|cff121377" .. ml[(#ml + 1 - i)].mailto .. "|r\n|cff204200            " .. EASYMAIL_L_Subject ..
                    " |r|cff121377" .. ml[(#ml + 1 - i)].subject .. "|r\n"
        end
        EASYMAIL_L_Sowframe_resultframe:SetText(historyout)
        if open == true then
            if EASYMAIL_L_Sowframe_HistoryFrame:IsVisible() == true then
                EASYMAIL_L_Sowframe_HistoryFrame:Hide()
            else
                EASYMAIL_L_Sowframe_HistoryFrame:Show()
            end
        end
    end
    if button == "RightButton" then
        -- InterfaceOptionsFrame_OpenToCategory(EASYMAIL_ADDONNAME)
        -- InterfaceOptionsFrame_OpenToCategory(EASYMAIL_ADDONNAME)
        SettingsPanel:Open();
        SettingsPanel:SelectCategory(easymail_options_category, true);
    end
end

function EASYMAIL_L_TTLast()
    GameTooltip:SetOwner(EasyMail_L_HistoryOpen, "ANCHOR_BOTTOMRIGHT");
    GameTooltip:SetText("|cff40FB40EasyMail|r", nil, nil, nil, nil, 1);
    local ml = EasyMail_Maillog
    if table.getn(ml) ~= 0 then
        --        GameTooltip:AddLine(("|cffFCE94F\n".. EASYMAIL_L_LMS .. "\n" .. EASYMAIL_L_Date .. " |r|cff9CBADA" .. date("%Y-%m-%d %H:%M",ml[table.getn(ml)].timestamp) .. "|r\n|cffFCE94F" .. EASYMAIL_L_To .. " |r|cff9CBADA" .. ml[table.getn(ml)].mailto .. "|r\n|cffFCE94F" .. EASYMAIL_L_From .. " |r|cff9CBADA" .. ml[table.getn(ml)].creator .. "|r\n|cffFCE94F" .. EASYMAIL_L_Subject .. " |r|cff9CBADA" .. ml[table.getn(ml)].subject .. "|r"), 1, 1, 1)
        GameTooltip:AddLine(("|cffFCE94F" .. EASYMAIL_L_LMS .. "|r\n\n"), 1, 1, 1)
        GameTooltip:AddDoubleLine(("|cffFCE94F" .. EASYMAIL_L_Date .. "|r"),
            ("|cff9CBADA" .. date("%Y-%m-%d %H:%M", ml[table.getn(ml)].timestamp)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(("|cffFCE94F" .. EASYMAIL_L_To .. "|r"), ("|cff9CBADA" .. ml[table.getn(ml)].mailto),
            1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(("|cffFCE94F" .. EASYMAIL_L_From .. "|r"),
            ("|cff9CBADA" .. ml[table.getn(ml)].creator), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(("|cffFCE94F" .. EASYMAIL_L_Subject .. "|r"),
            ("|cff9CBADA" .. ml[table.getn(ml)].subject), 1, 1, 1, 1, 1, 1)
        -- EASYMAIL_L_LastMail="|cffFCE94F\n".. EASYMAIL_L_LMS .. "|r\n|cff9CBADA" .. date("%Y-%m-%d %H:%M",ml[table.getn(ml)].timestamp) .. "|r\n|cffFCE94F" .. EASYMAIL_L_To .. " |r|cff9CBADA" .. ml[table.getn(ml)].mailto .. "|r\n|cffFCE94F" .. EASYMAIL_L_From .. " |r|cff9CBADA" .. ml[table.getn(ml)].creator .. "|r\n|cffFCE94F" .. EASYMAIL_L_Subject .. " |r|cff9CBADA" .. ml[table.getn(ml)].subject .. "|r\n\n" .. EASYMAIL_L_OpenList
    else
        -- GameTooltip:AddLine(" \n" ..EASYMAIL_L_NoMessages, 1, 1, 1)
        -- EASYMAIL_L_LastMail = "|cffCA4D2BEasyMail|r\n" .. EASYMAIL_L_NoMessages
    end
    GameTooltip:AddLine(("|cffFFD697 \n" .. EASYMAIL_L_OpenList .. "|r"), 1, 1, 1, 1)
    GameTooltip:Show()
    -- return EASYMAIL_L_LastMail
end

-- UI Functions end (Lemmoros)

-- slash commands (Lemmoros)

SLASH_EASYMAIL1 = '/easymail'
function SlashCmdList.EASYMAIL(msg)
    if msg ~= {} and msg ~= "" then
        if msg == 'p' then
            local ml = EasyMail_Maillog
            EASYMAIL_L_ShowAll(true, "LeftButton")
            --		    for i, j in pairs(ml) do
            --		        print("|cffCA4D2BEasyMail|r|cffFCE94F " .. EASYMAIL_L_MessageShort .. " " .. i .. ": " .. EASYMAIL_L_SENT .. " |r|cff9CBADA" .. ml[i].stamp .. "|r|cffFCE94F " .. EASYMAIL_L_To .. " |r|cff9CBADA" .. ml[i].mailto .. "|r|cffFCE94F " .. EASYMAIL_L_From .. " |r|cff9CBADA" .. ml[i].creator .. "|r|cffFCE94F " .. EASYMAIL_L_Subject .. " |r|cff9CBADA" .. ml[i].subject .. "|r")
            --           end
            --			print("all mails")
        elseif msg == 'l' then
            local ml = EasyMail_Maillog
            if table.getn(ml) ~= 0 then
                print("|cff40FB40EasyMail|r|cffFCE94F: " .. EASYMAIL_L_LMS .. " |r|cff9CBADA" ..
                          date("%Y-%m-%d %H:%M", ml[table.getn(ml)].timestamp) .. "|r|cffFCE94F " .. EASYMAIL_L_To ..
                          " |r|cff9CBADA" .. ml[table.getn(ml)].mailto .. "|r|cffFCE94F " .. EASYMAIL_L_From ..
                          " |r|cff9CBADA" .. ml[table.getn(ml)].creator .. "|r|cffFCE94F " .. EASYMAIL_L_Subject ..
                          " |r|cff9CBADA" .. ml[table.getn(ml)].subject .. "|r")
            end
        end
    else
        -- InterfaceOptionsFrame_OpenToCategory(EASYMAIL_ADDONNAME)
        -- InterfaceOptionsFrame_OpenToCategory(EASYMAIL_ADDONNAME)
        SettingsPanel:Open();
        SettingsPanel:SelectCategory(easymail_options_category, true);
    end
end
-- end slash commands (Lemmoros)
