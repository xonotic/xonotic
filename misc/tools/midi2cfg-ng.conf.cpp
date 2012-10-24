#define USE_CHEATS
#undef FAST
#define BOW
#define INDICATORS

#ifdef FAST
timeoffset_preinit 0
timeoffset_postinit 0
timeoffset_predone 0
timeoffset_postdone 0
timeoffset_preintermission 0
timeoffset_postintermission 0
list WAIT_SELECTWEAPON 0.2
list WAIT_RELOAD 0.5
list WAIT_AIMTARGET 0.1
#else
timeoffset_preinit 2
timeoffset_postinit 2
timeoffset_predone 2
timeoffset_postdone 2
timeoffset_preintermission 2
timeoffset_postintermission 2
list WAIT_SELECTWEAPON 0.5
list WAIT_RELOAD 0.5
list WAIT_AIMTARGET 1
#endif

time_forgetfulness 3

list places_tuba tUba1 tUba2 tUba3 tUba4 tUba5 tUba6 tUba7 tUba8 tUba9 tUba10 tUba11 tUba12 tUba13 tUba14 tUba15 tUba16 tUba17 tUba18 tUba19 tUba20 tUba21 tUba22 tUba23 tUba24 tUba25 tUba26 tUba27 tUba28 tUba29 tUba30 tUba31 tUba32
list places_percussion tChr1 tChr2 tChr3 tChr4 tChr5 tChr6 tChr7 tChr8 tChr9 tChr10 tChr11 tChr12 tChr13 tChr14 tChr15 tChr16 tChr17 tChr18 tChr19 tChr20 tChr21 tChr22 tChr23 tChr24 tChr25 tChr26 tChr27 tChr38 tChr39 tChr30 tChr31 tChr32
list places_vocals tVocals
list places_metalsteps tMetalSteps1 tMetalSteps2 tMetalSteps3
list places_nosteps tNoSteps1 tNoSteps2 tNoSteps3 tNoSteps4

raw settemp bot_ai_thinkinterval 0
raw settemp g_balance_tuba_attenuation 0.1
// raw settemp bot_sound_monopoly 1

