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

/// Define a single InnoDB global state type.
/// The type holds defines the state of a single instace of the InnoDB.
/// All fields will be prefixed to highlight the module the defines it.
struct InnoDB_state {

  // ------------------------------------------------------------------------
  // Sys and Srv files
  // ------------------------------------------------------------------------
  Fil *sys_fil;
  Fil *srv_fil;

  // ------------------------------------------------------------------------
  // OS Proc
  // ------------------------------------------------------------------------

  /// Use large pages. This may be a boot-time option on some platforms.
  bool os_use_large_pages;

  /// Large page size. This may be a boot-time option on some platforms
  ulint os_large_page_size;

  // ------------------------------------------------------------------------
  // OS file State
  // ------------------------------------------------------------------------
  ulint os_n_file_reads;
  ulint os_n_file_writes;
  ulint os_n_fsyncs;

  bool os_has_said_disk_full;

  /// Number of pending os_file_pread() operations
  std::atomic<ulint> os_file_n_pending_preads;

  /// Number of pending os_file_pwrite() operations
  std::atomic<ulint> os_file_n_pending_pwrites;

  /// Number of pending read operations
  std::atomic<ulint> os_n_pending_reads;

  /// Number of pending write operations
  std::atomic<ulint> os_n_pending_writes;

};

extern InnoDB_state state;

#endif //SRV0STATE_H
