/****************************************************************************
Copyright (c) 2024 Sunny Bains. All rights reserved.

Portions of this file contain modifications contributed and copyrighted by
Google, Inc. Those modifications are gratefully acknowledged and are described
briefly in the InnoDB documentation. The contributions by Google are
incorporated with their permission, and subject to the conditions contained in
the file COPYING.Google.

Portions of this file contain modifications contributed and copyrighted
by Percona Inc.. Those modifications are
gratefully acknowledged and are described briefly in the InnoDB
documentation. The contributions by Percona Inc. are incorporated with
their permission, and subject to the conditions contained in the file
COPYING.Percona.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; version 2 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA 02111-1307 USA

*****************************************************************************/

#ifndef SRV0STATE_H
#define SRV0STATE_H

#include <innodb0types.h>
#include <atomic>

struct Config {
  /** Location of the system tablespace. */
  char *m_data_home{};

  /** Location of the redo log group files. */
  char *m_log_group_home_dir{};

  /** Whether to create a new file for each table. */
  bool m_file_per_table{};

  /** Whether a new raw disk partition was initialized. */
  bool m_created_new_raw{};

  /** Number of log files. */
  ulint m_n_log_files{ULINT_MAX};

  /** Size of each log file, in pages. */
  ulint m_log_file_size{ULINT_MAX};

  /** Current size of the log file, in pages. */
  ulint m_log_file_curr_size{ULINT_MAX};

  /** Size of the log buffer, in pages. */
  ulint m_log_buffer_size{ULINT_MAX};

  /** Current size of the log buffer, in pages. */
  ulint m_log_buffer_curr_size{ULINT_MAX};

  /** Whether to flush the log at transaction commit. */
  ulong m_flush_log_at_trx_commit{1};

  /** Whether to use adaptive flushing. */
  bool m_adaptive_flushing{true};

  /** Whether to use sys malloc. */
  bool m_use_sys_malloc{true};

  /** Size of the buffer pool, in pages. */
  ulint m_buf_pool_size{ULINT_MAX};

  /** Old size of the buffer pool, in pages. */
  ulint m_buf_pool_old_size{ULINT_MAX};

  /** Current size of the buffer pool, in pages. */
  ulint m_buf_pool_curr_size{};

  /** Memory pool size in bytes */
  ulint m_mem_pool_size{ULINT_MAX};

  /** Size of the lock table, in pages. */
  ulint m_lock_table_size{ULINT_MAX};

  /** Number of read I/O threads. */
  ulint m_n_read_io_threads{ULINT_MAX};

  /** Number of write I/O threads. */
  ulint m_n_write_io_threads{ULINT_MAX};

  /** User settable value of the number of pages that must be present
   * in the buffer cache and accessed sequentially for InnoDB to trigger a
   * readahead request. */
  ulong m_read_ahead_threshold{56};

  /** Number of IO operations per second the server can do */
  ulong m_io_capacity{200};

  /** File flush method. */
  ulint m_unix_file_flush_method{SRV_UNIX_FSYNC};

  /** Maximum number of open files. */
  ulint m_max_n_open_files{1024};

  /** We are prepared for a situation that we have this many threads waiting
   * for a semaphore inside InnoDB. innobase_start_or_create() sets the value. */
  ulint m_max_n_threads{0};

  /** Force recovery. */
  ib_recovery_t m_force_recovery{IB_RECOVERY_DEFAULT};

  /** Fast shutdown. */
  ib_shutdown_t m_fast_shutdown{IB_SHUTDOWN_NORMAL};

  /** Generate a innodb_status.<pid> file if this is true. */
  bool m_status{false};

  /** When estimating number of different key values in an index, sample
   * this many index pages */
  uint64_t m_stats_sample_pages{8};

  /** Whether to use doublewrite buffer. */
  bool m_use_doublewrite_buf{true};

  /** Whether to use checksums. */
  bool m_use_checksums{true};

