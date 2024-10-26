/****************************************************************************
Copyright (c) 1997, 2009, Innobase Oy. All Rights Reserved.
Copyright (c) 2024 Sunny Bains. All rights reserved.

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

/** @file include/row0uins.h
Fresh insert undo

Created 2/25/1997 Heikki Tuuri
*******************************************************/

#pragma once

#include "innodb0types.h"

#include "data0data.h"
#include "dict0types.h"
#include "mtr0mtr.h"
#include "que0types.h"
#include "row0types.h"
#include "trx0types.h"

/** Undoes a fresh insert of a row to a table. A fresh insert means that
the same clustered index unique key did not have any record, even delete
marked, at the time of the insert.  InnoDB is eager in a rollback:
if it figures out that an index record will be removed in the purge
anyway, it will remove it in the rollback.
@param[in,out] node             Row undo node that will undo the fresh insert.
@return	DB_SUCCESS */
db_err row_undo_ins(Undo_node *node);
