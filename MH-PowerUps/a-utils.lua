if not _G.mhExists then return end

local smlua_model_util_get_id = smlua_model_util_get_id
local sqrf = sqrf
local atan2s = atan2s
local sm64_to_degrees = sm64_to_degrees
local spawn_sync_object = spawn_sync_object
local network_send_object = network_send_object
local passes_pvp_interaction_checks = passes_pvp_interaction_checks
local spawn_sync_object = spawn_sync_object

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

--#region MH Stuff ----------------------------------------------------------------------------------------------------

getTeam = function (_) return 1 end
allowPvpAttack = function (_, _) return true end
mhAllowInteract = function (_, _, _) return true end

if _G.mhExists then
    getTeam = _G.mhApi.getTeam
    allowPvpAttack = _G.mhApi.pvpIsValid
    mhAllowInteract = _G.mhApi.interactionIsValid
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region PowerUp Stuff -----------------------------------------------------------------------------------------------
UNKNOWN = 0
HAMMER = 1
FIREFLOWER = 2
CANNON = 3
BOOMERANG = 4
MAX_PU = 5

E_MODEL_HAMMER = smlua_model_util_get_id('hammer_geo')
E_MODEL_FIRE_FLOWER = smlua_model_util_get_id('fire_flower_geo')
E_MODEL_FIREBALL = smlua_model_util_get_id('fireball_geo')
E_MODEL_CANNON = smlua_model_util_get_id('cannon_geo')
E_MODEL_BOOMERANG = smlua_model_util_get_id('boomerang_geo')
E_MODEL_UNKNOWN_PU = smlua_model_util_get_id('unknown_pu_geo')

