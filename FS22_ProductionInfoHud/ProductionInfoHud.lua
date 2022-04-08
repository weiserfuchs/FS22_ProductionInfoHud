--- Anzeige für Produktionen in einem HUD by achimobil@hotmail.com
--- Fehlermeldungen und Verbesserungsvorschläge gerne im Discord Kanal des Mods: https://discord.gg/Va7JNnEkcW

ProductionInfoHud = {}

ProductionInfoHud.metadata = {
    title = "ProductionInfoHud",
    notes = "Anzeige für Produktionen in einem HUD",
    author = "Achimobil",
    info = "Das verändern und wiederöffentlichen, auch in Teilen, ist untersagt und wird abgemahnt."
};
ProductionInfoHud.modDir = g_currentModDirectory;
ProductionInfoHud.firstRun = false;
ProductionInfoHud.isClient = false;
ProductionInfoHud.timePast = 0;
ProductionInfoHud.overlay = Overlay.new(HUD.MENU_BACKGROUND_PATH, 0, 0, 0, 0);
ProductionInfoHud.colors = {};
ProductionInfoHud.colors.WHITE =    {1.000, 1.000, 1.000, 1}
ProductionInfoHud.colors.ORANGE =   {0.840, 0.270, 0.020, 1}
ProductionInfoHud.colors.RED =      {0.580, 0.040, 0.020, 1}
ProductionInfoHud.colors.YELLOW =   {0.980, 0.420, 0.000, 1}
ProductionInfoHud.PossiblePositions = {"TopCenter", "BelowHelp", "BelowVehicleInspector"}
ProductionInfoHud.PossibleMaxLines = {"2", "3", "4", "5", "6", "7", "8", "9", "10"}

function ProductionInfoHud:init()
    ProductionInfoHud.isClient = g_currentMission:getIsClient();
    ProductionInfoHud.isInit = true;
    
    ProductionInfoHud.messageCenter = g_messageCenter;
    ProductionInfoHud.i18n = g_i18n;
    ProductionInfoHud.inputManager = g_gui.inputManager;
    
    -- default settings einstellen
    ProductionInfoHud.settings = {};
    ProductionInfoHud.settings["display"] = {};
    ProductionInfoHud.settings["display"]["showType"] = "ALL";
    ProductionInfoHud.settings["display"]["position"] = 1;
    ProductionInfoHud.settings["display"]["showFullAnimals"] = true;
    ProductionInfoHud.settings["display"]["maxLines"] = 5;
    
    ProductionInfoHud:LoadSettings();
       
    self:mergeModTranslations(ProductionInfoHud.i18n)
       
    -- sie einstellungsseite
    local settingsFrame = ProductionInfoHudFrame.new(ProductionInfoHud, ProductionInfoHud.i18n)
    g_gui:loadGui(ProductionInfoHud.modDir .. "Gui/ProductionInfoHudFrame.xml", "ProductionInfoHudFrame", settingsFrame, true)
    
    -- Das Menü wo die seiten rein kommen
    ProductionInfoHud.menu = ProductionInfoHudGUI:new(ProductionInfoHud.messageCenter, ProductionInfoHud.i18n, ProductionInfoHud.inputManager);
    ProductionInfoHud.gui = g_gui:loadGui(ProductionInfoHud.modDir .. "Gui/ProductionInfoHudGui.xml", "ProductionInfoHudGUI", ProductionInfoHud.menu)
    
    -- Aufrufen nach init, da erst an isclient gesetzt ist und sonst die binding nicht aktiv ist bevor man in ein auto einsteigt
    ProductionInfoHud:registerActionEvents()

    -- overwrite the InfoMessageHUD method to move it to a good location, when it is installed    
    if g_modIsLoaded["FS22_InfoMessageHUD"] then
        print("Info: ProductionInfoHud override position of InfoMessageHUD");
        local mod2 = getfenv(0)["FS22_InfoMessageHUD"];
        ProductionInfoHud.InfoMessageHUD = mod2.InfoMessageHUD;        

        function ProductionInfoHud.InfoMessageHUD:renderText(x, y, size, text, bold, colorId)
            x = x + 0.4;

            setTextColor(unpack(ProductionInfoHud.InfoMessageHUD.Colors[colorId][2]))
            setTextBold(bold)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x, y, size, text)
            
            -- Back to defaults
            setTextBold(false)
            setTextColor(unpack(ProductionInfoHud.InfoMessageHUD.Colors[1][2])) --Back to default color which is white
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
    end
end