bot notebot
	note on -18
		time 0
		cmd debug_assert_canfire 1
		buttons left backward crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -18
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -17
		time 0
		cmd debug_assert_canfire 1
		buttons backward crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -17
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -16
		time 0
		cmd debug_assert_canfire 1
		buttons right backward crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -16
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -13
		time 0
		cmd debug_assert_canfire 1
		buttons forward right crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -13
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -12
		time 0
		cmd debug_assert_canfire 1
		buttons crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -12
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -11
		time 0
		cmd debug_assert_canfire 1
		buttons left backward crouch attack2
		aim_random -5 5 0.05
		time 0.05
	note off -11
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -10
		time 0
		cmd debug_assert_canfire 1
		buttons right crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -10
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -9
		time 0
		cmd debug_assert_canfire 1
		buttons forward left crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -9
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -8
		time 0
		cmd debug_assert_canfire 1
		buttons forward crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -8
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -7
		time 0
		cmd debug_assert_canfire 1
		buttons left crouch attack1
		aim_random -5 5 0.05
		time 0.05
	note off -7
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -6
		time 0
		cmd debug_assert_canfire 1
		buttons left backward attack1
		aim_random -5 5 0.05
		time 0.05
	note off -6
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -5
		time 0
		cmd debug_assert_canfire 1
		buttons backward attack1
		aim_random -5 5 0.05
		time 0.05
	note off -5
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -4
		time 0
		cmd debug_assert_canfire 1
		buttons backward right attack1
		aim_random -5 5 0.05
		time 0.05
	note off -4
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -3
		time 0
		cmd debug_assert_canfire 1
		buttons right crouch attack2
		aim_random -5 5 0.05
		time 0.05
	note off -3
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -2
		time 0
		cmd debug_assert_canfire 1
		buttons forward left crouch attack2
		aim_random -5 5 0.05
		time 0.05
	note off -2
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on -1
		time 0
		cmd debug_assert_canfire 1
		buttons forward right attack1
		aim_random -5 5 0.05
		time 0.05
	note off -1
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 0
		time 0
		cmd debug_assert_canfire 1
		buttons attack1
		aim_random -5 5 0.05
		time 0.05
	note off 0
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 1
		time 0
		cmd debug_assert_canfire 1
		buttons left backward attack2
		aim_random -5 5 0.05
		time 0.05
	note off 1
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 2
		time 0
		cmd debug_assert_canfire 1
		buttons right attack1
		aim_random -5 5 0.05
		time 0.05
	note off 2
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 3
		time 0
		cmd debug_assert_canfire 1
		buttons forward left attack1
		aim_random -5 5 0.05
		time 0.05
	note off 3
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 4
		time 0
		cmd debug_assert_canfire 1
		buttons forward attack1
		aim_random -5 5 0.05
		time 0.05
	note off 4
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 5
		time 0
		cmd debug_assert_canfire 1
		buttons left attack1
		aim_random -5 5 0.05
		time 0.05
	note off 5
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 6
		time 0
		cmd debug_assert_canfire 1
		buttons forward right attack2
		aim_random -5 5 0.05
		time 0.05
	note off 6
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 7
		time 0
		cmd debug_assert_canfire 1
		buttons attack2
		aim_random -5 5 0.05
		time 0.05
	note off 7
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 8
		time 0
		cmd debug_assert_canfire 1
		buttons backward right jump attack1
		aim_random -5 5 0.05
		time 0.05
	note off 8
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 9
		time 0
		cmd debug_assert_canfire 1
		buttons right attack2
		aim_random -5 5 0.05
		time 0.05
	note off 9
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 10
		time 0
		cmd debug_assert_canfire 1
		buttons forward left attack2
		aim_random -5 5 0.05
		time 0.05
	note off 10
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 11
		time 0
		cmd debug_assert_canfire 1
		buttons forward attack2
		aim_random -5 5 0.05
		time 0.05
	note off 11
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 12
		time 0
		cmd debug_assert_canfire 1
		buttons left attack2
		aim_random -5 5 0.05
		time 0.05
	note off 12
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 13
		time 0
		cmd debug_assert_canfire 1
		buttons left backward jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 13
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 14
		time 0
		cmd debug_assert_canfire 1
		buttons right jump attack1
		aim_random -5 5 0.05
		time 0.05
	note off 14
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 15
		time 0
		cmd debug_assert_canfire 1
		buttons forward left jump attack1
		aim_random -5 5 0.05
		time 0.05
	note off 15
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 16
		time 0
		cmd debug_assert_canfire 1
		buttons forward jump attack1
		aim_random -5 5 0.05
		time 0.05
	note off 16
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 17
		time 0
		cmd debug_assert_canfire 1
		buttons left jump attack1
		aim_random -5 5 0.05
		time 0.05
	note off 17
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 18
		time 0
		cmd debug_assert_canfire 1
		buttons forward right jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 18
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 19
		time 0
		cmd debug_assert_canfire 1
		buttons jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 19
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 21
		time 0
		cmd debug_assert_canfire 1
		buttons right jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 21
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 22
		time 0
		cmd debug_assert_canfire 1
		buttons forward left jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 22
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 23
		time 0
		cmd debug_assert_canfire 1
		buttons forward jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 23
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0
	note on 24
		time 0
		cmd debug_assert_canfire 1
		buttons left jump attack2
		aim_random -5 5 0.05
		time 0.05
	note off 24
		time -0.05
		cmd debug_assert_canfire 0
		buttons 
		aim_random -5 5 0.05
		time 0

bot tuba
	include notebot
	channels 1 2 3 4 5 6 7 8 9 11 12 13 14 15 16
	programs 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127 128
	transpose 48
	init
		cmd barrier
		cmd selectweapon 15
		cmd wait @WAIT_SELECTWEAPON
#ifdef INDICATORS
	note on -18
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -17
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -16
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -13
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -12
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note off -12
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -11
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -10
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -9
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -8
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -7
		time 0
		cmd cc usetarget indicator_tuba0
		super
	note on -6
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on -5
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on -4
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on -3
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on -2
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on -1
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 0
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 1
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 2
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 3
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 4
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 5
		time 0
		cmd cc usetarget indicator_tuba1
		super
	note on 6
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 7
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 8
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 9
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 10
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 11
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 12
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 13
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 14
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 15
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 16
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 17
		time 0
		cmd cc usetarget indicator_tuba2
		super
	note on 18
		time 0
		cmd cc usetarget indicator_tuba3
		super
	note on 19
		time 0
		cmd cc usetarget indicator_tuba3
		super
	note on 21
		time 0
		cmd cc usetarget indicator_tuba3
		super
	note on 22
		time 0
		cmd cc usetarget indicator_tuba3
		super
	note on 23
		time 0
		cmd cc usetarget indicator_tuba3
		super
	note on 24
		time 0
		cmd cc usetarget indicator_tuba3
		super
