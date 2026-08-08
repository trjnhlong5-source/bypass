// FreeFireBypass — OB54 Anti-Cheat Suppressor
// Theos dylib | arm64 | iOS 14+
// by ktienxios offsets

#include <substrate.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

// ─── Base Address ─────────────────────────────────────────────────────────────
static uintptr_t getBase() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

// ─── OB54 Offsets ─────────────────────────────────────────────────────────────
#define OFF_LogReportCheat              0x5729834
#define OFF_LogReportCheatInHistory     0x572A1E8
#define OFF_OnReportCheatClick          0x5F7BADC
#define OFF_OnMsgGroup_Cheating         0x6E5B6A4

// OnReportCheatSent — 10 classes
#define OFF_ReportSent_LobbyLW          0x1F6C298
#define OFF_ReportSent_HudMatchResult   0x21B9D78
#define OFF_ReportSent_MultiTeamScore   0x2691C48
#define OFF_ReportSent_TeamBattle       0x269B3E0
#define OFF_ReportSent_FriendAdd        0x27EB5D0
#define OFF_ReportSent_FootballLB       0x30E6664
#define OFF_ReportSent_ObserverInter    0x32A32D0
#define OFF_ReportSent_SingleFight      0x3420200
#define OFF_ReportSent_ProfileBR        0x38FB6CC
#define OFF_ReportSent_VerticleView     0x3CD7904

// ─── Typedefs ─────────────────────────────────────────────────────────────────
typedef void (*LogReportCheat_t)(
    uintptr_t cheater, uint32_t reason, uintptr_t cheaterPlayerID,
    uintptr_t subReason, bool inGame, uint32_t reporteeType,
    int reportScene, uintptr_t cheaterClientVersion,
    uint32_t cheaterClientType, int reportMethod
);

typedef void (*LogReportCheatInHistory_t)(
    uintptr_t cheater, uint32_t reason, uintptr_t stats,
    uintptr_t matchID, uintptr_t subReason, uint32_t reporteeType,
    uintptr_t clientVer, uint32_t clientType, int reportMethod
);

typedef void (*VoidSelfParam_t)(uintptr_t self, uintptr_t param);
typedef void (*VoidRetMsg_t)(uint32_t ret, uintptr_t msg);

// ─── Original ptrs ────────────────────────────────────────────────────────────
static LogReportCheat_t          orig_LogReportCheat          = nullptr;
static LogReportCheatInHistory_t orig_LogReportCheatInHistory = nullptr;
static VoidSelfParam_t           orig_OnReportCheatClick      = nullptr;
static VoidRetMsg_t              orig_OnMsgGroupCheating      = nullptr;

// ─── Hooks ───────────────────────────────────────────────────────────────────

// Null out semua jalur report cheat ke server
static void hook_LogReportCheat(
    uintptr_t cheater, uint32_t reason, uintptr_t cheaterPlayerID,
    uintptr_t subReason, bool inGame, uint32_t reporteeType,
    int reportScene, uintptr_t cheaterClientVersion,
    uint32_t cheaterClientType, int reportMethod)
{
    // swallow — không gửi gì lên server
    return;
}

static void hook_LogReportCheatInHistory(
    uintptr_t cheater, uint32_t reason, uintptr_t stats,
    uintptr_t matchID, uintptr_t subReason, uint32_t reporteeType,
    uintptr_t clientVer, uint32_t clientType, int reportMethod)
{
    return;
}

// Block UI click report
static void hook_OnReportCheatClick(uintptr_t self, uintptr_t param) {
    return;
}

// Block notification cheating từ team
static void hook_OnMsgGroupCheating(uint32_t ret, uintptr_t msg) {
    return;
}

// Generic suppressor cho tất cả OnReportCheatSent
static void hook_OnReportCheatSent(uintptr_t self, uintptr_t param) {
    return;
}

// ─── Constructor ─────────────────────────────────────────────────────────────
__attribute__((constructor))
static void FFBypassInit() {
    uintptr_t base = getBase();
    if (!base) {
        // UnityFramework chưa load — retry sau 2s
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            FFBypassInit();
        });
        return;
    }

    // Hook LogReportCheat
    MSHookFunction(
        (void*)(base + OFF_LogReportCheat),
        (void*)hook_LogReportCheat,
        (void**)&orig_LogReportCheat
    );

    // Hook LogReportCheatInHistory
    MSHookFunction(
        (void*)(base + OFF_LogReportCheatInHistory),
        (void*)hook_LogReportCheatInHistory,
        (void**)&orig_LogReportCheatInHistory
    );

    // Hook OnReportCheatClick (UI button)
    MSHookFunction(
        (void*)(base + OFF_OnReportCheatClick),
        (void*)hook_OnReportCheatClick,
        (void**)&orig_OnReportCheatClick
    );

    // Hook OnMsgGroup_ShowTeamMateCheating
    MSHookFunction(
        (void*)(base + OFF_OnMsgGroup_Cheating),
        (void*)hook_OnMsgGroupCheating,
        (void**)&orig_OnMsgGroupCheating
    );

    // Hook semua OnReportCheatSent dari 10 class berbeda
    const uintptr_t sentOffsets[] = {
        OFF_ReportSent_LobbyLW,
        OFF_ReportSent_HudMatchResult,
        OFF_ReportSent_MultiTeamScore,
        OFF_ReportSent_TeamBattle,
        OFF_ReportSent_FriendAdd,
        OFF_ReportSent_FootballLB,
        OFF_ReportSent_ObserverInter,
        OFF_ReportSent_SingleFight,
        OFF_ReportSent_ProfileBR,
        OFF_ReportSent_VerticleView
    };

    for (int i = 0; i < 10; i++) {
        MSHookFunction(
            (void*)(base + sentOffsets[i]),
            (void*)hook_OnReportCheatSent,
            nullptr
        );
    }
}