  /** The InnoDB main thread tries to keep the ratio of modified pages
   * in the buffer pool to all database pages in the buffer pool smaller than
   * the following number. But it is not guaranteed that the value stays below
   * that during a time of heavy update/insert activity. */
  ulong m_max_buf_pool_modified_pct{90};

  /* Maximum allowable purge history length. <= 0 means 'infinite'. */
  ulong m_max_purge_lag{0};
};

/// @brief Define a single InnoDB global state type.
///
/// The type holds defines the state of a single instace of the InnoDB.
/// All fields will be prefixed to highlight the module the defines it.
///
struct InnoDB_state {
  /// @name General InnoDB Server state variables
  /// @{

  Config srv_config;

  /// true if the server is being started
  bool srv_is_being_started{false};

  /// true if the server was successfully started
  bool srv_was_started{false};

  /// @}

  /// @name OS InnoDB state variables
  /// @{

  /// If the following is true, read i/o handler threads try to wait until a batch
  /// of new read requests have been posted
  bool os_aio_recommend_sleep_for_read_threads{false};

  /// Number of reads from OS files.
  ulint os_n_file_reads{0};
  ulint os_n_file_reads_old{0};

  /// Number of writes to OS files.
  ulint os_n_file_writes{0};
  ulint os_n_file_writes_old{0};

  /// Number of flushes to OS files.
  ulint os_n_fsyncs{0};
  ulint os_n_fsyncs_old{0};

  /// Number of bytes read since the last printout
  time_t os_last_printout;
  ulint os_bytes_read_since_printout{0};

  /// true if os has said that the this is full
  bool os_has_said_disk_full{false};

  /// Number of pending os_file_pread() operations
  std::atomic<ulint> os_file_n_pending_preads{};

  /// Number of pending os_file_pwrite() operations
  std::atomic<ulint> os_file_n_pending_pwrites{};

  /// Number of pending read operations
  std::atomic<ulint> os_n_pending_reads{};

  /// Number of pending write operations
  std::atomic<ulint> os_n_pending_writes{};

  /// @}

  [[nodiscard]] size_t log_buffer_size() const { return srv_config.m_log_buffer_size * UNIV_PAGE_SIZE; }

  [[nodiscard]] ulint max_n_threads() const { return srv_config.m_max_n_threads; }

  /// @name Activity Thresholds
  /// The master thread performs various tasks based on the current
  /// state of I/O activity and the level of IO utilization is past
  /// intervals.
  ///
  /// Following utilities define thresholds for these conditions.
  ///
  /// @{

  /// @brief Returns the number of IO operations that is `pct` percent of the capacity.
  /// Example: `state.pct_io(5)`: returns the number of IO operations that is 5% of the max where max is srv_io_capacity.
  /// @return the number of IO operations that is X percent of the
  [[nodiscard]] ulong pct_io(const ulong pct) const {
    const auto value = static_cast<double>(srv_config.m_io_capacity) * (static_cast<double>(pct) / 100.0);
    return static_cast<ulong>(value);
  }

  /// @brief Returns the pending I/O threshold measured in I/O operations defined as a percentage of the `m_io_capacity`
  /// Currently fixed to 3% of the maximum capacity I/O capacity.
  ///
  /// @return The pending I/O threshold measured in I/O operations
  [[nodiscard]] constexpr ulong pend_io_threshold() const { return pct_io(3); }

  /// @brief Returns the recent I/O activity as a percentage of the maximum I/O capacity.
  /// Currently fixed to 5% of the maximum capacity I/O capacity.
  ///
  /// @return The number of I/O operations that is the specified percentage of the system's maximum I/O capacity.
  [[nodiscard]] constexpr ulong recent_io_activity() const { return pct_io(5); }

  [[nodiscard]] constexpr ulong past_io_activity() const { return pct_io(200); }

  /// @}
};

extern InnoDB_state state;

#endif  //SRV0STATE_H