POWERUPS_PER_LEVEL = {
    [LEVEL_CASTLE_GROUNDS] = {
        {
            {type = HAMMER, x = -1394, y = 3174, z = -5506},
            {type = HAMMER, x = -5344, y = 543, z = -3921},
            {type = FIREFLOWER, x = -6695, y = 311, z = -379},
            {type = FIREFLOWER, x = 6392, y = 745, z = -4038},
            {type = CANNON, x = 1242, y = 3174, z = -5506},
            {type = CANNON, x = 2180, y = 89, z = 1957},
            {type = BOOMERANG, x = -939, y = 544, z = 2533},
            {type = BOOMERANG, x = 3888, y = 545, z = -5766}
        }
    },
    [LEVEL_CASTLE] = {
        { --1st Floor
            {type = HAMMER, x = 779, y = 205, z = -782},
            {type = FIREFLOWER, x = -2823, y = 205, z = -972},
            {type = CANNON, x = -1024, y = 0, z = 717},
            {type = BOOMERANG, x = -1034, y = -101, z = -3213}
        },
        { --2nd Floor
            {type = HAMMER, x = 3961, y = 1613, z = 708},
            {type = HAMMER, x = 1691, y = 2765, z = 6637},
            {type = CANNON, x = 3164, y = 1613, z = 3164},
            {type = CANNON, x = -2072, y = 2765, z = 6683},
            {type = FIREFLOWER, x = 3765, y = 1613, z = 2741},
            {type = FIREFLOWER, x = -6649, y = 1306, z = 1832},
            {type = BOOMERANG, x = 3254, y = 1613, z = 1315},
            {type = BOOMERANG, x = -218, y = 3174, z = 4340}
        },
        { --Basement
            {type = HAMMER, x = 1997, y = -1381, z = -2639},
            {type = HAMMER, x = -160, y = -1074, z = -2609},
            {type = FIREFLOWER, x = -1390, y = -1177, z = -3482},
            {type = CANNON, x = -3856, y = -1381, z = -1108},
            {type = BOOMERANG, x = 5548, y = -1177, z = -502}
        }
    },
    [LEVEL_CASTLE_COURTYARD] = {
        {
            {type = HAMMER, x = 3372, y = 0, z = -337},
            {type = FIREFLOWER, x = 2157, y = -204, z = -2526},
            {type = FIREFLOWER, x = -2445, y = -204, z = -2236},
            {type = CANNON, x = 3372, y = 0, z = -2827},
            {type = BOOMERANG, x = -3304, y = 0, z = -1582}
        }
    },
    [LEVEL_BOB] = {
        {
            {type = HAMMER, x = -5941, y = 768, z = 1673},
            {type = HAMMER, x = 1281, y = 768, z = 678},
            {type = HAMMER, x = 4338, y = 3072, z = 405},
            {type = FIREFLOWER, x = -6600, y = 1024, z = -3360},
            {type = FIREFLOWER, x = 1918, y = 768, z = 6616},
            {type = FIREFLOWER, x = 446, y = 3850, z = -5050},
            {type = CANNON, x = -6121, y = 128, z = 5604},
            {type = CANNON, x = 4719, y = 1009, z = 4669},
            {type = CANNON, x = 3957, y = 3048, z = -2273},
            {type = BOOMERANG, x = -6959, y = 2080, z = -7346},
            {type = BOOMERANG, x = -2896, y = 0, z = -4724},
            {type = BOOMERANG, x = 6793, y = 883, z = -2531}
        }
    },
    [LEVEL_WF] = {
        {
            {type = HAMMER, x = -2569, y = 384, z = -1077},
            {type = HAMMER, x = 2918, y = 2304, z = -241},
            {type = HAMMER, x = 1311, y = 3584, z = -450},
            {type = FIREFLOWER, x = 3076, y = 256, z = 5253},
            {type = FIREFLOWER, x = 4606, y = 256, z = 131},
            {type = FIREFLOWER, x = -265, y = 2560, z = 2313},
            {type = CANNON, x = -2260, y = 1024, z = 3894},
            {type = CANNON, x = 1872, y = 2560, z = 2619},
            {type = CANNON, x = -2540, y = 2560, z = -502},
            {type = BOOMERANG, x = 1562, y = 922, z = 2340},
            {type = BOOMERANG, x = 2699, y = 1075, z = -3768},
            {type = BOOMERANG, x = 2328, y = 3584, z = -2354}
        }
    },
    [LEVEL_JRB] = {
        {--main
            {type = HAMMER, x = -5016, y = 1126, z = -223},
            {type = HAMMER, x = 5565, y = -2966, z = -7055},
            {type = FIREFLOWER, x = -2449, y = -2966, z = -4131},
            {type = FIREFLOWER, x = -6764, y = 1126, z = 3301},
            {type = CANNON, x = 1254, y = 1536, z = 6560},
            {type = CANNON, x = 46, y = -2534, z = -6608},
            {type = BOOMERANG, x = -531, y = -2966, z = -2830},
            {type = BOOMERANG, x = -2022, y = 1331, z = 6732}
        },
        {--inside ship
            {type = HAMMER, x = 864, y = 430, z = 1804},
            {type = FIREFLOWER, x = 397, y = -351, z = -107},
            {type = CANNON, x = -234, y = 694, z = 1972},
            {type = BOOMERANG, x = 762, y = -351, z = -1643}
        }
    },
    [LEVEL_CCM] = {
        {--main
            {type = HAMMER, x = -766, y = 3471, z = -945},
            {type = HAMMER, x = 3040, y = -818, z = 589},
            {type = HAMMER, x = 2201, y = -3885, z = 4142},
            {type = FIREFLOWER, x = 438, y = 2698, z = -2566},
            {type = FIREFLOWER, x = -3713, y = 808, z = -2292},
            {type = FIREFLOWER, x = -4820, y = -1360, z = 253},
            {type = CANNON, x = -763, y = 1194, z = 2110},
            {type = CANNON, x = -3827, y = -1740, z = 5398},
            {type = CANNON, x = 148, y = -511, z = 2663},
            {type = BOOMERANG, x = 1150, y = 3072, z = -600},
            {type = BOOMERANG, x = 5805, y = -4607, z = -2401},
            {type = BOOMERANG, x = 1457, y = -1535, z = 3539}
        },
        {--slide
            {type = HAMMER, x = -6541, y = -4812, z = -7533},
            {type = FIREFLOWER, x = -5934, y = 6656, z = -6103},
            {type = CANNON, x = -5609, y = -4812, z = -6959},
            {type = BOOMERANG, x = -7279, y = -5836, z = -6683}
        }
    },
    [LEVEL_BBH] = {
        {
            {type = HAMMER, x = -1450, y = -204, z = 6043},
            {type = HAMMER, x = 1532, y = 0, z = -958},
            {type = HAMMER, x = 658, y = 2867, z = 1712},
            {type = HAMMER, x = -8, y = -2457, z = 3310},
            {type = FIREFLOWER, x = 4632, y = -204, z = 290},
            {type = FIREFLOWER, x = -1512, y = 102, z = 216},
            {type = FIREFLOWER, x = -1542, y = 2560, z = 1712},
            {type = FIREFLOWER, x = 1182, y = -2457, z = 1802},
            {type = CANNON, x = 1952, y = -204, z = -3086},
            {type = CANNON, x = -1628, y = 0, z = 1749},
            {type = CANNON, x = -198, y = 819, z = 1012},
            {type = CANNON, x = -2233, y = -2457, z = -1234},
            {type = BOOMERANG, x = -3577, y = -204, z = 290},
            {type = BOOMERANG, x = 2867, y = 2560, z = 1712},
            {type = BOOMERANG, x = -2668, y = -2457, z = 4576},
            {type = BOOMERANG, x = 956, y = 0, z = 214}
        }
    },
    [LEVEL_HMC] = {
        {
            {type = HAMMER, x = -7760, y = 2161, z = 7720},
            {type = HAMMER, x = 603, y = 2048, z = 4799},
            {type = HAMMER, x = 5547, y = -767, z = -2669},
            {type = HAMMER, x = -5208, y = 2458, z = -166},
            {type = HAMMER, x = -1333, y = -4484, z = 5763},
            {type = FIREFLOWER, x = -2607, y = 2048, z = 3960},
            {type = FIREFLOWER, x = 4264, y = 0, z = 4955},
            {type = FIREFLOWER, x = 2068, y = -767, z = -1582},
            {type = FIREFLOWER, x = -6795, y = 1587, z = -5756},
            {type = FIREFLOWER, x = -3324, y = -4279, z = 2991},
            {type = CANNON, x = -6557, y = 1536, z = 2105},
            {type = CANNON, x = 6765, y = 1024, z = 7227},
            {type = CANNON, x = 6595, y = -357, z = -1585},
            {type = CANNON, x = -5262, y = 2810, z = -7983},
            {type = CANNON, x = -125, y = -4689, z = 3324},
            {type = BOOMERANG, x = 9, y = 2048, z = 3871},
            {type = BOOMERANG, x = 2533, y = 2048, z = 6520},
            {type = BOOMERANG, x = 3182, y = -869, z = 448},
            {type = BOOMERANG, x = -3974, y = 1843, z = -6129},
            {type = BOOMERANG, x = -5441, y = -4195, z = -2885}
        }
    },
    [LEVEL_LLL] = {
        {--main  
            {type = HAMMER, x = 2098, y = 154, z = -314},
            {type = HAMMER, x = -5113, y = 512, z = -4098},
            {type = FIREFLOWER, x = 7167, y = 307, z = 1401},
            {type = FIREFLOWER, x = 3820, y = 307, z = -5618},
            {type = CANNON, x = -5888, y = 154, z = 6986},
            {type = CANNON, x = 6125, y = 512, z = 7288},
            {type = BOOMERANG, x = 1130, y = 154, z = 6242},
            {type = BOOMERANG, x = 3839, y = 78, z = -3207}
        },
        {--volcano
            {type = HAMMER, x = 419, y = 2355, z = 582},
            {type = FIREFLOWER, x = -1411, y = 2442, z = -2307},
            {type = CANNON, x = -1381, y = 1613, z = 2291},
            {type = BOOMERANG, x = -1541, y = 95, z = 544}
        }
    },
    [LEVEL_SSL] = {
        {--main
            {type = HAMMER, x = 5897, y = 51, z = 2990},
            {type = HAMMER, x = -1725, y = 0, z = 3543},
            {type = FIREFLOWER, x = 1025, y = 0, z = 2194},
            {type = FIREFLOWER, x = -4833, y = 0, z = -6370},
            {type = CANNON, x = 6405, y = 0, z = -2292},
            {type = CANNON, x = -6379, y = 45, z = -917},
            {type = BOOMERANG, x = 7097, y = 0, z = 7216},
            {type = BOOMERANG, x = 3341, y = 0, z = 5893}
        },
        {--pyramid
            {type = HAMMER, x = 649, y = 0, z = 4746},
            {type = FIREFLOWER, x = 14, y = 896, z = -2111},
            {type = CANNON, x = -1399, y = -81, z = -1438},
            {type = BOOMERANG, x = 3, y = 1874, z = 2806}
        }
    },
    [LEVEL_DDD] = {
        {
            {type = HAMMER, x = 6790, y = 520, z = -556},
            {type = FIREFLOWER, x = 1545, y = 110, z = 4306},
            {type = CANNON, x = 6139, y = 110, z = 4371},
            {type = BOOMERANG, x = 6790, y = 520, z = 160}
        }
    },
    [LEVEL_SL] = {
        {--main
            {type = HAMMER, x = 5041, y = 1024, z = 4538},
            {type = HAMMER, x = -3845, y = 1024, z = 837},
            {type = FIREFLOWER, x = -4668, y = 1024, z = -6235},
            {type = FIREFLOWER, x = -401, y = 4352, z = 707},
            {type = CANNON, x = 2793, y = 973, z = -4864},
            {type = CANNON, x = -4451, y = 1382, z = 4482},
            {type = BOOMERANG, x = -726, y = 1536, z = -2526},
            {type = BOOMERANG, x = -5759, y = 2048, z = -2573}
        },
        {--igloo
            {type = HAMMER, x = -1573, y = 0, z = 392},
            {type = FIREFLOWER, x = 599, y = 0, z = 830},
            {type = CANNON, x = 1756, y = 0, z = -924},
            {type = BOOMERANG, x = -436, y = 0, z = 1740}
        }
    },
    [LEVEL_WDW] = {
        {--main
            {type = HAMMER, x = 1639, y = 205, z = -1793},
            {type = HAMMER, x = -3576, y = 3584, z = -3584},
            {type = FIREFLOWER, x = 528, y = 384, z = 919},
            {type = FIREFLOWER, x = 3386, y = 1280, z = 2184},
            {type = CANNON, x = -3222, y = 1152, z = 423},
            {type = CANNON, x = -762, y = 2176, z = 2211},
            {type = BOOMERANG, x = -3136, y = 2304, z = -1470},
            {type = BOOMERANG, x = 1621, y = 2756, z = -3589}
        },
        {--town
            {type = HAMMER, x = 2052, y = -2559, z = -2037},
            {type = FIREFLOWER, x = -3695, y = -2508, z = 1394},
            {type = CANNON, x = -2114, y = -2536, z = -2038},
            {type = BOOMERANG, x = 599, y = -2559, z = 3326}
        }
    },
    [LEVEL_TTM] = {
        {--main
            {type = HAMMER, x = 5026, y = -3848, z = 5084},
            {type = HAMMER, x = 566, y = -2836, z = -4155},
            {type = HAMMER, x = -1174, y = 78, z = 1624},
            {type = FIREFLOWER, x = -2588, y = -4245, z = 4436},
            {type = FIREFLOWER, x = -1649, y = -2252, z = -2363},
            {type = FIREFLOWER, x = -850, y = 1235, z = -1066},
            {type = CANNON, x = 4534, y = -4607, z = 1054},
            {type = CANNON, x = -2200, y = -2111, z = 2166},
            {type = CANNON, x = -1879, y = -706, z = -3209},
            {type = BOOMERANG, x = 3942, y = -2836, z = -3519},
            {type = BOOMERANG, x = 2551, y = -1548, z = 3775},
            {type = BOOMERANG, x = 2393, y = 1670, z = -1410}
        },
        {--slide start
            {type = HAMMER, x = 6357, y = 4781, z = 7240},
            {type = FIREFLOWER, x = 7506, y = 4781, z = 6110}
        },
        {},--nothing
        {--slide end
            {type = CANNON, x = -7292, y = -1763, z = -5207},
            {type = BOOMERANG, x = -7292, y = -1763, z = -4406}
        }
    },
    [LEVEL_THI] = {
        {--huge
            {type = HAMMER, x = -7875, y = -2969, z = 7876},
            {type = HAMMER, x = -3064, y = 512, z = 534},
            {type = HAMMER, x = 1395, y = 3845, z = -1140},
            {type = FIREFLOWER, x = -4562, y = -2559, z = -5680},
            {type = FIREFLOWER, x = 4940, y = -1535, z = 3440},
            {type = FIREFLOWER, x = 2556, y = -2047, z = -4834},
            {type = CANNON, x = -6443, y = -2559, z = 839},
            {type = CANNON, x = 6549, y = -2832, z = 7287},
            {type = CANNON, x = -5101, y = 325, z = -5547},
            {type = BOOMERANG, x = -526, y = -2559, z = 6934},
            {type = BOOMERANG, x = -1294, y = -511, z = 4901},
            {type = BOOMERANG, x = 7154, y = -1535, z = -3310}
        },
        {--tiny
            {type = HAMMER, x = -1658, y = -767, z = 321},
            {type = FIREFLOWER, x = -924, y = 154, z = 145},
            {type = CANNON, x = 2157, y = -460, z = -927},
            {type = BOOMERANG, x = 1452, y = -460, z = 1046}
        },
        {--wiggler cave
            {type = HAMMER, x = 1258, y = 1968, z = -1239},
            {type = FIREFLOWER, x = -997, y = 1434, z = 1737},
            {type = CANNON, x = -1485, y = 2026, z = 1509},
            {type = BOOMERANG, x = -1538, y = 512, z = -1851}
        }
    },
    [LEVEL_TTC] = {
        {
            {type = HAMMER, x = 1797, y = -4822, z = -726},
            {type = HAMMER, x = -973, y = -19, z = -372},
            {type = FIREFLOWER, x = -731, y = -1453, z = -1888},
            {type = FIREFLOWER, x = 621, y = 3860, z = -430},
            {type = CANNON, x = 780, y = -2487, z = 1898},
            {type = CANNON, x = 1890, y = -19, z = -425},
            {type = BOOMERANG, x = -1585, y = -3491, z = 1107},
            {type = BOOMERANG, x = 656, y = 1351, z = 1874}
        }
    },
    [LEVEL_RR] = {
        {
            {type = HAMMER, x = 1793, y = -944, z = -103},
            {type = HAMMER, x = -5318, y = 1648, z = -42},
            {type = HAMMER, x = 1900, y = 3083, z = -649},
            {type = FIREFLOWER, x = 6496, y = -1091, z = 880},
            {type = FIREFLOWER, x = -3858, y = 112, z = -52},
            {type = FIREFLOWER, x = -5600, y = 3072, z = -5290},
            {type = CANNON, x = 583, y = -1116, z = 2730},
            {type = CANNON, x = 3184, y = -1014, z = -3653},
            {type = CANNON, x = 4740, y = 2930, z = -2322},
            {type = BOOMERANG, x = -2380, y = -1116, z = -36},
            {type = BOOMERANG, x = -5344, y = -1935, z = 6565},
            {type = BOOMERANG, x = -6520, y = 3942, z = -2331}
        }
    },
    [LEVEL_TOTWC] = {
        {
            {type = HAMMER, x = 5, y = -2047, z = 1441},
            {type = FIREFLOWER, x = -1428, y = -2047, z = -4},
            {type = CANNON, x = 5, y = -2047, z = -1427},
            {type = BOOMERANG, x = 1433, y = -2047, z = -4}
        }
    },
    [LEVEL_COTMC] = {
        {
            {type = HAMMER, x = -300, y = 20, z = 1013},
            {type = FIREFLOWER, x = -104, y = 359, z = -5836},
            {type = CANNON, x = -326, y = 132, z = -2500},
            {type = BOOMERANG, x = 401, y = 111, z = -1580}
        }
    },
    [LEVEL_VCUTM] = {
        {
            {type = HAMMER, x = 159, y = -1817, z = -5898},
            {type = FIREFLOWER, x = -3241, y = 5734, z = -6172},
            {type = CANNON, x = -4670, y = -3276, z = 1218},
            {type = BOOMERANG, x = -2055, y = -2457, z = -5282}
        }
    },
    [LEVEL_BITDW] = {
        {
            {type = HAMMER, x = 1091, y = -2027, z = 3666},
            {type = FIREFLOWER, x = 1139, y = 2048, z = 245},
            {type = CANNON, x = 5784, y = 2765, z = 6},
            {type = BOOMERANG, x = -3686, y = 1024, z = -2138}
        }
    },
    [LEVEL_BITFS] = {
        {
            {type = HAMMER, x = 2060, y = -2457, z = -643},
            {type = FIREFLOWER, x = -5317, y = 3686, z = -805},
            {type = CANNON, x = -1861, y = 753, z = 283},
            {type = BOOMERANG, x = 1232, y = 5478, z = 39}
        }
    },
    [LEVEL_BITS] = {
        {
            {type = HAMMER, x = 1570, y = -4095, z = -8},
            {type = FIREFLOWER, x = 1661, y = -1453, z = -706},
            {type = CANNON, x = -3850, y = -409, z = -1100},
            {type = BOOMERANG, x = -2176, y = 2735, z = -889}
        }
    },
    [LEVEL_BOWSER_1] = {
        {
            {type = HAMMER, x = 1800, y = 307, z = -1800},
            {type = FIREFLOWER, x = -1800, y = 307, z = -1800},
            {type = CANNON, x = -1800, y = 307, z = 1800},
            {type = BOOMERANG, x = 1800, y = 307, z = 1800}
        }
    },
    [LEVEL_BOWSER_2] = {
        {
            {type = HAMMER, x = 1800, y = 1229, z = -1800},
            {type = FIREFLOWER, x = -1800, y = 1229, z = -1800},
            {type = CANNON, x = -1800, y = 1229, z = 1800},
            {type = BOOMERANG, x = 1800, y = 1229, z = 1800}
        }
    },
    [LEVEL_BOWSER_3] = {
        {
            {type = HAMMER, x = -1186, y = 307, z = 1645},
            {type = FIREFLOWER, x = -1704, y = 307, z = -549},
            {type = CANNON, x = -11, y = 307, z = -1936},
            {type = BOOMERANG, x = -1201, y = 3800, z = -895}
        }
    }
}

