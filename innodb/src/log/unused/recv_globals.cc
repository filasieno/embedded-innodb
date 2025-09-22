/****************************************************************************
Copyright (c) 2025 Sunny Bains. All rights reserved.

Redo recovery globals and initialization.
*****************************************************************************/

#include "log0recv.h"
#include "mem0mem.h"

// Global recovery state
Recv_sys* recv_sys = nullptr;
bool      recv_recovery_on{};
bool      recv_needed_recovery{};
bool      recv_lsn_checks_on{};
ib_cb_t   recv_pre_rollback_hook{};

// Tuning/diagnostic globals referenced from other subsystems
ulint recv_n_pool_free_frames{};
lsn_t recv_max_page_lsn{};
ulint recv_max_parsed_page_no{};

void recv_sys_var_init() noexcept {
  ut_a(recv_sys == nullptr);

  recv_lsn_checks_on      = false;
  recv_n_pool_free_frames = 256; // default; adjusted at open()
  recv_recovery_on        = false;
  recv_needed_recovery    = false;
  recv_max_parsed_page_no = 0;
  recv_max_page_lsn       = 0;
}