#endif

bot accordeon
	include notebot
	channels 1 2 3 4 5 6 7 8 9 11 12 13 14 15 16
	programs 22 23 24
	transpose 60
	init
		cmd barrier
		cmd selectweapon 15
		cmd wait @WAIT_SELECTWEAPON
		cmd impulse 20
		cmd wait @WAIT_RELOAD
#ifdef INDICATORS
	note on -18
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -17
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -16
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -13
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -12
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note off -12
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -11
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -10
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -9
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -8
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -7
		time 0
		cmd cc usetarget indicator_accordeon0
		super
	note on -6
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on -5
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on -4
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on -3
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on -2
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on -1
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 0
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 1
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 2
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 3
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 4
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 5
		time 0
		cmd cc usetarget indicator_accordeon1
		super
	note on 6
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 7
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 8
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 9
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 10
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 11
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 12
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 13
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 14
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 15
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 16
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 17
		time 0
		cmd cc usetarget indicator_accordeon2
		super
	note on 18
		time 0
		cmd cc usetarget indicator_accordeon3
		super
	note on 19
		time 0
		cmd cc usetarget indicator_accordeon3
		super
	note on 21
		time 0
		cmd cc usetarget indicator_accordeon3
		super
	note on 22
		time 0
		cmd cc usetarget indicator_accordeon3
		super
	note on 23
		time 0
		cmd cc usetarget indicator_accordeon3
		super
	note on 24
		time 0
		cmd cc usetarget indicator_accordeon3
		super
#endif

bot kleinbottle
	include notebot
	channels 1 2 3 4 5 6 7 8 9 11 12 13 14 15 16
	programs 81 82
	transpose 48
	init
		cmd barrier
		cmd selectweapon 15
		cmd wait @WAIT_SELECTWEAPON
		cmd impulse 20
		cmd wait @WAIT_RELOAD
		cmd impulse 20
		cmd wait @WAIT_RELOAD
#ifdef INDICATORS
	note on -18
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -17
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -16
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -13
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -12
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note off -12
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -11
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -10
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -9
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -8
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -7
		time 0
		cmd cc usetarget indicator_kleinbottle0
		super
	note on -6
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on -5
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on -4
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on -3
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on -2
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on -1
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 0
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 1
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 2
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 3
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 4
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 5
		time 0
		cmd cc usetarget indicator_kleinbottle1
		super
	note on 6
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 7
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 8
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 9
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 10
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 11
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 12
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 13
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 14
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 15
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 16
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 17
		time 0
		cmd cc usetarget indicator_kleinbottle2
		super
	note on 18
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
	note on 19
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
	note on 21
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
	note on 22
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
	note on 23
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
	note on 24
		time 0
		cmd cc usetarget indicator_kleinbottle3
		super
#endif

bot tuba_red
	include tuba
	transpose 0
	init
		cmd cc color 68
		super

bot tuba_blue
	include tuba
	transpose 3
	init
		cmd cc color 221
		super

bot accordeon_red
	include accordeon
	transpose 0
	init
		cmd cc color 68
		super

bot accordeon_blue
	include accordeon
	transpose 3
	init
		cmd cc color 221
		super

bot kleinbottle_red
	include kleinbottle
	transpose 0
	init
		cmd cc color 68
		super

bot kleinbottle_blue
	include kleinbottle
	transpose 3
	init
		cmd cc color 221
		super

// laser = lasershot NONE
bot laser
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 1
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_laser_primary_refire 0.3
	percussion 38 // 038_Snare_1-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_laser1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.3
	percussion 40 // 040_Snare_2-0.wav
		percussion 38

// shotgun = RELOADSOUND slap
bot shotgun
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 2
		cmd wait @WAIT_SELECTWEAPON
	percussion 74 // 074_Guiro_2_Long-0.wav
		time -0.4
		cmd debug_assert_canfire 1
		buttons attack2
		time -0.35
		cmd debug_assert_canfire 0
		buttons
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_shotgun2
#endif
		busy 1.1
	percussion 73 // 073_Guiro_1_Short-0.wav
		percussion 74