function ProductionInfoHud:mergeModTranslations(i18n)
    -- We can copy all our translations to the global table because we prefix everything with guidanceSteering_
    -- Thanks for blocking the getfenv Giants..
    -- and my thanks to Wopster for a solution that also works for my problems, better than my solution to loop trough all elements and translater afterwards a second time
    local modEnvMeta = getmetatable(_G)
    local env = modEnvMeta.__index

    local global = env.g_i18n.texts
    for key, text in pairs(i18n.texts) do
        global[key] = text
    end
end

function ProductionInfoHud:registerActionEvents()
    if ProductionInfoHud.isClient then
        _, ProductionInfoHud.eventIdToggle = g_inputBinding:registerActionEvent(InputAction.TOGGLE_GUI, ProductionInfoHud, ProductionInfoHud.ToggleGui, false, true, false, true)
        _, ProductionInfoHud.eventIdOPenGui = g_inputBinding:registerActionEvent(InputAction.OPEN_GUI, ProductionInfoHud, ProductionInfoHud.OpenGui, false, true, false, true)
    end
end

function ProductionInfoHud:ToggleGui()
    if ProductionInfoHud.settings["display"]["showType"] == "ALL" then 
        ProductionInfoHud.settings["display"]["showType"] = "NONE"
    else 
        ProductionInfoHud.settings["display"]["showType"] = "ALL"
    end
end

function ProductionInfoHud:OpenGui()
print("ProductionInfoHud:OpenGui")
    -- hier die Einstellungen öffnen
    if g_gui.currentGui == nil then
        g_gui:showGui("ProductionInfoHudGUI")
    end
    
end

function ProductionInfoHud:loadMap(name)
    -- ActionEvents registrieren
    FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, ProductionInfoHud.registerActionEvents);
end

function ProductionInfoHud:update(dt)

    if not ProductionInfoHud.isInit then ProductionInfoHud:init(); end
    
    if not ProductionInfoHud.isClient then return end
    
    ProductionInfoHud.timePast = ProductionInfoHud.timePast + dt;
    
    if ProductionInfoHud.timePast >= 5000 then
        ProductionInfoHud.timePast = 0;
        ProductionInfoHud:refreshProductionsTable();
    end
    
    if not ProductionInfoHud.firstRun then
        -- print("Testoutput")
        -- DebugUtil.printTableRecursively(g_currentMission,"_",0,1)        
        ProductionInfoHud.firstRun = true;
    end
end

function ProductionInfoHud:refreshProductionsTable()
        
        local farmId = g_currentMission.player.farmId;
        local myProductions = {}
        
        if g_currentMission.productionChainManager.farmIds[farmId] ~= nil and g_currentMission.productionChainManager.farmIds[farmId].productionPoints ~= nil then
            for _, productionPoint in pairs(g_currentMission.productionChainManager.farmIds[farmId].productionPoints) do
