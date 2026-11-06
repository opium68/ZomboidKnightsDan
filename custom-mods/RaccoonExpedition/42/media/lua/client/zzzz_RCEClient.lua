require 'RCE/Config'
require 'ISUI/ISButton'
require 'ISUI/ISLabel'
RCE.Client={status=nil,ui=nil}
local U=RCE.Client
local fallback={
 Entry='Enter Raccoon City',Exit='Return from Raccoon City (10s)',
 Preparing='Preparing entry',Extracting='Preparing return',Transferred='Transferring',
 Busy='Already preparing',BridgeMissing='Expedition transport is unavailable',
 LeaveVehicle='Leave your vehicle first',AlreadyInside='Already inside Raccoon City',
 ComputerRequired='Use a nearby computer',NoEntry='No safe entry available. Try again.',
 NotAtExit='Move inside an extraction zone',NoReturnPosition='Return position unavailable',
 EntryCancelled='Entry cancelled',Cancelled='Cancelled',Hit='Return cancelled: you were hit',
 LeftExit='Return cancelled: outside extraction zone',PreparationTimeout='Destination preparation timed out',
 NoSafeReturn='No safe return position. You have not moved.',
 TransferFailed='Transfer failed. Try again.',Dead='Cancelled: character died',
 SafetyCheck='Checking the destination...',CountdownSuffix=' (%1s)',
}
local function tr(code,arg)
 local key='IGUI_RCE_'..code
 local text=arg~=nil and getText(key,tostring(arg)) or getText(key)
 if not text or text==key then
  text=fallback[code] or tostring(code)
  if arg~=nil then text=text:gsub('%%1',tostring(arg)) end
 end
 return text
end
function U.request(player,command) sendClientCommand(player,RCE.Config.module,command,{}) end
Events.OnServerCommand.Add(function(module,command,args)
 if module~=RCE.Config.module or command~='Status' then return end
 local text=tr(args.code)
 if args.code=='Preparing' or args.code=='Extracting' then
  text=text..tr('CountdownSuffix',args.remaining or 0)
  if args.remaining==0 then text=tr('SafetyCheck') end
 end
 U.status=text;U.statusAt=getTimestampMs()
 if U.ui and U.ui.RCELabel then U.ui.RCELabel:setName(text) end
 if args.code=='Transferred' and U.ui then
  if U.ui.onClose then U.ui:onClose() end
  U.ui=nil
 end
end)
function U.installMainMenu()
 if type(linuxUI)~='table' or type(linuxUI.initialise)~='function' or type(linuxUI.onPrompt)~='function' then return false end
 if linuxUI.RCEPatched then return true end
 linuxUI.RCEPatched=true
 local initialise,prompt=linuxUI.initialise,linuxUI.onPrompt
 linuxUI.initialise=function(self,...)
  initialise(self,...)
  local button=ISButton:new(self.width*0.20,self.height*0.62,self.width*0.05,self.height*0.025,
   tr('Entry'),self,function(ui)
    U.ui=ui;U.request(ui.player,'Enter')
   end)
  button.backgroundColor={r=0,g=0,b=0,a=0.5}
  button.textColor={r=0,g=1,b=0,a=1}
  button.borderColor={r=0,g=0,b=0,a=0}
  button:setVisible(false);button:initialise()
  self.topBar:addChild(button);self.RCEEntry=button
  local label=ISLabel:new(self.width*0.20,self.height*0.66,self.height*0.025,'',0,1,0,1,UIFont.Small,true)
  label:setVisible(false);label:initialise()
  self.topBar:addChild(label);self.RCELabel=label
  print('[RCE] Main menu expedition entry created')
 end
 linuxUI.onPrompt=function(self,...)
  prompt(self,...)
  self.RCEEntry:setVisible(true);self.RCELabel:setVisible(true)
 end
 print('[RCE] Main menu expedition entry installed')
 return true
end
U.installMainMenu()
Events.OnGameStart.Add(U.installMainMenu)
Events.OnCreatePlayer.Add(U.installMainMenu)
local function installWhenReady()
 if U.installMainMenu() then Events.OnTick.Remove(installWhenReady) end
end
Events.OnTick.Add(installWhenReady)
Events.OnFillWorldObjectContextMenu.Add(function(playerIndex,context,objects,test)
 if test then return end
 local player=getSpecificPlayer(playerIndex)
 if player and RCE.exitAt(RCE.position(player)) then
  context:addOption(tr('Exit'),player,function(p) U.request(p,'Exit') end)
 end
end)
Events.OnPostUIDraw.Add(function()
 if not U.status or getTimestampMs()-U.statusAt>15000 then return end
 local p=getPlayer();if not p or not RCE.inside(p:getX(),p:getY()) then return end
 getTextManager():DrawStringCentre(UIFont.Medium,getCore():getScreenWidth()/2,80,U.status,1,1,1,1)
end)