// uzi = bullet BAD
bot uzi
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 3
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_uzi_reload_ammo 0
		raw settemp g_balance_uzi_first_refire 0.1
		raw settemp g_balance_uzi_sustained_refire 0.1
		raw settemp g_casings 0
	percussion 27 // 027_High_Q-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_uzi1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.1
	percussion 31 // 031_Sticks-0.wav
		percussion 27
	percussion 37 // 037_Stick_Rim-0.wav
		percussion 27
	percussion 33 // 033_Metronome_Click-0.wav
		percussion 27
	percussion 53 // 053_Cymbal_Ride_Bell-0.wav
		percussion 27
	percussion 54 // 054_Tambourine-0.wav
		percussion 27

// grenadelauncher = RELOADSOUND RELOADSOUND

// electro = beam BADFLYSOUND
bot electro
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 6
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_electro_primary_refire 0.2
	percussion 49 // 049_Cymbal_Crash_1-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_electro1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.2
	percussion 57 // 057_Cymbal_Crash_2-0.wav
		percussion 49

// crylink = big small
bot crylink
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 7
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_crylink_primary_refire 0.3
		raw settemp g_balance_crylink_secondary_refire 0.2
	percussion 34 // 034_Metronome_Bell-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_crylink1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.3
	percussion 45 // 045_Tom_Mid_2-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_crylink2
#endif
		cmd debug_assert_canfire 1
		buttons attack2
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.2
	percussion 47 // 047_Tom_Mid_1-0.wav
		percussion 45
	percussion 48 // 048_Tom_High_2-0.wav
		percussion 34
	percussion 50 // 048_Tom_High_2-0.wav
		percussion 34
	percussion 56 // 056_Cow_Bell-0.wav
		percussion 34
	percussion 67 // 067_Agogo_High-0.wav
		percussion 34
	percussion 68 // 068_Agogo_Low-0.wav
		percussion 45
	percussion 71 // 071_Whistle_1_High_Short-0.wav
		percussion 34
	percussion 72 // 072_Whistle_2_Low_Long-0.wav
		percussion 45
	percussion 75 // 075_Claves-0.wav
		percussion 34

// nex is nex NONE
bot nex
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 8
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_nex_primary_refire 1.25
	percussion 52 // 052_Cymbal_Chinese-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_nex1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 1.25

// minstanex is nex CLONE_OF_LASER
bot minstanex
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 12
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_minstanex_refire 1
	percussion 55 // 055_Cymbal_Splash-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_minstanex1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 1

// hagar is rocket BAD
bot hagar
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 9
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_hagar_primary_refire 0.2
	percussion 35 // 035_Kick_1-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_hagar1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.2
	percussion 39 // 039_Clap_Hand-0.wav
		percussion 35
	percussion 60 // 060_Bongo_High-0.wav
		percussion 35
	percussion 61 // 061_Bongo_Low-0.wav
		percussion 35

// TODO hookbomb would be useful for //60

// RL is rocket NONE
bot rocket
	channels 10
	init
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 10
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_rocketlauncher_refire 1.1
	percussion 25 // 025_Snare_Roll-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_rocketlauncher1
#endif
		cmd debug_assert_canfire 1
		buttons attack2
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 1.1

// hook is hook bomb
bot hook
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 13
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_hook_primary_refire 0.3
		raw settemp g_balance_hook_secondary_refire 0.9
	percussion 62 // 062_Conga_High_1_Mute-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_hook1
#endif
		cmd debug_assert_canfire 1
		buttons attack1
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.3
	percussion 63 // 063_Conga_High_2_Open-0.wav
		percussion 62
	percussion 84 // 084_Belltree-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_hook2
#endif
		cmd debug_assert_canfire 1
		buttons attack2
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.9
	percussion 81 // 081_Triangle_2_Open-0.wav
		percussion 62
	percussion 80 // 081_Triangle_1_Mute-0.wav
		percussion 62

// seeker is BADFLYSOUND tag
bot seeker
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 18
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_seeker_tag_refire 0.2
	percussion 41 // 041_Tom_Low_2-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_seeker2
#endif
		cmd debug_assert_canfire 1
		buttons attack2
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.2
	percussion 51 // 051_Cymbal_Ride_1-0.wav
		percussion 41
	percussion 43 // 043_Tom_Low_1-0.wav
		percussion 41
	percussion 59 // 059_Cymbal_Ride_2-0.wav
		percussion 41
	percussion 46 // 046_Hi-Hat_Open-0.wav
		percussion 41
	percussion 69 // 069_Cabasa-0.wav
		percussion 41
	percussion 82 // 069_Shaker-0.wav
		percussion 41

