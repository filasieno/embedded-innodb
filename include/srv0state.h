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

/// Define a single InnoDB global state type.
/// The type holds defines the state of a single instace of the InnoDB.
/// All fields will be prefixed to highlight the module the defines it.
struct InnoDB_state {

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

};

extern InnoDB_state state;



#endif //SRV0STATE_H
