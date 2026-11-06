-------------------------------------------------
-- RPG_Client_UINodeData.lua
-- UI node definitions / prerequisites / sizes
-- ✅ Thirst branch
-- ❌ Removed: VeteranPartisan, AccumulatedPower
-------------------------------------------------
local D = {}

D.SIZES = {
    SMALL   = 64,
    BIG     = 96,
    SPECIAL = 128,
}

-- 🔹 큰 노드 목록
D.BigNodeIds = {
    HungerBig         = true,
	StressBig         = true,
    ThirstBig         = true,
	NimbleBig         = true,
	RunningBig        = true,
	StrengthBig       = true,
	FitnessBig        = true,
	BoredomBig        = true,
	WetBig            = true,
	StaminaRegenBig   = true,
	StaminaBig        = true,
	PainBig           = true,
	StaPainBig        = true,
	UnhappyBig        = true,
	FoodSicknessBig   = true,
	PanicBig          = true,
    WeightBig1        = true,
	WeightBig2        = true,
	WeightBig3        = true,
	XPgainBig1        = true,
	XPgainBig2        = true,
	XPgainBig3        = true,
	XPgainBig4        = true,
	XPgainBig5        = true,
    XPVer2Big1        = true,
	XPVer2Big2        = true,
	XPVer2Big3        = true,
	XPVer2Big4        = true,
	XPVer2Big5        = true,
	XPMixedBig        = true,
	XPWeightBig       = true,
}

-- 🔹 스페셜 노드 목록
D.SpecialNodeIds = {
    Start              = true,
    AmmoCollector       = true,
    GravityAdaptation  = true,
    SoulCollector      = true, -- 수리
    BloodCollector     = true, -- 강화
	SacrificeCollector = true, -- 장비보호권
    MemoryStone        = true,
    GeneEditing        = true, -- v50: after Memory Stone
    EnduranceKeystone  = true, -- 1.10.00: final upper node
    DimensionalVault   = true, -- 1.10.00: final left node
}