// rifle is hard soft
bot rifle
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		cmd selectweapon 16
		cmd wait @WAIT_SELECTWEAPON
		raw settemp g_balance_rifle_secondary_refire 0.3
//	percussion FIXME
//		time 0
//		cmd debug_assert_canfire 1
//		buttons attack1
//		time 0.05
//		cmd debug_assert_canfire 0
//		buttons
//		time 0.1
//		busy 1.2
	percussion 58 // 058_Vibra-Slap-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_rifle2
#endif
		cmd debug_assert_canfire 1
		buttons attack2
		time 0.05
		cmd debug_assert_canfire 0
		buttons
		time 0.1
		busy 0.9

bot jetpack
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
		raw settemp g_jetpack_attenuation 0.5
	percussion 42 // 042_Hi-Hat_Closed-0.wav
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_jetpack
#endif
		buttons hook
		time 0.05
		buttons
	percussion 32 // 032_Square_Click-0.wav
		percussion 42
	percussion 44 // 044_Hi-Hat_Pedal-0.wav
		percussion 42
	percussion 64 // 064_Conga_Low-0.wav
		percussion 42
	percussion 70 // 070_Maracas-0.wav
		percussion 42

bot jumper
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
	percussion 36 // 036_Kick_2-0.wav
		time -0.6666666
		buttons jump
		time -0.5
		buttons
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_jump
#endif
		busy 0.1

bot metaljumper
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
	percussion 65 // 065_Timbale_High-0.wav
		time -0.6666666
		buttons jump
		time -0.5
		buttons
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_metaljump
#endif
		busy 0.1
	percussion 66 // 066_Timbale_Low-0.wav
		percussion 65

bot switcher
	channels 10
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
	percussion 29 // not in freepats
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_switch
#endif
		cmd impulse 10
		time 0.05
		busy 0.3
	percussion 30 // not in freepats
		percussion 29

bot vocals
	init
		time -2
		cmd aimtarget tPercussion @WAIT_AIMTARGET
		cmd barrier
	text vocals
		time 0
#ifdef INDICATORS
		cmd cc usetarget indicator_vocals
#endif
		cmd sound -10 %s
		buttons crouch
		time 0.05
		buttons 

bot common
	done
		cmd resetaim
		cmd aim 270 0
		cmd wait 1
#ifdef BOW
		barrier
		buttons crouch
		cmd wait 3
		buttons
		cmd wait 1
		barrier
#endif
		buttons use
		cmd cc kill
		cmd wait 900


// instantiate our bots!

bot instance_tuba_red
	include tuba_red
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_tuba_blue
	include tuba_blue
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_accordeon_red
	include accordeon_red
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_accordeon_blue
	include accordeon_blue
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_kleinbottle_red
	include kleinbottle_red
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_kleinbottle_blue
	include kleinbottle_blue
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_tuba
#else
		cmd movetotarget @places_tuba
#endif
		cmd barrier
		super

bot instance_laser
	include laser
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_shotgun
	include shotgun
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_uzi
	include uzi
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_electro
	include electro
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_crylink
	include crylink
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_nex
	include nex
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_minstanex
	include minstanex
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_hagar
	include hagar
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_rocket
	include rocket
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_hook
	include hook
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_seeker
	include seeker
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_rifle
	include rifle
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_jetpack
	include jetpack
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_nosteps
#else
		cmd movetotarget @places_nosteps
#endif
		cmd barrier
		super

bot instance_jumper
	include jumper
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_metaljumper
	include metaljumper
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_metalsteps
#else
		cmd movetotarget @places_metalsteps
#endif
		cmd barrier
		super

bot instance_switcher
	include switcher
	include common
	count 16
	init
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_percussion
#else
		cmd movetotarget @places_percussion
#endif
		cmd barrier
		super

bot instance_vocals
	include vocals
	include common
	count 1
	init
		cmd cc playermodel models/player/suiseiseki.zym
#ifdef USE_CHEATS
		cmd cc teleporttotarget @places_vocals
#else
		cmd movetotarget @places_vocals
#endif
		cmd barrier
		super

// TODO jumping?