---@class PowerupData
---@field type integer
---@field model ModelExtendedId
---@field scale number
---@field yOffset integer
---@field pickupSound integer
---@field faceMario integer

POWERUP_DATA = {
    [UNKNOWN] = {type = UNKNOWN, model = E_MODEL_UNKNOWN_PU, scale = 1, yOffset = 30, pickupSound = SOUND_ACTION_METAL_HEAVY_LANDING, faceMario = 0 },
    [HAMMER] = {type = HAMMER, model = E_MODEL_HAMMER, scale = 1, yOffset = 10, pickupSound = SOUND_ACTION_METAL_HEAVY_LANDING, faceMario = 0 },
    [FIREFLOWER] = { type = FIREFLOWER, model = E_MODEL_FIRE_FLOWER, scale = 1, yOffset = 0, pickupSound = SOUND_MENU_EXIT_PIPE, faceMario = 1 },
    [CANNON] = {type = CANNON, model = E_MODEL_CANNON, scale = 0.9, yOffset = 20, pickupSound = SOUND_ACTION_METAL_HEAVY_LANDING, faceMario = 0},
    [BOOMERANG] = {type = BOOMERANG, model = E_MODEL_BOOMERANG, scale = 0.8, yOffset = 100, pickupSound = SOUND_ACTION_METAL_HEAVY_LANDING, faceMario = 0}
}