-- 🔹 선행 스킬 조건 테이블
D.PrereqAND = {
    -- B42.21 v17: vanilla ammunition collector branches (one point per node).
    AmmoCollector = { "Start" },
    Ammo9mm = { "AmmoCollector" },
    Ammo38 = { "Ammo9mm" },
    Ammo45 = { "Ammo38" },
    Ammo357 = { "AmmoCollector" },
    Ammo44 = { "Ammo357" },
    Ammo12g = { "Ammo44" },
    Ammo3030 = { "AmmoCollector" },
    Ammo308 = { "Ammo3030" },
    Ammo556 = { "Ammo308" },
    -- 상단 스테미나 재생
    StaminaRegen1   = { "XPgainBig1" },
    StaminaRegen2   = { "StaminaRegen1" },
    StaminaRegenBig = { "StaminaRegen2" },
    StaminaRegen3   = { "StaminaRegenBig" },
    StaminaRegen4   = { "StaminaRegen3" },

    -- 상단 두번째 네갈래 XPgainBig2
    XPgainBig2        = { "StaminaRegen4" },

    -- 상단 두번째 네갈래 좌측 스테미나 소모량 감소
    Stamina1          = { "XPgainBig2" },
    Stamina2          = { "Stamina1" },
    StaminaBig        = { "Stamina2" },
    Stamina3          = { "StaminaBig" },
    Stamina4          = { "Stamina3" },
	
	-- 상단 두번째 네갈래 좌측 스페셜 수리노드
	SoulCollector    = { "Stamina4" },

    -- 상단 두번째 네갈래 상단 스테미나/고통 감소
    StaPain1          = { "XPgainBig2" },
    StaPain2          = { "StaPain1" },
    StaPainBig        = { "StaPain2" },
    StaPain3          = { "StaPainBig" },
    StaPain4          = { "StaPain3" },

    -- 상단 두번째 네갈래 상단 스페셜 소드 마스터리
    BloodCollector      = { "StaPain4" },
    EnduranceKeystone  = { "BloodCollector" },
    EnduranceChance1   = { "EnduranceKeystone" },
    EnduranceChance2   = { "EnduranceChance1" },
	
    -- 상단 두번째 네갈래 우측 고통 감소
    Pain1             = { "XPgainBig2" },
    Pain2             = { "Pain1" },
    PainBig           = { "Pain2" },
    Pain3             = { "PainBig" },
	Pain4			  = { "Pain3" },
	
	-- 상단 두번째 네갈래 우측 스페셜 쇠지렛대 마스터리
	SacrificeCollector    = { "Pain4" },

    -- 좌측 목마름
    Thirst1            = { "WeightBig1" },
    Thirst2            = { "Thirst1" },
    ThirstBig          = { "Thirst2" },
    Thirst3            = { "ThirstBig" },
    Thirst4            = { "Thirst3" },

    -- 좌측 두번째 네갈래 WeightBig2
    WeightBig2         = { "Thirst4" },
	
    -- 좌측 두번째 네갈래 하단 XPVer2
    XPVer21            = { "WeightBig2" },
    XPVer22            = { "XPVer21" },
    XPVer2Big1         = { "XPVer22" },
    XPVer23            = { "XPVer2Big1" },
    XPVer24            = { "XPVer23" },

    -- 좌측 두번째 네갈래 하단 XPVer2Big2
    XPVer2Big2         = { "XPVer24" },

    -- 좌측 두번째 네갈래 좌측 
    Weight1            = { "WeightBig2" },
    Weight2            = { "Weight1" },
    WeightBig3         = { "Weight2" },
    Weight3            = { "WeightBig3" },
    Weight4            = { "Weight3" },
	
	-- 좌측 두번째 네갈래 좌측 스페셜 GravityAdaptation
	GravityAdaptation  = { "Weight4" },
    DimensionalVault  = { "GravityAdaptation" },
    VaultWeight1      = { "DimensionalVault" },
    VaultWeight2      = { "VaultWeight1" },
    VaultCount1       = { "DimensionalVault" },
    VaultCount2       = { "VaultCount1" },
    VaultTabs1        = { "DimensionalVault" },
    VaultTabs2        = { "VaultTabs1" },

    -- 좌측 두번째 네갈래 상단 
    XPgain1            = { "WeightBig2" },
    XPgain2            = { "XPgain1" },
    XPgainBig3         = { "XPgain2" },
    XPgain3            = { "XPgainBig3" },
    XPgain4            = { "XPgain3" },

    -- 좌측 두번째 네갈래 상단
    XPgainBig4    = { "XPgain4" },

    -- 우측 지루함 회복력
    Boredom1           = { "XPVer2Big3" },
	Boredom2           = { "Boredom1" },
	BoredomBig         = { "Boredom2" },
	Boredom3           = { "BoredomBig" },
	Boredom4           = { "Boredom3" },
	
    -- 우측 두번째 네갈래 XPVer2Big4
    XPVer2Big4        = { "Boredom4" },
	
	-- 우측 두번째 네갈래 하단 질병저항
    FoodSickness1     = { "XPVer2Big4" },
    FoodSickness2     = { "FoodSickness1" },
	FoodSicknessBig   = { "FoodSickness2" },
	FoodSickness3     = { "FoodSicknessBig" },
	FoodSickness4     = { "FoodSickness3" },
	
	-- 우측 하단 XPVer2Big5
	XPVer2Big5        = { "FoodSickness4" },
	
	-- 우측 두번째 네갈래 우측 공황 감소
    Panic1            = { "XPVer2Big4" },
    Panic2            = { "Panic1" },
	PanicBig          = { "Panic2" },
	Panic3            = { "PanicBig" },
	Panic4            = { "Panic3" },
	
	-- 우측 두번째 네갈래 우측 스페셜 GeneEditing
	MemoryStone     = { "Panic4" },
    GeneEditing    = { "MemoryStone" }, -- v50: DNA node at the end of this branch
    ItemFind1      = { "GeneEditing" },
    ItemFind2      = { "ItemFind1" },
    ItemFind3      = { "ItemFind2" },

	-- 우측 두번째 네갈래 상단 우울 회복
    Unhappy1          = { "XPVer2Big4" },
    Unhappy2          = { "Unhappy1" },
	UnhappyBig        = { "Unhappy2" },
	Unhappy3          = { "UnhappyBig" },
	Unhappy4          = { "Unhappy3" },
	
	-- 우측 두번째 네갈래 상단 XPgainBig5
    XPgainBig5        = { "Unhappy4" },
}

