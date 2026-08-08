#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <dispatch/dispatch.h>
#include <objc/runtime.h>

// ─── Offsets OB54 ────────────────────────────────────────────────
#define OFF_LogReportCheat          0x5729834
#define OFF_LogReportCheatInHistory 0x572A1E8
#define OFF_OnReportCheatClick      0x5F7BADC
#define OFF_OnMsgGroup_Cheating     0x6E5B6A4
#define OFF_ReportSent_1            0x1F6C298
#define OFF_ReportSent_2            0x21B9D78
#define OFF_ReportSent_3            0x2691C48
#define OFF_ReportSent_4            0x269B3E0
#define OFF_ReportSent_5            0x27EB5D0
#define OFF_ReportSent_6            0x30E6664
#define OFF_ReportSent_7            0x32A32D0
#define OFF_ReportSent_8            0x3420200
#define OFF_ReportSent_9            0x38FB6CC
#define OFF_ReportSent_10           0x3CD7904

// ─── ARM64 inline patch (NOP = 0xD503201F) ───────────────────────
static void nop_function(uintptr_t addr) {
    // RET instruction: 0xD65F03C0
    // Patch first instruction to RET so function returns immediately
    uint32_t ret_inst = 0xD65F03C0;

    vm_address_t page = addr & ~(vm_page_size - 1);
    vm_protect(mach_task_self(), page, vm_page_size, false,
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    uint32_t* ptr = (uint32_t*)addr;
    *ptr = ret_inst;

    vm_protect(mach_task_self(), page, vm_page_size, false,
               VM_PROT_READ | VM_PROT_EXECUTE);
}

// ─── Base address ────────────────────────────────────────────────
static uintptr_t getBase() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

static void applyPatches() {
    uintptr_t base = getBase();
    if (!base) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{ applyPatches(); }
        );
        return;
    }

    const uintptr_t targets[] = {
        base + OFF_LogReportCheat,
        base + OFF_LogReportCheatInHistory,
        base + OFF_OnReportCheatClick,
        base + OFF_OnMsgGroup_Cheating,
        base + OFF_ReportSent_1,
        base + OFF_ReportSent_2,
        base + OFF_ReportSent_3,
        base + OFF_ReportSent_4,
        base + OFF_ReportSent_5,
        base + OFF_ReportSent_6,
        base + OFF_ReportSent_7,
        base + OFF_ReportSent_8,
        base + OFF_ReportSent_9,
        base + OFF_ReportSent_10,
    };

    for (int i = 0; i < 14; i++) {
        nop_function(targets[i]);
    }
}

__attribute__((constructor))
static void init() {
    applyPatches();
}