FIREFLOWER_RECOLOR_PARTS = {
    [CT_MARIO] = {
        [PANTS] = {r = 255, g = 0, b = 0},
        [SHIRT] = {r = 255, g = 255, b = 255},
        [GLOVES] = {r = 255, g = 255, b = 255},
        [CAP] = {r = 255, g = 255, b = 255}
    },
    [CT_LUIGI] = {
        [PANTS] = {r = 0, g = 124, b = 0},
        [SHIRT] = {r = 255, g = 255, b = 255},
        [GLOVES] = {r = 255, g = 255, b = 255},
        [CAP] = {r = 255, g = 255, b = 255}
    },
    [CT_WARIO] = {
        [PANTS] = {r = 219, g = 209, b = 0},
        [SHIRT] = {r = 255, g = 255, b = 255},
        [GLOVES] = {r = 255, g = 255, b = 255},
        [CAP] = {r = 255, g = 255, b = 255}
    },
    [CT_WALUIGI] = {
        [PANTS] = {r = 48, g = 0, b = 91},
        [SHIRT] = {r = 255, g = 255, b = 255},
        [GLOVES] = {r = 255, g = 255, b = 255},
        [CAP] = {r = 255, g = 255, b = 255}
    },
    [CT_TOAD] = {
        [PANTS] = {r = 255, g = 0, b = 0},
        [SHIRT] = {r = 255, g = 140, b = 0},
        [GLOVES] = {r = 255, g = 115, b = 0},
        [CAP] = {r = 255, g = 0, b = 0}
    }
}
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Aux Funcs ---------------------------------------------------------------------------------------------------

