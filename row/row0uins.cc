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

/** @file row/row0uins.c
Fresh insert undo

Created 2/25/1997 Heikki Tuuri
*******************************************************/

#include "btr0btr.h"
#include "dict0dict.h"
#include "dict0dict.h"
#include "log0log.h"
#include "mach0data.h"
#include "que0que.h"
#include "row0row.h"
#include "row0undo.h"
#include "row0uins.h"
#include "row0upd.h"
#include "row0vers.h"
#include "trx0rec.h"
#include "trx0roll.h"
#include "trx0trx.h"
#include "trx0undo.h"

/** Removes a clustered index record. The pcur in node was positioned on the
record, now it is detached.
@param[in,out] node             Undo node.
@return	DB_SUCCESS or DB_OUT_OF_FILE_SPACE */
static db_err row_undo_ins_remove_clust_rec(Undo_node *node) {
  Btree_cursor *btr_cur;
  db_err err;
  ulint n_tries{};
  mtr_t mtr;

  mtr.start();

  auto success = node->m_pcur.restore_position(BTR_MODIFY_LEAF, &mtr, Current_location());
  ut_a(success);

  if (node->table->m_id == DICT_INDEXES_ID) {
    ut_ad(node->trx->m_dict_operation_lock_mode == RW_X_LATCH);

    /* Drop the index tree associated with the row in
    SYS_INDEXES table: */

    srv_dict_sys->m_store.drop_index_tree(node->m_pcur.get_rec(), &mtr);

    mtr.commit();

    mtr.start();

    success = node->m_pcur.restore_position(BTR_MODIFY_LEAF, &mtr, Current_location());
    ut_a(success);
  }

  btr_cur = node->m_pcur.get_btr_cur();

  success = btr_cur->optimistic_delete(&mtr);

  node->m_pcur.commit_specify_mtr(&mtr);

  if (success) {
    trx_undo_rec_release(node->trx, node->undo_no);

    return DB_SUCCESS;
  }
retry:
  /* If did not succeed, try pessimistic descent to tree */
  mtr.start();

  success = node->m_pcur.restore_position(BTR_MODIFY_TREE, &mtr, Current_location());
  ut_a(success);

  btr_cur->pessimistic_delete(&err, false, trx_is_recv(node->trx) ? RB_RECOVERY : RB_NORMAL, &mtr);

  /* The delete operation may fail if we have little
  file space left: TODO: easiest to crash the database
  and restart with more file space */

  if (err == DB_OUT_OF_FILE_SPACE && n_tries < BTR_CUR_RETRY_DELETE_N_TIMES) {

    node->m_pcur.commit_specify_mtr(&mtr);

    ++n_tries;

    os_thread_sleep(BTR_CUR_RETRY_SLEEP_TIME);

    goto retry;
  }

  node->m_pcur.commit_specify_mtr(&mtr);

  trx_undo_rec_release(node->trx, node->undo_no);

  return err;
}

/**
 * Removes a secondary index entry if found.
 * 
 * @param[in,out] mode             BTR_MODIFY_LEAF or BTR_MODIFY_TREE,
 *                                depending on whether we wish optimistic or
 *                                pessimistic descent down the index tree
 * @param[in] index                Remove entry from this index
 * @param[in] entry                Index entry to remove
 * 
 * @return	DB_SUCCESS, DB_FAIL, or DB_OUT_OF_FILE_SPACE
 */
static db_err row_undo_ins_remove_sec_low(ulint mode, Index *index, DTuple *entry) {
  db_err err;
  Btree_pcursor pcur(srv_fsp, srv_btree_sys);

  log_sys->free_check();

  mtr_t mtr;

  mtr.start();

  auto found = row_search_index_entry(index, entry, mode, &pcur, &mtr);
  auto btr_cur = pcur.get_btr_cur();

  if (unlikely(!found)) {
    /* Not found */

    pcur.close();
    mtr.commit();

    return DB_SUCCESS;
  }

  if (mode == BTR_MODIFY_LEAF) {
    auto success = btr_cur->optimistic_delete(&mtr);
    err = success ? DB_SUCCESS : DB_FAIL;
  } else {
    ut_ad(mode == BTR_MODIFY_TREE);

    /* No need to distinguish RB_RECOVERY here, because we
    are deleting a secondary index record: the distinction
    between RB_NORMAL and RB_RECOVERY only matters when
    deleting a record that contains externally stored
    columns. */
    ut_ad(!index->is_clustered());
    btr_cur->pessimistic_delete(&err, false, RB_NORMAL, &mtr);
  }

  pcur.close();
  mtr.commit();

  return err;
}

