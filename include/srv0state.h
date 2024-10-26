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

#include <fil0fil.h>
#include <innodb0types.h>

struct Log;

/// @brief Defines the embedded InnoDB State type.
///
/// The type defines the state of a single instace of the InnoDB.
struct InnoDB_state {

  /// If the following flag is set true, the module will print trace info
  /// of SQL execution in the UNIV_SQL_DEBUG version
  bool que_trace_on;

  /// Variable counts amount of data read in total (in bytes)
  ulint srv_data_read{0};

  /// @name Row stats variables
  /// @brief the row state variables to count row writes (insert, update, delete) and reads
  /// @{
  ulint srv_n_rows_inserted_old{0};
  ulint srv_n_rows_updated_old{0};
  ulint srv_n_rows_deleted_old{0};
  ulint srv_n_rows_read_old{0};

  ulint srv_n_rows_inserted{0};
  ulint srv_n_rows_updated{0};
  ulint srv_n_rows_deleted{0};
  ulint srv_n_rows_read{0};
  /// @}

  /// @name Database components
  /// @{
  AIO *srv_aio{nullptr};
  Log *log_sys{nullptr};
  /// @}

  /// @name Database files
  /// @{
  Fil *sys_fil{nullptr};
  Fil *srv_fil{nullptr};
  /// @}

  /// @name OS InnoDB State varaibles
  /// @{

  /// Use large pages. This may be a boot-time option on some platforms.
  bool os_use_large_pages{false};

  /// Large page size. This may be a boot-time option on some platforms
  ulint os_large_page_size{0};

  /// Number of reads from OS files.
  ulint os_n_file_reads{0};

  /// Number of writes to OS files.
  ulint os_n_file_writes{0};

  /// Number of flushes to OS files.
  ulint os_n_fsyncs{0};
  /// true if os has said that the this is full
  bool os_has_said_disk_full{false};

  /// Number of pending os_file_pread() operations
  std::atomic<ulint> os_file_n_pending_preads{0};

  /// Number of pending os_file_pwrite() operations
  std::atomic<ulint> os_file_n_pending_pwrites{0};

  /// Number of pending read operations
  std::atomic<ulint> os_n_pending_reads{0};

  /// Number of pending write operations
  std::atomic<ulint> os_n_pending_writes{0};

  /// @}
};

/// @brief A transitory global variable used to collect all global variables in InnoDB.
///
/// The variable is one of the key elements of the objective to make InnoDB reeentrant.
extern InnoDB_state state;

#endif //SRV0STATE_H