D.PrereqOR = {
    -- 상단 불편함 최대치
	Wet1      = { "Start", "Wet2" },
	Wet2      = { "Wet1", "WetBig"},
	WetBig    = { "Wet2", "Wet3"},
	Wet3      = { "WetBig", "Wet4"},
	Wet4      = { "Wet3", "XPgainBig1"},
	
    -- 상단 첫 네갈래 XPgainBig1
    XPgainBig1        = { "Wet4", "Fitness1", "Nimble1" },
	
	-- 좌측 배고픔
    Hunger1           = { "Start", "Hunger2" },
    Hunger2           = { "Hunger1", "HungerBig" },
	HungerBig         = { "Hunger2", "Hunger3" },
    Hunger3           = { "HungerBig", "Hunger4"},
    Hunger4           = { "Hunger3", "WeightBig1" },

	-- 좌측 첫 두갈래 WeightBig1
    WeightBig1        = { "Hunger4", "Strength1" },
	
	-- 우측 스트레스
    Stress1           = { "Start", "Stress2" },
	Stress2           = { "Stress1", "StressBig" },
	StressBig         = { "Stress2", "Stress3" },
	Stress3           = { "StressBig", "Stress4" },
	Stress4           = { "Stress3", "XPVer2Big3" },

    -- 우측 첫 두갈래 XPVer2Big3
    XPVer2Big3       = { "Stress4", "Running1" },
	
	-- 좌상단 힘배율
    Strength1     = { "WeightBig1", "Strength2" },
    Strength2     = { "Strength1", "StrengthBig" },
	StrengthBig   = { "Strength2", "Strength3"},
	Strength3     = { "StrengthBig", "Strength4" },
	Strength4     = { "Strength3", "XPWeightBig" },
	
	-- 좌상단 XPWeight
	XPWeightBig       = { "Strength4", "Fitness4" },
	
	-- 좌상단 Fitness
	Fitness1          = { "XPgainBig1", "Fitness2" },
	Fitness2          = { "Fitness1", "FitnessBig" },
	FitnessBig        = { "Fitness2", "Fitness3"},
	Fitness3          = { "FitnessBig", "Fitness4" },
	Fitness4          = { "Fitness3", "XPWeightBig" },
	
	-- 우상단 능숙한 달리기 배율
    Running1     = { "XPVer2Big3", "Running2" },
    Running2     = { "Running1", "RunningBig" },
	RunningBig   = { "Running2", "Running3" },
	Running3     = { "RunningBig", "Running4" },
	Running4     = { "Running3", "XPMixedBig" },
	
	-- 우상단 XPMixedBig
	XPMixedBig       = { "Running4", "Nimble4" },
	
	-- 우상단 조준시발걸음 배율
	Nimble1          = { "XPgainBig1", "Nimble2" },
	Nimble2          = { "Nimble1", "NimbleBig" },
	NimbleBig        = { "Nimble2", "Nimble3" },
	Nimble3          = { "NimbleBig", "Nimble4" },
	Nimble4          = { "Nimble3", "XPMixedBig" },
	
}