---@param cond boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

---@param globalIdx integer
---@return integer
function getLocalFromGlobalIdx(globalIdx)
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == globalIdx then
            return i
        end
    end
    return -1
end

---@return boolean
function localPlayerIsAloneInArea()
    local np1 = nps[0]
    for i = 1, MAX_PLAYERS - 1 do
        local np2 = nps[i]

        if np2.connected and np2.currAreaSyncValid and np2.currLevelSyncValid and
        np1.currLevelNum == np2.currLevelNum and
        np1.currActNum == np2.currActNum and
        np1.currAreaIndex == np2.currAreaIndex then
            return false
        end
    end
    return true
end

---@return boolean
function localPlayerHasLowestIndexInArea()
    local np1 = nps[0]
    for i = 1, MAX_PLAYERS - 1 do
        local np2 = nps[i]

        if np2.connected and np2.currAreaSyncValid and np2.currLevelSyncValid and
        np1.currLevelNum == np2.currLevelNum and
        np1.currActNum == np2.currActNum and
        np1.currAreaIndex == np2.currAreaIndex and
        np1.globalIndex > np2.globalIndex then
            return false
        end
    end
    return true
end

function spawnLocalPowerups()

    local positions = (POWERUPS_PER_LEVEL[nps[0].currLevelNum] or {})[nps[0].currAreaIndex] or {}

	for i = 1, #positions do
		local pu = positions[i]
		if pu then
			local data = POWERUP_DATA[ternary(globalTable.randomPowerups, UNKNOWN, pu.type)]
			if data then
				network_send_object(spawn_sync_object(id_bhvPowerup, data.model, pu.x, pu.y, pu.z, function(o)
					initPowerup(o, data)
				end), true)
			end
		end
	end