-- print("productionPoint")
-- DebugUtil.printTableRecursively(productionPoint,"_",0,2)
                
                for fillTypeId, fillLevel in pairs(productionPoint.storage.fillLevels) do
                    local productionItem = {}
                    productionItem.name = productionPoint.owningPlaceable:getName();
                    productionItem.fillTypeId = fillTypeId
                    productionItem.needPerHour = 0
                    productionItem.hoursLeft = 0
                    productionItem.fillLevel = fillLevel
                    productionItem.capacity = productionPoint.storage.capacities[fillTypeId]
                    productionItem.isInput = false;
                    
                    -- prüfen ob input type
                    if productionPoint.inputFillTypeIds[fillTypeId] ~= nil then
                        productionItem.isInput = productionPoint.inputFillTypeIds[fillTypeId];
                    end
                    
                    if productionItem.capacity == 0 then 
                        productionItem.capacityLevel = 0
                    elseif productionItem.capacity == nil then
                        productionItem.capacityLevel = 0
                        print("Error: No storage for '" .. g_currentMission.fillTypeManager.fillTypes[fillTypeId].name .. "' in productionPoint but defined to used. Has to be fixed in '" .. productionPoint.owningPlaceable.customEnvironment .."'.")
                    else
                        productionItem.capacityLevel = productionItem.fillLevel / productionItem.capacity;
                    end
                    productionItem.fillTypeTitle = g_currentMission.fillTypeManager.fillTypes[fillTypeId].title;
                    
                    for _, production in pairs(productionPoint.activeProductions) do
                        for _, input in pairs(production.inputs) do
                            -- status 3 = läuft nicht weil ausgang voll
                            if input.type == fillTypeId then
                                productionItem.isInput = true;
                                if production.status ~= 3 then
                                    productionItem.needPerHour = productionItem.needPerHour + (production.cyclesPerHour * input.amount)
                                end
                            end
                        end
                    end

                    if (productionItem.fillLevel ~= 0) and (productionItem.needPerHour ~= 0) then
                        -- hier die anzahl der Tage pro Monat berücksichtigen
                        productionItem.hoursLeft = productionItem.fillLevel / productionItem.needPerHour * g_currentMission.environment.daysPerPeriod;
                    end
                    
                    if (productionItem.needPerHour > 0 and productionItem.capacityLevel <= 0.5 and productionItem.hoursLeft <= (48 * g_currentMission.environment.daysPerPeriod)) then 
                        table.insert(myProductions, productionItem)
                    end
                    
                    -- Ausgangslager voll, dann speziell eintragen
                    if (productionItem.needPerHour == 0 and productionItem.capacityLevel >= 0.99 and not productionItem.isInput) then 
                        productionItem.hoursLeft = -1;
                        table.insert(myProductions, productionItem)
                    end
                end
            end
        end
        
        -- Tiere
        for _, placeable in pairs(g_currentMission.husbandrySystem.placeables) do
            if placeable.ownerFarmId == farmId then
                
                -- Futter der Tiere als gesamtes pro Stall
                local productionItem = {}
                productionItem.name = placeable:getName();
                -- productionItem.fillTypeId = fillTypeId
                productionItem.needPerHour = placeable.spec_husbandryFood.litersPerHour;
                productionItem.hoursLeft = 0
                productionItem.fillLevel = placeable:getTotalFood();
                productionItem.capacity = placeable:getFoodCapacity();
                productionItem.isInput = true;
                
                if productionItem.capacity == 0 then 
                    productionItem.capacityLevel = 0
                elseif productionItem.capacity == nil then
                    productionItem.capacityLevel = 0
                    print("Error: No storage for '" .. g_currentMission.fillTypeManager.fillTypes[fillTypeId].name .. "' in productionPoint but defined to used. Has to be fixed in '" .. productionPoint.owningPlaceable.customEnvironment .."'.")
                else
                    productionItem.capacityLevel = productionItem.fillLevel / productionItem.capacity;
                end
                productionItem.fillTypeTitle = placeable.spec_husbandryFood.info.title;

                if (productionItem.fillLevel ~= 0) and (productionItem.needPerHour ~= 0) then
                    -- hier die anzahl der Tage pro Monat berücksichtigen
                    productionItem.hoursLeft = productionItem.fillLevel / productionItem.needPerHour * g_currentMission.environment.daysPerPeriod;
                end
                    
                if (productionItem.needPerHour > 0 and productionItem.capacityLevel <= 0.5 and productionItem.hoursLeft <= (48 * g_currentMission.environment.daysPerPeriod)) then 
                    table.insert(myProductions, productionItem)
                end
                
                -- Tiere voll, also muss was verkauft werden
                if ProductionInfoHud.settings["display"]["showFullAnimals"] and placeable:getNumOfFreeAnimalSlots() == 0 then
                    local productionItem = {}
                    productionItem.name = placeable:getName();
                    -- productionItem.fillTypeId = fillTypeId
                    productionItem.needPerHour = 0;
                    productionItem.hoursLeft = 0
                    productionItem.fillLevel = 0;
                    productionItem.capacity = 0;
                    productionItem.isInput = false;
                    if (placeable.spec_husbandryPallets ~= nil) then
                        productionItem.fillTypeTitle =  placeable.spec_husbandryPallets.animalTypeName
                    else
                        productionItem.fillTypeTitle = g_i18n:getText("helpLine_animals") 
                    end
                    productionItem.capacityLevel = 0;
                    productionItem.hoursLeft = -1;
                    table.insert(myProductions, productionItem)
                end
            end
        end

        table.sort(myProductions, compPrductionTable)
        
        ProductionInfoHud.productionDataSorted = myProductions;
        
        -- print("myProductions")
        -- DebugUtil.printTableRecursively(myProductions,"_",0,2)
end

function compPrductionTable(w1,w2)
    -- Zum Sortieren der Ausgabeliste nach Zeit
    if w1.hoursLeft == w2.hoursLeft and w1.name < w2.name then
        return true
    end
    if w1.hoursLeft < w2.hoursLeft then
        return true
    end
end