-- 🔹 노드 좌표/텍스처
function D.BuildNodes(o)
    -- o에는 tex들이 로드돼 있어야 함 (RPG_UI_Textures.Load(o) 이후)
    return {
        -- 0. Start
        { id="Start",          x=0, y=0, tex=o.startNodeTex },
        -- B42.21 v17: new branch below Start. Pistol / heavy / rifle ammunition.
        { id="AmmoCollector", x=0, y=150, tex=o.texAmmoCollector },
        { id="Ammo9mm", x=-340, y=300, tex=o.texAmmo9mm },
        { id="Ammo38", x=-340, y=420, tex=o.texAmmo38 },
        { id="Ammo45", x=-340, y=540, tex=o.texAmmo45 },
        { id="Ammo357", x=0, y=300, tex=o.texAmmo357 },
        { id="Ammo44", x=0, y=420, tex=o.texAmmo44 },
        { id="Ammo12g", x=0, y=540, tex=o.texAmmo12g },
        { id="Ammo3030", x=340, y=300, tex=o.texAmmo3030 },
        { id="Ammo308", x=340, y=420, tex=o.texAmmo308 },
        { id="Ammo556", x=340, y=540, tex=o.texAmmo556 },


        -- 1. 상단
        { id="Wet1",   x=0, y=-100, tex=o.texWet },
        { id="Wet2",   x=0, y=-200, tex=o.texWet },
        { id="WetBig", x=0, y=-300, tex=o.texWet },
        { id="Wet3",   x=0, y=-400, tex=o.texWet },
        { id="Wet4",   x=0, y=-500, tex=o.texWet },

		-- 상단 첫 네갈래 XPgainBig1
        { id="XPgainBig1",     x=0, y=-600, tex=o.texStaminaRegen },

		-- 상단 스테미나 재생
        { id="StaminaRegen1", x=0, y=-700, tex=o.texStaminaRegen },
        { id="StaminaRegen2", x=0, y=-800, tex=o.texStaminaRegen },
        { id="StaminaRegenBig", x=0, y=-900, tex=o.texStaminaRegen },
        { id="StaminaRegen3", x=0, y=-1000, tex=o.texStaminaRegen },
        { id="StaminaRegen4", x=0, y=-1100, tex=o.texStaminaRegen },
		
		-- 상단 두번째 네갈래 XPgainBig2
        { id="XPgainBig2", x=0, y=-1200, tex=o.texStamina },
		
		-- 상단 두번째 네갈래 좌측 Stamina
        { id="Stamina1",   x=-100, y=-1200, tex=o.texStamina },
        { id="Stamina2",   x=-200, y=-1200, tex=o.texStamina },
        { id="StaminaBig", x=-300, y=-1200, tex=o.texStamina },
		{ id="Stamina3",   x=-400, y=-1200, tex=o.texStamina },
		{ id="Stamina4",   x=-500, y=-1200, tex=o.texStamina },
		
		-- 상단 두번째 네갈래 좌측 Special PickaxeMastery
		{ id="SoulCollector", x=-600, y=-1200, tex=o.texSoulCollector },
		
		-- 상단 두번째 네갈래 상단 StaPain
        { id="StaPain1", x=0, y=-1300, tex=o.texStaPain },
		{ id="StaPain2", x=0, y=-1400, tex=o.texStaPain },
		{ id="StaPainBig", x=0, y=-1500, tex=o.texStaPain },
		{ id="StaPain3", x=0, y=-1600, tex=o.texStaPain },
		{ id="StaPain4", x=0, y=-1700, tex=o.texStaPain },
		
		-- 상단 두번째 네갈래 상단 Special SwordMastery
        { id="BloodCollector", x=0, y=-1800, tex=o.texBloodCollector },
        { id="EnduranceKeystone", x=0, y=-2000, tex=o.texEnduranceKeystone },
        { id="EnduranceChance1", x=0, y=-2110, tex=o.texEnduranceChance },
        { id="EnduranceChance2", x=0, y=-2220, tex=o.texEnduranceChance },
		
		-- 상단 두번째 네갈래 우측 Pain
        { id="Pain1",  x=100, y=-1200, tex=o.texPain },
		{ id="Pain2",  x=200, y=-1200, tex=o.texPain },
		{ id="PainBig",  x=300, y=-1200, tex=o.texPain },
		{ id="Pain3",  x=400, y=-1200, tex=o.texPain },
		{ id="Pain4",  x=500, y=-1200, tex=o.texPain },
		
		-- 상단 두번째 네갈래 우측 Special CrowbarMastery
        { id="SacrificeCollector",     x=600, y=-1200, tex=o.texSacrificeCollector },

		-- 좌측 Hunger
        { id="Hunger1", x=-100, y=0, tex=o.texHunger },
		{ id="Hunger2", x=-200, y=0, tex=o.texHunger },
		{ id="HungerBig", x=-300, y=0, tex=o.texHunger },
		{ id="Hunger3", x=-400, y=0, tex=o.texHunger },
		{ id="Hunger4", x=-500, y=0, tex=o.texHunger },
		
		-- 좌측 첫번째 두갈래 WeightBig1
        { id="WeightBig1", x=-600, y=0, tex=o.texWeight },

        -- 좌측 Thirst
        { id="Thirst1", x=-700, y= 0, tex=o.texThirst },
		{ id="Thirst2", x=-800, y= 0, tex=o.texThirst },
		{ id="ThirstBig", x=-900, y= 0, tex=o.texThirst },
		{ id="Thirst3", x=-1000, y= 0, tex=o.texThirst },
		{ id="Thirst4", x=-1100, y= 0, tex=o.texThirst },
		
		-- 좌측 두번째 네갈래
        { id="WeightBig2", x=-1200, y= 0, tex=o.texWeight },
		
		-- 좌측 두번째 네갈래 하단
        { id="XPVer21", x=-1200, y= 100, tex=o.texWeight },
		{ id="XPVer22", x=-1200, y= 200, tex=o.texWeight },
		{ id="XPVer2Big1", x=-1200, y= 300, tex=o.texWeight },
		{ id="XPVer23", x=-1200, y= 400, tex=o.texWeight },
		{ id="XPVer24", x=-1200, y= 500, tex=o.texWeight },
		
		-- 좌측 두번째 네갈래 하단 AccumulatedPower
        { id="XPVer2Big2", x=-1200, y= 600, tex=o.texWeight },
		
		-- 좌측 두번째 네갈래 좌측 Weight
        { id="Weight1", x=-1300, y= 0, tex=o.texWeight },
		{ id="Weight2", x=-1400, y= 0, tex=o.texWeight },
		{ id="WeightBig3", x=-1500, y= 0, tex=o.texWeight },
		{ id="Weight3", x=-1600, y= 0, tex=o.texWeight },
		{ id="Weight4", x=-1700, y= 0, tex=o.texWeight },
		
		-- 좌측 두번째 네갈래 좌측 Special GravityAdaptation
        { id="GravityAdaptation", x=-1800, y=0, tex=o.texGravityAdaptation },
        { id="DimensionalVault", x=-2000, y=0, tex=o.texDimensionalVault },
        { id="VaultWeight1", x=-2000, y=-180, tex=o.texVaultWeight },
        { id="VaultWeight2", x=-2000, y=-320, tex=o.texVaultWeight },
        { id="VaultCount1", x=-2200, y=0, tex=o.texVaultCount },
        { id="VaultCount2", x=-2340, y=0, tex=o.texVaultCount },
        { id="VaultTabs1", x=-2000, y=180, tex=o.texVaultTabs },
        { id="VaultTabs2", x=-2000, y=320, tex=o.texVaultTabs },
		
		-- 좌측 두번째 네갈래 상단 
        { id="XPgain1", x=-1200, y=-100, tex=o.texHunger },
		{ id="XPgain2", x=-1200, y=-200, tex=o.texThirst },
		{ id="XPgainBig3", x=-1200, y=-300, tex=o.texHunger },
		{ id="XPgain3", x=-1200, y=-400, tex=o.texHunger },
		{ id="XPgain4", x=-1200, y=-500, tex=o.texThirst },
		
		-- 좌측 두번째 네갈래 상단 VeteranPartisan
        { id="XPgainBig4", x=-1200, y=-600, tex=o.texThirst },
		
		-- 우측 Stress
        { id="Stress1", x=100, y=0, tex=o.texStress },
		{ id="Stress2", x=200, y=0, tex=o.texStress },
		{ id="StressBig", x=300, y=0, tex=o.texStress },
		{ id="Stress3", x=400, y=0, tex=o.texStress },
		{ id="Stress4", x=500, y=0, tex=o.texStress },
		
		-- 우측 첫번째 두갈래 XPVer2Big3
        { id="XPVer2Big3", x=600, y=0, tex=o.texStress },

		-- 우측 지루함 회복력
        { id="Boredom1", x=700, y=0, tex=o.texBoredom },
		{ id="Boredom2", x=800, y=0, tex=o.texBoredom },
		{ id="BoredomBig", x=900, y=0, tex=o.texBoredom },
		{ id="Boredom3", x=1000, y=0, tex=o.texBoredom },
		{ id="Boredom4", x=1100, y=0, tex=o.texBoredom },
		
        -- 우측 두번째 네갈래 XPVer2Big4
        { id="XPVer2Big4", x=1200, y=0, tex=o.texPanic },
		
		-- 우측 두번째 네갈래 하단 FoodSickness
        { id="FoodSickness1", x=1200, y=100, tex=o.texFoodSickness },
		{ id="FoodSickness2", x=1200, y=200, tex=o.texFoodSickness },
		{ id="FoodSicknessBig", x=1200, y=300, tex=o.texFoodSickness },
		{ id="FoodSickness3", x=1200, y=400, tex=o.texFoodSickness },
		{ id="FoodSickness4", x=1200, y=500, tex=o.texFoodSickness },
		
		-- 우측 두번째 네갈래 하단 XPVer2Big5
        { id="XPVer2Big5", x=1200, y=600, tex=o.texFoodSickness },
		
		-- 우측 두번째 네갈래 우측 Panic
        { id="Panic1", x=1300, y=0, tex=o.texPanic },
		{ id="Panic2", x=1400, y=0, tex=o.texPanic },
		{ id="PanicBig", x=1500, y=0, tex=o.texPanic },
		{ id="Panic3", x=1600, y=0, tex=o.texPanic },
		{ id="Panic4", x=1700, y=0, tex=o.texPanic },
		
		-- 우측 두번째 네갈래 우측 Special GeneEditing
        { id="MemoryStone", x=1800, y=0, tex=o.texMemoryStone },
        { id="GeneEditing", x=2000, y=0, tex=o.texGeneEditing },
        { id="ItemFind1", x=2140, y=0, tex=o.texItemFind },
        { id="ItemFind2", x=2260, y=0, tex=o.texItemFind },
        { id="ItemFind3", x=2380, y=0, tex=o.texItemFind },
		
		-- 우측 두번째 네갈래 상단 Unhappy
        { id="Unhappy1", x=1200, y=-100, tex=o.texUnhappy },
		{ id="Unhappy2", x=1200, y=-200, tex=o.texUnhappy },
		{ id="UnhappyBig", x=1200, y=-300, tex=o.texUnhappy },
		{ id="Unhappy3", x=1200, y=-400, tex=o.texUnhappy },
		{ id="Unhappy4", x=1200, y=-500, tex=o.texUnhappy },
		
		-- 우측 두번째 네갈래 상단 XPgainBig5
        { id="XPgainBig5", x=1200, y=-600, tex=o.texUnhappy },
		
		-- 좌상단 힘배율
        { id="Strength1", x=-600, y=-100, tex=o.texStrength },
		{ id="Strength2", x=-600, y=-200, tex=o.texStrength },
		{ id="StrengthBig", x=-600, y=-300, tex=o.texStrength },
		{ id="Strength3", x=-600, y=-400, tex=o.texStrength },
		{ id="Strength4", x=-600, y=-500, tex=o.texStrength },
		
		-- 좌상단 XPWeight
        { id="XPWeightBig", x=-600, y=-600, tex=o.texWeight },
		
		-- 좌상단 체력배율
        { id="Fitness1", x=-100, y=-600, tex=o.texFitness },
		{ id="Fitness2", x=-200, y=-600, tex=o.texFitness },
		{ id="FitnessBig", x=-300, y=-600, tex=o.texFitness },
		{ id="Fitness3", x=-400, y=-600, tex=o.texFitness },
		{ id="Fitness4", x=-500, y=-600, tex=o.texFitness },
		
		--우상단 달리기 배율
        { id="Running1", x=600, y=-100, tex=o.texRunning },
		{ id="Running2", x=600, y=-200, tex=o.texRunning },
		{ id="RunningBig", x=600, y=-300, tex=o.texRunning },
		{ id="Running3", x=600, y=-400, tex=o.texRunning },
		{ id="Running4", x=600, y=-500, tex=o.texRunning },
		
		-- 우상단 조준시발걸음 배율
        { id="Nimble1", x=100, y=-600, tex=o.texNimble },
		{ id="Nimble2", x=200, y=-600, tex=o.texNimble },
		{ id="NimbleBig", x=300, y=-600, tex=o.texNimble },
		{ id="Nimble3", x=400, y=-600, tex=o.texNimble },
		{ id="Nimble4", x=500, y=-600, tex=o.texNimble },
		
		--우상단 XPMixedBig
        { id="XPMixedBig", x=600, y=-600, tex=o.texNimble },
    }
end

return D