end

---@param posFrom Vec3f
---@param posTo Vec3f
---@return integer
function pos_pitch_to_pos(posFrom, posTo)
    local xzDist = sqrf((posTo.x - posFrom.x)^2 + (posTo.z - posFrom.z)^2)
    return atan2s(xzDist, posFrom.y - posTo.y)
end

---@param yaw integer
---@param target integer
---@param degRange number
---@return boolean
function targetAngleInYawRange(yaw, target, degRange)

    local degYaw = (sm64_to_degrees(yaw) + 180) % 360
    local degTarget = (sm64_to_degrees(target) + 180) % 360
    degRange = ((degRange + 180) % 360) / 2

    local min = (degYaw - degRange) % 360
    local max = (degYaw + degRange) % 360

    if min > max then
        return degTarget >= min or degTarget <= max
    else
        return degTarget >= min and degTarget <= max
    end
end

---@param origin Vec3f
---@param yaw integer
---@return Vec3f
function getHammerPos(origin, yaw)
    return {
        x = origin.x + 100 * sins(yaw),
		y = origin.y + 50,
		z = origin.z + 100 * coss(yaw)
    }
end

---@param m MarioState
---@param powerUpType integer
function spawnHeldItem(m, powerUpType)
    local id = nil
    local model = nil

    if powerUpType == HAMMER then
        id = id_bhvHeldHammer
        model = E_MODEL_HAMMER
    elseif powerUpType == CANNON then
        id = id_bhvHeldCannon
        model = E_MODEL_CANNON
    elseif powerUpType == BOOMERANG then
        id = id_bhvBoomerang
        model = E_MODEL_BOOMERANG
    end

    if id and model then
        local o = spawn_sync_object(id, model, m.pos.x, m.pos.y, m.pos.z, function (item)
            item.oPowerupHeldByPlayerIndex = nps[0].globalIndex
        end)
        m.usedObj = o
		network_send_object(o, true)
    end
end

---@param owner MarioState
---@param target MarioState
---@return boolean
function shouldHitWithPowerup(owner, target)

    if not owner or not target or owner.playerIndex == target.playerIndex or
    passes_pvp_interaction_checks(owner, target) == 0 then
        return false
    end

    return allowPvpAttack(states[owner.playerIndex], states[target.playerIndex])
end
--#endregion ----------------------------------------------------------------------------------------------------------