/** Removes a secondary index entry from the index if found. Tries first
optimistic, then pessimistic descent down the tree.
@param[in,out] index            Remove entry from this secondary index.
@param[in] entry                Entry to remove.
@return	DB_SUCCESS or DB_OUT_OF_FILE_SPACE */
static db_err row_undo_ins_remove_sec(Index *index, DTuple *entry) {

  /* Try first optimistic descent to the B-tree */

  auto err = row_undo_ins_remove_sec_low(BTR_MODIFY_LEAF, index, entry);

  if (err == DB_SUCCESS) {

    return err;
  }

  ulint n_tries{};

  /* Try then pessimistic descent to the B-tree */
  for (;; ++n_tries) {
    err = row_undo_ins_remove_sec_low(BTR_MODIFY_TREE, index, entry);

    /* The delete operation may fail if we have little
    file space left: TODO: easiest to crash the database
    and restart with more file space */

    if (err == DB_SUCCESS || n_tries >= BTR_CUR_RETRY_DELETE_N_TIMES) {
      return err;
    }

    os_thread_sleep(BTR_CUR_RETRY_SLEEP_TIME);
  }
}

/** Parses the row reference and other info in a fresh insert undo record.
@param[in] recovery             Recovery flag
@param[in,out] node             Ros undo node. */
static void row_undo_ins_parse_undo_rec(ib_recovery_t recovery, Undo_node *node) {
  ulint type;
  ulint dummy;
  uint64_t table_id;
  undo_no_t undo_no;
  bool dummy_extern;

  auto ptr = trx_undo_rec_get_pars(node->undo_rec, &type, &dummy, &dummy_extern, &undo_no, &table_id);

  ut_ad(type == TRX_UNDO_INSERT_REC);
  node->rec_type = type;

  node->update = nullptr;
  node->table = srv_dict_sys->table_get_on_id(state.srv_config.m_force_recovery, table_id, node->trx);

  /* Skip the UNDO if we can't find the table or the .ibd file. */
  if (unlikely(node->table == nullptr)) {
  } else if (unlikely(node->table->m_ibd_file_missing)) {
    node->table = nullptr;
  } else {
    auto clust_index = node->table->get_first_index();

    if (clust_index != nullptr) {
      ptr = trx_undo_rec_get_row_ref(ptr, clust_index, &node->ref, node->heap);
    } else {
      ut_print_timestamp(ib_stream);
      ib_logger(ib_stream, "  table ");
      ut_print_name(node->table->m_name);
      ib_logger(
        ib_stream,
        " has no indexes, "
        "ignoring the table\n"
      );

      node->table = nullptr;
    }
  }
}

db_err row_undo_ins(Undo_node *node) {
  ut_ad(node->state == UNDO_NODE_INSERT);

  row_undo_ins_parse_undo_rec(state.srv_config.m_force_recovery, node);

  if (!node->table || !row_undo_search_clust_to_pcur(node)) {
    trx_undo_rec_release(node->trx, node->undo_no);

    return DB_SUCCESS;
  }

  /* Iterate over all the secondary indexes and undo the insert.*/

  for (auto index : node->table->m_indexes) {
    /* Skip the clustered index (the first index) */
    if (index->is_clustered()) {
      continue;
    }

    auto entry = row_build_index_entry(node->row, node->ext, node->index, node->heap);

    if (unlikely(entry == nullptr)) {
      /* The database must have crashed after
      inserting a clustered index record but before
      writing all the externally stored columns of
      that record.  Because secondary index entries
      are inserted after the clustered index record,
      we may assume that the secondary index record
      does not exist.  However, this situation may
      only occur during the rollback of incomplete
      transactions. */
      ut_a(trx_is_recv(node->trx));
    } else {
      auto err = row_undo_ins_remove_sec(node->index, entry);

      if (err != DB_SUCCESS) {

        return err;
      }
    }
  }

  return row_undo_ins_remove_clust_rec(node);
}