function ProductionInfoHud:draw()

    if not ProductionInfoHud.isClient then return end
    if ProductionInfoHud.productionDataSorted == nil then return end
    
    if ProductionInfoHud.settings["display"]["showType"] == "NONE" then 
        return
    end
    
    local lineCount = 0;
    local maxLines = tonumber(ProductionInfoHud.PossibleMaxLines[ProductionInfoHud.settings["display"]["maxLines"]]);
    local additionalLines = 0;
    local productionOutputTable = {}
    local posX = 0.413;
    local posY = 0.97;
    local textSize = 12/1000;
    local totalTextHeigh = 0;
    local maxTextWidth = 0;
    
    -- 1-"TopCenter", 2-"BelowHelp", 3-"BelowVehicleInspector"
    -- Startpunkt setzen anhand der Einstellungen
    if ProductionInfoHud.settings["display"]["position"] == 2 or (ProductionInfoHud.settings["display"]["position"] == 3 and g_currentMission.vehicleInspector ~= nil and not g_currentMission.vehicleInspector:getVisible()) then
        if (g_currentMission.hud.inputHelp.overlay.visible == true) then
            -- move under Help Dialog, when help visible or when VI is selected and not visible
            posX = g_currentMission.hud.inputHelp.overlay.x;
            posY = g_currentMission.hud.inputHelp.overlay.y - 0.04;
        else
            posX = 0.013;
            posY = 0.95;
        end
    elseif ProductionInfoHud.settings["display"]["position"] == 3 and g_currentMission.vehicleInspector ~= nil and  g_currentMission.vehicleInspector:getVisible() then
    
            local viPosition = g_currentMission.vehicleInspector:getPosition()
            
            posX = viPosition.x;
            posY = viPosition.y - g_currentMission.vehicleInspector.global.height[g_currentMission.vehicleInspector.global.viewModus]-0.01;
    end
    
    local posYStart = posY;

    for _, productionData in pairs(ProductionInfoHud.productionDataSorted) do
        if (lineCount < maxLines) then
            
            lineCount = lineCount + 1;
        
            local productionOutputItem = {}
            productionOutputItem.productionPointName = productionData.name
            productionOutputItem.fillTypeTitle = productionData.fillTypeTitle
            productionOutputItem.TextColor = ProductionInfoHud.colors.WHITE;
            
            if productionData.hoursLeft == -1 then
                productionOutputItem.TimeLeftString = g_i18n:getText("Full");
                productionOutputItem.TextColor = ProductionInfoHud.colors.RED;
            elseif productionData.hoursLeft == 0 then
                productionOutputItem.TimeLeftString = g_i18n:getText("Empty");
                productionOutputItem.TextColor = ProductionInfoHud.colors.ORANGE;
            else
                local days = math.floor(productionData.hoursLeft / 24);
                local hoursLeft = productionData.hoursLeft - (days * 24);
                local hours = math.floor(hoursLeft);
                local hoursLeft = hoursLeft - hours;
                local minutes = math.floor(hoursLeft * 60);
                if(minutes <= 9) then minutes = "0" .. minutes end;
                local timeString = "";
                if (days ~= 0) then 
                    timeString = days .. "d ";
                else
                    productionOutputItem.TextColor = ProductionInfoHud.colors.YELLOW;
                end
                timeString = timeString .. hours .. ":" .. minutes;
                productionOutputItem.TimeLeftString = timeString;
            end
            table.insert(productionOutputTable, productionOutputItem)
        else
            additionalLines = additionalLines + 1;
        end
    end
        
    for _, productionOutputItem in pairs(productionOutputTable) do
        posY = posY - textSize;
                        
        local textLine = (productionOutputItem.productionPointName .. " - " .. productionOutputItem.fillTypeTitle .. " - " .. productionOutputItem.TimeLeftString);
        totalTextHeigh = totalTextHeigh + getTextHeight(textSize, textLine)
        local textWidth = getTextWidth(textSize, textLine);
        if (textWidth > maxTextWidth) then maxTextWidth = textWidth; end
        
        -- farben von oben benutzen
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextColor(unpack(productionOutputItem.TextColor));                                
        setTextBold(false);
        renderText(posX,posY,textSize,textLine);
    end
        
    if (additionalLines > 0) then
        posY = posY - textSize;
        local textLine = (additionalLines .. "  " .. g_i18n:getText("MoreAvailable"));
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextColor(1,1,1,1);								
        setTextBold(false);
        totalTextHeigh = totalTextHeigh + getTextHeight(textSize, textLine)
        local textWidth = getTextWidth(textSize, textLine);
        if (textWidth > maxTextWidth) then maxTextWidth = textWidth; end
        renderText(posX,posY,textSize,textLine);
    end
			
    if (lineCount == 0) then
        posY = posY - textSize;
        local textLine = g_i18n:getText("AllProductsOperativ");
        setTextAlignment(RenderText.ALIGN_LEFT);
        setTextColor(1,1,1,1);								
        setTextBold(false);
        totalTextHeigh = totalTextHeigh + getTextHeight(textSize, textLine)
        local textWidth = getTextWidth(textSize, textLine);
        if (textWidth > maxTextWidth) then maxTextWidth = textWidth; end
        renderText(posX,posY,textSize,textLine);
    end
                
        
    
    -- overlay für produktionen
    setOverlayColor(ProductionInfoHud.overlay.overlayId, 0, 0, 0, 0.7);
    setOverlayUVs(ProductionInfoHud.overlay.overlayId, 0.0078125,0.990234375, 0.0078125,0.9921875, 0.009765625,0.990234375, 0.009765625,0.9921875);
    ProductionInfoHud.overlay:setPosition(posX-0.001, posYStart - totalTextHeigh - 0.002);
    ProductionInfoHud.overlay:setDimension(maxTextWidth+0.002, totalTextHeigh);
    ProductionInfoHud.overlay:render();
