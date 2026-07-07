local Notific = CreateFrame("Frame");

Notific:RegisterEvent("CHAT_MSG_WHISPER");
Notific:RegisterEvent("CHAT_MSG_BN_WHISPER");
Notific:SetScript("OnEvent", function (self, event, msg, sender)
    PlaySoundFile("Interface\\Addons\\Notific\\message.ogg", "Master");
end);
