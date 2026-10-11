--***********************************************************
--**                     Papa_Chad                        **
--***********************************************************

KnightsDanHumveeArmorConfig = {
    BullBar = {
        requiredItem = "Bull_Bar",
        protectedParts = {
            EngineDoor  = { absorbPercent = 0.8, wearPerDamage = 0.15 },
            Engine      = { absorbPercent = 0.5, wearPerDamage = 0.1 },
            Windshield  = { absorbPercent = 0.3, wearPerDamage = 0.05 }
        }
    },
    BumperFront = {
        requiredItem = "BumperFront",
        protectedParts = {
            EngineDoor  = { absorbPercent = 0.7, wearPerDamage = 0.25 },
            Engine      = { absorbPercent = 0.5, wearPerDamage = 0.15 },
            Windshield  = { absorbPercent = 0.3, wearPerDamage = 0.05 }
        }
    },
    Grille = {
        requiredItem = "Grille",
        protectedParts = {
            EngineDoor  = { absorbPercent = 0.3, wearPerDamage = 0.9 },
			Engine = { absorbPercent = 0.3, wearPerDamage = 0.9 }
        }
    },
    BumperRear = {
        requiredItem = "BumperRear",
        protectedParts = {
            TrunkDoor = { absorbPercent = 0.5, wearPerDamage = 0.25 }
        }
    },

    ------------------------ Windows Armor ---------------------------------
    WindshieldArmor = {
        requiredItem = "WindshieldArmor",
        protectedParts = {
            Windshield = { absorbPercent = 0.5, wearPerDamage = 0.25 }           
        }
    },
    TrunkDoorArmor = {
        requiredItem = "TrunkDoorArmor",
        protectedParts = {
            WindshieldRear = { absorbPercent = 0.5, wearPerDamage = 0.25 }           
        }
    },
    DoorFrontLeftArmor = {
        requiredItem = "DoorFrontLeftArmor",
        protectedParts = {
            WindowFrontLeft = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorFrontLeft   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },
    DoorFrontRightArmor = {
        requiredItem = "DoorFrontRightArmor",
        protectedParts = {
            WindowFrontRight = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorFrontRight   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },
    DoorMiddleLeftArmor = {
        requiredItem = "DoorMiddleLeftArmor",
        protectedParts = {
            WindowMiddleLeft = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorMiddleLeft   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },
    DoorMiddleRightArmor = {
        requiredItem = "DoorMiddleRightArmor",
        protectedParts = {
            WindowMiddleRight = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorMiddleRight   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },
	DoorRearLeftArmor = {
        requiredItem = "DoorRearLeftArmor",
        protectedParts = {
            WindowRearLeft = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorRearLeft   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },
    DoorRearRightArmor = {
        requiredItem = "DoorRearRightArmor",
        protectedParts = {
            WindowRearRight = { absorbPercent = 0.5, wearPerDamage = 0.25 },
            DoorRearRight   = { absorbPercent = 0.5, wearPerDamage = 0.15 }
        }
    },

    -------------------------- Tank Armor --------------------------------
    Tank_Armor = {
        requiredItem = "Armor",
        protectedParts = {
            EngineDoor       = { absorbPercent = 0.99, wearPerDamage = 0.01 },
            Engine           = { absorbPercent = 0.60, wearPerDamage = 0.02 },
			GasTank          = { absorbPercent = 0.95, wearPerDamage = 0.02 },
            Windshield       = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorFrontLeft    = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorFrontRight   = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorRearLeft     = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorRearRight    = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorMiddleRight  = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            DoorMiddleLeft   = { absorbPercent = 0.97, wearPerDamage = 0.02 },
			TrunkDoor		 = { absorbPercent = 0.98, wearPerDamage = 0.02 },
			TankRoof		 = { absorbPercent = 0.98, wearPerDamage = 0.02 },
			TruckBed		 = { absorbPercent = 0.97, wearPerDamage = 0.02 },
			TruckBedOpen	 = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowFrontLeft  = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowFrontRight = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowMiddleRight= { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowRearRight  = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowRearLeft   = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            WindowMiddleLeft = { absorbPercent = 0.97, wearPerDamage = 0.02 },
            Tire             = { absorbPercent = 0.97, wearPerDamage = 0.02 },			
            Turret           = { absorbPercent = 0.97, wearPerDamage = 0.02 }
        }
    },	
	Engine_Armor = {
        requiredItem = "Engine_Armor",
        protectedParts = {
            EngineDoor       = { absorbPercent = 0.98, wearPerDamage = 0.2 },
			GasTank          = { absorbPercent = 0.70, wearPerDamage = 0.2 },
            Engine           = { absorbPercent = 0.60, wearPerDamage = 0.2 }
        }
    }
}