end

function ProductionInfoHud:SaveSettings()

    if not ProductionInfoHud.isClient then return end

    createFolder(getUserProfileAppPath().. "modSettings/");
    local file = getUserProfileAppPath() .. "modSettings/ProductionInfoHudSettings.xml"

    local XML = createXMLFile("ProductionInfoHudSettings_XML", file, "ProductionInfoHudSettings")

    local xmlTag = ("ProductionInfoHudSettings.display.showType(%d)"):format(0);
    setXMLString(XML, xmlTag.."#string", ProductionInfoHud.settings["display"]["showType"])

    local xmlTag = ("ProductionInfoHudSettings.display.position(%d)"):format(0);
    setXMLInt(XML, xmlTag.."#int", ProductionInfoHud.settings["display"]["position"])

    local xmlTag = ("ProductionInfoHudSettings.display.showFullAnimals(%d)"):format(0);
    setXMLBool(XML, xmlTag.."#bool", ProductionInfoHud.settings["display"]["showFullAnimals"])

    local xmlTag = ("ProductionInfoHudSettings.display.maxLines(%d)"):format(0);
    setXMLInt(XML, xmlTag.."#int", ProductionInfoHud.settings["display"]["maxLines"])

    saveXMLFile(XML)
end

function ProductionInfoHud:LoadSettings()

    if not ProductionInfoHud.isClient then return end

    createFolder(getUserProfileAppPath().. "modSettings/");
    local file = getUserProfileAppPath() .. "modSettings/ProductionInfoHudSettings.xml"
    
    if fileExists(file) ~= true then
        print("ProductionInfoHud: No settings file found. Use predefines");
        return;
    end

    local XML = loadXMLFile("ProductionInfoHudSettings_XML", file, "ProductionInfoHudSettings")

    local xmlTag = ("ProductionInfoHudSettings.display.showType(%d)"):format(0); 
    local value = getXMLString(XML, xmlTag.. "#string");
    if value ~= nil then ProductionInfoHud.settings["display"]["showType"] = value;end;

    xmlTag = ("ProductionInfoHudSettings.display.position(%d)"):format(0); 
    value = getXMLInt(XML, xmlTag.. "#int");
    if value ~= nil then ProductionInfoHud.settings["display"]["position"] = value;end;

    xmlTag = ("ProductionInfoHudSettings.display.showFullAnimals(%d)"):format(0); 
    value = getXMLBool(XML, xmlTag.. "#bool");
    if value ~= nil then ProductionInfoHud.settings["display"]["showFullAnimals"] = value;end;

    xmlTag = ("ProductionInfoHudSettings.display.maxLines(%d)"):format(0); 
    value = getXMLInt(XML, xmlTag.. "#int");
    if value ~= nil then ProductionInfoHud.settings["display"]["maxLines"] = value;end;
end

-- local rX, rY, rZ = getRotation(place.node);
-- print("place.node rX:"..rX.." rY:"..rY.." rZ:"..rZ);

-- print("loadingPattern")
-- DebugUtil.printTableRecursively(loadingPattern,"_",0,2)

addModEventListener(ProductionInfoHud);