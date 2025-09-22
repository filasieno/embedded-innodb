/****************************************************************************
Copyright (c) 2025 Sunny Bains. All rights reserved.

Runtime glue for redo log globals and lifecycle.
*****************************************************************************/

#include "log0log.h"
#include "mem0mem.h"
#include "ut0lst.h"
#include "os0sync.h"
#include "os0aio.h"
#include "mach0data.h"
#include "ut0logger.h"

// Define globals that were previously in monolithic sources
Log *log_sys = nullptr;

#ifdef UNIV_DEBUG
bool log_do_write = true;
#endif

bool log_has_printed_chkp_warning = false;
time_t log_last_warning_time = 0;
ulint log_fsp_current_free_limit = 0;

void Log::var_init() noexcept {
  ut_a(log_sys == nullptr);
  log_last_warning_time = 0;
  log_fsp_current_free_limit = 0;
  log_has_printed_chkp_warning = false;
}

Log::Log() noexcept {
  mutex_create(&m_mutex, IF_DEBUG("log_sys_mutex", ) IF_SYNC_DEBUG(SYNC_LOG, ) Current_location());

  acquire();

  m_lsn = LOG_START_LSN;

  ut_a(LOG_BUFFER_SIZE >= 16 * IB_FILE_BLOCK_SIZE);
  ut_a(LOG_BUFFER_SIZE >= 4 * UNIV_PAGE_SIZE);

  m_buf_ptr = static_cast<byte *>(mem_alloc(LOG_BUFFER_SIZE + IB_FILE_BLOCK_SIZE));
  m_buf = static_cast<byte *>(ut_align(m_buf_ptr, IB_FILE_BLOCK_SIZE));
  m_buf_size = LOG_BUFFER_SIZE;
  memset(m_buf, '\0', LOG_BUFFER_SIZE);

  m_max_buf_free = m_buf_size / 2 - (4 * IB_FILE_BLOCK_SIZE + 4 * UNIV_PAGE_SIZE);
  m_check_flush_or_checkpoint = true;
  UT_LIST_INIT(m_log_groups);

  m_n_log_ios = 0;
  m_n_log_ios_old = m_n_log_ios;
  m_last_printout_time = time(nullptr);

  m_buf_next_to_write = 0;
  m_write_lsn = 0;
  m_current_flush_lsn = 0;
  m_flushed_to_disk_lsn = 0;
  m_written_to_some_lsn = m_lsn;
  m_written_to_all_lsn = m_lsn;
  m_n_pending_writes = 0;

  m_no_flush_event = os_event_create(nullptr);
  os_event_set(m_no_flush_event);
  m_one_flushed_event = os_event_create(nullptr);
  os_event_set(m_one_flushed_event);

  m_adm_checkpoint_interval = ULINT_MAX;
  m_next_checkpoint_no = 0;
  m_last_checkpoint_lsn = m_lsn;
  m_n_pending_checkpoint_writes = 0;

  rw_lock_create(&m_checkpoint_lock, SYNC_NO_ORDER_CHECK);

  m_checkpoint_buf_ptr = static_cast<byte *>(mem_alloc(2 * IB_FILE_BLOCK_SIZE));
  m_checkpoint_buf = static_cast<byte *>(ut_align(m_checkpoint_buf_ptr, IB_FILE_BLOCK_SIZE));
  memset(m_checkpoint_buf, '\0', IB_FILE_BLOCK_SIZE);

  block_init(m_buf, m_lsn);
  block_set_first_rec_group(m_buf, LOG_BLOCK_HDR_SIZE);
  m_buf_free = LOG_BLOCK_HDR_SIZE;
  m_lsn = LOG_START_LSN + LOG_BLOCK_HDR_SIZE;

  release();
}

Log::~Log() noexcept {
  // Minimal; full cleanup handled by shutdown()/destroy()
}

Log *Log::create() noexcept {
  ut_a(log_sys == nullptr);
  log_sys = static_cast<log_t *>(mem_alloc(sizeof(Log)));
  new (log_sys) Log();
  return log_sys;
}

void Log::destroy(Log *&ptr) noexcept {
  if (ptr != nullptr) {
    call_destructor(ptr);
    mem_free(ptr);
    ptr = nullptr;
  }
}

void Log::shutdown() noexcept {
  if (log_sys == nullptr) {
    return;
  }
  // Minimal cleanup; detailed resource free happens elsewhere in split modules
}


