/****************************************************************************
Copyright (c) 1997, 2010, Innobase Oy. All Rights Reserved.
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

/** @file row/row0umod.c
Undo modify of a row

Created 2/27/1997 Heikki Tuuri
*******************************************************/

#include "row0umod.h"

#include "btr0btr.h"
#include "dict0dict.h"
#include "dict0store.h"
#include "log0log.h"
#include "mach0data.h"
#include "que0que.h"
#include "row0row.h"
#include "row0undo.h"
#include "row0upd.h"
#include "row0vers.h"
#include "srv0state.h"
#include "trx0rec.h"
#include "trx0roll.h"
#include "trx0trx.h"
#include "trx0undo.h"

/* Considerations on undoing a modify operation.
(1) Undoing a delete marking: all index records should be found. Some of
them may have delete mark already false, if the delete mark operation was
stopped underway, or if the undo operation ended prematurely because of a
system crash.
(2) Undoing an update of a delete unmarked record: the newer version of
an updated secondary index entry should be removed if no prior version
of the clustered index record requires its existence. Otherwise, it should
be delete marked.
(3) Undoing an update of a delete marked record. In this kind of update a
delete marked clustered index record was delete unmarked and possibly also
some of its fields were changed. Now, it is possible that the delete marked
version has become obsolete at the time the undo is started. */

/** Checks if also the previous version of the clustered index record was
modified or inserted by the same transaction, and its undo number is such
that it should be undone in the same rollback.
@param[in,out] node             Row undo node.
@param[out] undo_no             The undo number.
@return	true if also previous modify or insert of this row should be undone */
inline bool row_undo_mod_undo_also_prev_vers(Undo_node *node, undo_no_t *undo_no) {
  trx_undo_rec_t *undo_rec;
  Trx *trx;

  trx = node->trx;

  if (node->new_trx_id != trx->m_id) {

    *undo_no = 0;
    return false;
  }

  undo_rec = trx_undo_get_undo_rec_low(node->new_roll_ptr, node->heap);

  *undo_no = trx_undo_rec_get_undo_no(undo_rec);

  return trx->m_roll_limit <= *undo_no;
}

/** Undoes a modify in a clustered index record.
@param[in,out] node             Row undo node.
@param[in,out] thr              Query thread.
@param[in,out] mtr              Must be committed before latching any further
pages.
@param[in] mode                 BTR_MODIFY_LEAF or BTR_MODIFY_TREE.
@return	DB_SUCCESS, DB_FAIL, or error code: we may run out of file space */
static db_err row_undo_mod_clust_low(Undo_node *node, que_thr_t *thr, mtr_t *mtr, ulint mode) {
  auto pcur = &node->m_pcur;
  auto btr_cur = pcur->get_btr_cur();
  auto success = pcur->restore_position(mode, mtr, Current_location());

  ut_a(success);

  db_err err;

  if (mode == BTR_MODIFY_LEAF) {

    err = btr_cur->optimistic_update(BTR_NO_LOCKING_FLAG | BTR_NO_UNDO_LOG_FLAG | BTR_KEEP_SYS_FLAG, node->update, node->cmpl_info, thr, mtr);
  } else {
    mem_heap_t *heap = nullptr;
    big_rec_t *dummy_big_rec;

    ut_ad(mode == BTR_MODIFY_TREE);

    err = btr_cur->pessimistic_update(
      BTR_NO_LOCKING_FLAG | BTR_NO_UNDO_LOG_FLAG | BTR_KEEP_SYS_FLAG,
      &heap,
      &dummy_big_rec,
      node->update,
      node->cmpl_info,
      thr,
      mtr
    );

    ut_a(!dummy_big_rec);
    if (likely_null(heap)) {
      mem_heap_free(heap);
    }
  }

  return err;
}

/** Removes a clustered index record after undo if possible.
This is attempted when the record was inserted by updating a
delete-marked record and there no longer exist transactions
that would see the delete-marked record.  In other words, we
roll back the insert by purging the record.
@param[in,out] node             Row undo node.
@param[in,out] thr              Query thread.
@param[in,out] mtr              Must be committed before latching any further
pages.
@param[in] mode                 BTR_MODIFY_LEAF or BTR_MODIFY_TREE.
@return	DB_SUCCESS, DB_FAIL, or error code: we may run out of file space */
static db_err row_undo_mod_remove_clust_low(Undo_node *node, que_thr_t *thr, mtr_t *mtr, ulint mode) {
  db_err err;

  ut_ad(node->rec_type == TRX_UNDO_UPD_DEL_REC);

  auto pcur = &node->m_pcur;
  auto btr_cur = pcur->get_btr_cur();
  auto success = pcur->restore_position(mode, mtr, Current_location());

  if (!success) {

    return DB_SUCCESS;
  }

  /* Find out if we can remove the whole clustered index record */

  if (node->rec_type == TRX_UNDO_UPD_DEL_REC && !row_vers_must_preserve_del_marked(node->new_trx_id, mtr)) {

    /* Ok, we can remove */
  } else {
    return DB_SUCCESS;
  }

  if (mode == BTR_MODIFY_LEAF) {
    success = btr_cur->optimistic_delete(mtr);

    if (success) {
      err = DB_SUCCESS;
    } else {
      err = DB_FAIL;
    }
  } else {
    ut_ad(mode == BTR_MODIFY_TREE);

    /* This operation is analogous to purge, we can free also
    inherited externally stored fields */

    btr_cur->pessimistic_delete(&err, false, thr_is_recv(thr) ? RB_RECOVERY_PURGE_REC : RB_NONE, mtr);

    /* The delete operation may fail if we have little
    file space left: TODO: easiest to crash the database
    and restart with more file space */
  }

  return err;
}

/** Undoes a modify in a clustered index record. Sets also the node state for
the next round of undo.
@param[in,out] node             Row undo node.
@param[in,out] thr              Query thread.
@return	DB_SUCCESS or error code: we may run out of file space */
static db_err row_undo_mod_clust(Undo_node *node, que_thr_t *thr) {
  mtr_t mtr;
  undo_no_t new_undo_no;

  ut_ad(node && thr);

  /* Check if also the previous version of the clustered index record
  should be undone in this same rollback operation */

  auto more_vers = row_undo_mod_undo_also_prev_vers(node, &new_undo_no);
  auto pcur = &node->m_pcur;

  mtr.start();

  /* Try optimistic processing of the record, keeping changes within
  the index page */

  auto err = row_undo_mod_clust_low(node, thr, &mtr, BTR_MODIFY_LEAF);

  if (err != DB_SUCCESS) {
    pcur->commit_specify_mtr(&mtr);

    /* We may have to modify tree structure: do a pessimistic
    descent down the index tree */

    mtr.start();

    err = row_undo_mod_clust_low(node, thr, &mtr, BTR_MODIFY_TREE);
  }

  pcur->commit_specify_mtr(&mtr);

  if (err == DB_SUCCESS && node->rec_type == TRX_UNDO_UPD_DEL_REC) {

    mtr.start();

    err = row_undo_mod_remove_clust_low(node, thr, &mtr, BTR_MODIFY_LEAF);
    if (err != DB_SUCCESS) {
      pcur->commit_specify_mtr(&mtr);

      /* We may have to modify tree structure: do a
      pessimistic descent down the index tree */

      mtr.start();

      err = row_undo_mod_remove_clust_low(node, thr, &mtr, BTR_MODIFY_TREE);
    }

    pcur->commit_specify_mtr(&mtr);
  }

  node->state = UNDO_NODE_FETCH_NEXT;

  trx_undo_rec_release(node->trx, node->undo_no);

  if (more_vers && err == DB_SUCCESS) {

    /* Reserve the undo log record to the prior version after
    committing &mtr: this is necessary to comply with the latching
    order, as &mtr may contain the fsp latch which is lower in
    the latch hierarchy than trx->undo_mutex. */

    auto success = trx_undo_rec_reserve(node->trx, new_undo_no);

    if (success) {
      node->state = UNDO_NODE_PREV_VERS;
    }
  }

  return err;
}

/** Delete marks or removes a secondary index entry if found.
@param[in,out] node             Row undo node
@param[in,out] thr              Query thread
@param[in,out] index            index
@param[in] entry                Index entry
@param[in] mode                 latch mode BTR_MODIFY_LEAF or BTR_MODIFY_TREE
@return	DB_SUCCESS, DB_FAIL, or DB_OUT_OF_FILE_SPACE */
static db_err row_undo_mod_del_mark_or_remove_sec_low(
  Undo_node *node, que_thr_t *thr, Index *index, DTuple *entry, ulint mode
) {
  db_err err;
  mtr_t mtr;
  bool old_has;
  bool success;
  mtr_t mtr_vers;
  Btree_pcursor pcur(srv_fsp, srv_btree_sys);

  state.log_sys->free_check();
  mtr.start();

  auto found = row_search_index_entry(index, entry, mode, &pcur, &mtr);

  auto btr_cur = pcur.get_btr_cur();

  if (!found) {
    /* In crash recovery, the secondary index record may
    be missing if the UPDATE did not have time to insert
    the secondary index records before the crash.  When we
    are undoing that UPDATE in crash recovery, the record
    may be missing.

    In normal processing, if an update ends in a deadlock
    before it has inserted all updated secondary index
    records, then the undo will not find those records. */

    pcur.close();
    mtr.commit();

    return DB_SUCCESS;
  }

  /* We should remove the index record if no prior version of the row,
  which cannot be purged yet, requires its existence. If some requires,
  we should delete mark the record. */

  mtr_vers.start();

  success = node->m_pcur.restore_position(BTR_SEARCH_LEAF, &mtr_vers, Current_location());
  ut_a(success);

  old_has = row_vers_old_has_index_entry(false, node->m_pcur.get_rec(), &mtr_vers, index, entry);

  if (old_has) {
    err = btr_cur->del_mark_set_sec_rec(BTR_NO_LOCKING_FLAG, true, thr, &mtr);
    ut_ad(err == DB_SUCCESS);
  } else {
    /* Remove the index record */

    if (mode == BTR_MODIFY_LEAF) {
      success = btr_cur->optimistic_delete(&mtr);
      if (success) {
        err = DB_SUCCESS;
      } else {
        err = DB_FAIL;
      }
    } else {
      ut_ad(mode == BTR_MODIFY_TREE);

      /* No need to distinguish RB_RECOVERY_PURGE here,
      because we are deleting a secondary index record:
      the distinction between RB_NORMAL and
      RB_RECOVERY_PURGE only matters when deleting a
      record that contains externally stored
      columns. */
      ut_ad(!index->is_clustered());
      btr_cur->pessimistic_delete(&err, false, RB_NORMAL, &mtr);

      /* The delete operation may fail if we have little
      file space left: TODO: easiest to crash the database
      and restart with more file space */
    }
  }

  node->m_pcur.commit_specify_mtr(&mtr_vers);
  pcur.close();
  mtr.commit();

  return err;
}

/** Delete marks or removes a secondary index entry if found.
NOTE that if we updated the fields of a delete-marked secondary index record
so that alphabetically they stayed the same, e.g., 'abc' -> 'aBc', we cannot
return to the original values because we do not know them. But this should
not cause problems because in row0sel.c, in queries we always retrieve the
clustered index record or an earlier version of it, if the secondary index
record through which we do the search is delete-marked.
@param[in,out] node             Row undo node
@param[in,out] thr              Query thread
@param[in,out] index            index
@param[in] entry                Index entry
@return	DB_SUCCESS or DB_OUT_OF_FILE_SPACE */
static db_err row_undo_mod_del_mark_or_remove_sec(Undo_node *node, que_thr_t *thr, Index *index, DTuple *entry) {
  auto err = row_undo_mod_del_mark_or_remove_sec_low(node, thr, index, entry, BTR_MODIFY_LEAF);

  if (err == DB_SUCCESS) {

    return err;
  } else {
    return row_undo_mod_del_mark_or_remove_sec_low(node, thr, index, entry, BTR_MODIFY_TREE);
  }
}

/**
 * Delete unmarks a secondary index entry which must be found. It might not be
 * delete-marked at the moment, but it does not harm to unmark it anyway. We also
 * need to update the fields of the secondary index record if we updated its
 *  fields but alphabetically they stayed the same, e.g., 'abc' -> 'aBc'.
 * 
 * @param[in] mode              Search mode: BTR_MODIFY_LEAF or BTR_MODIFY_TREE
 * @param[in,out] thr           Query thread
 * @param[in,out] index         Secondary index in which to unmark the entry
 * @param[in] entry             Index entry to unmark.
 * 
 * @return DB_FAIL or DB_SUCCESS or DB_OUT_OF_FILE_SPACE
 */
static db_err row_undo_mod_del_unmark_sec_and_undo_update(ulint mode, que_thr_t *thr, Index *index, const DTuple *entry) {
  mtr_t mtr;
  upd_t *update;
  Btree_pcursor pcur(srv_fsp, srv_btree_sys);
  mem_heap_t *heap;
  db_err err = DB_SUCCESS;
  big_rec_t *dummy_big_rec;
  Trx *trx = thr_get_trx(thr);

  /* Ignore indexes that are being created. */
  if (unlikely(*index->m_name == TEMP_INDEX_PREFIX)) {

    return DB_SUCCESS;
  }

  state.log_sys->free_check();
  mtr.start();

  if (unlikely(!row_search_index_entry(index, entry, mode, &pcur, &mtr))) {
    ib_logger(ib_stream, " error in sec index entry del undo in\n ");
    // index_name_print(ib_stream, trx, index);
    ib_logger(ib_stream, "\n tuple ");
    dtuple_print(ib_stream, entry);
    ib_logger(ib_stream, "\n record ");
    log_err(rec_to_string(pcur.get_rec()));
    log_info(trx->to_string(0));
    ib_logger(ib_stream, "\nSubmit a detailed bug report, check the TBD website for details");
  } else {
    auto btr_cur = pcur.get_btr_cur();

    err = btr_cur->del_mark_set_sec_rec(BTR_NO_LOCKING_FLAG, false, thr, &mtr);
    ut_a(err == DB_SUCCESS);
    heap = mem_heap_create(100);

    update = srv_row_upd->build_sec_rec_difference_binary(index, entry, btr_cur->get_rec(), trx, heap);

    if (Row_update::upd_get_n_fields(update) == 0) {

      /* Do nothing */

    } else if (mode == BTR_MODIFY_LEAF) {
      /* Try an optimistic updating of the record, keeping
      changes within the page */

      err = btr_cur->optimistic_update(BTR_KEEP_SYS_FLAG | BTR_NO_LOCKING_FLAG, update, 0, thr, &mtr);
      switch (err) {
        case DB_OVERFLOW:
        case DB_UNDERFLOW:
          err = DB_FAIL;
          break;

        default:
          break;
      }
    } else {
      ut_a(mode == BTR_MODIFY_TREE);
      err =
        btr_cur->pessimistic_update(BTR_KEEP_SYS_FLAG | BTR_NO_LOCKING_FLAG, &heap, &dummy_big_rec, update, 0, thr, &mtr);
      ut_a(!dummy_big_rec);
    }

    mem_heap_free(heap);
  }

  pcur.close();
  mtr.commit();

  return err;
}

/**
 * Undoes a modify in secondary indexes when undo record type is UPD_DEL.
 * 
 * @param[in,out] node             Row undo node
 * @param[in,out] thr              Query thread
 * 
 * @return DB_SUCCESS or DB_OUT_OF_FILE_SPACE
 */
static db_err row_undo_mod_upd_del_sec(Undo_node *node, que_thr_t *thr) {
  db_err err = DB_SUCCESS;

  ut_ad(node->rec_type == TRX_UNDO_UPD_DEL_REC);
  auto heap = mem_heap_create(1024);

  for (; node->index != nullptr; node->index = node->index->get_next()) {
    auto index = node->index;
    auto entry = row_build_index_entry(node->row, node->ext, index, heap);

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
      ut_a(thr_is_recv(thr));
    } else {
      err = row_undo_mod_del_mark_or_remove_sec(node, thr, index, entry);

      if (err != DB_SUCCESS) {

        break;
      }
    }

    mem_heap_empty(heap);
  }

  mem_heap_free(heap);

  return err;
}

/** Undoes a modify in secondary indexes when undo record type is DEL_MARK.
@param[in,out] node             Row undo node
@param[in,out] thr              Query thread
@return	DB_SUCCESS or DB_OUT_OF_FILE_SPACE */
static db_err row_undo_mod_del_mark_sec(Undo_node *node, que_thr_t *thr) {
  auto heap = mem_heap_create(1024);

  for (; node->index != nullptr; node->index = node->index->get_next()) {
    auto index = node->index;
    auto entry = row_build_index_entry(node->row, node->ext, index, heap);
    ut_a(entry != nullptr);

    auto err = row_undo_mod_del_unmark_sec_and_undo_update(BTR_MODIFY_LEAF, thr, index, entry);

    if (err == DB_FAIL) {
      err = row_undo_mod_del_unmark_sec_and_undo_update(BTR_MODIFY_TREE, thr, index, entry);
    }

    if (err != DB_SUCCESS) {

      mem_heap_free(heap);

      return err;
    }
  }

  mem_heap_free(heap);

  return DB_SUCCESS;
}

/**
 * Undoes a modify in secondary indexes when undo record type is UPD_EXIST.
 * 
 * @param[in,out] node             Row undo node
 * @param[in,out] thr              Query thread
 * 
 * @return DB_SUCCESS or DB_OUT_OF_FILE_SPACE
 */
static db_err row_undo_mod_upd_exist_sec(Undo_node *node, que_thr_t *thr) {
  if (node->cmpl_info & UPD_NODE_NO_ORD_CHANGE) {
    /* No change in secondary indexes */

    return DB_SUCCESS;
  }

  auto heap = mem_heap_create(1024);

  for (; node->index != nullptr; node->index = node->index->get_next()) {
    auto index = node->index;

    if (srv_row_upd->changes_ord_field_binary(node->row, node->index, node->update)) {

      /* Build the newest version of the index entry */
      auto entry = row_build_index_entry(node->row, node->ext, index, heap);
      ut_a(entry != nullptr);

      /* NOTE that if we updated the fields of a
      delete-marked secondary index record so that
      alphabetically they stayed the same, e.g.,
      'abc' -> 'aBc', we cannot return to the original
      values because we do not know them. But this should
      not cause problems because in row0sel.c, in queries
      we always retrieve the clustered index record or an
      earlier version of it, if the secondary index record
      through which we do the search is delete-marked. */

      auto err = row_undo_mod_del_mark_or_remove_sec(node, thr, index, entry);

      if (err != DB_SUCCESS) {
        mem_heap_free(heap);

        return err;
      }

      /* We may have to update the delete mark in the
      secondary index record of the previous version of
      the row. We also need to update the fields of
      the secondary index record if we updated its fields
      but alphabetically they stayed the same, e.g.,
      'abc' -> 'aBc'. */
      mem_heap_empty(heap);

      entry = row_build_index_entry(node->undo_row, node->undo_ext, index, heap);

      ut_a(entry != nullptr);

      err = row_undo_mod_del_unmark_sec_and_undo_update(BTR_MODIFY_LEAF, thr, index, entry);

      if (err == DB_FAIL) {
        err = row_undo_mod_del_unmark_sec_and_undo_update(BTR_MODIFY_TREE, thr, index, entry);
      }

      if (err != DB_SUCCESS) {
        mem_heap_free(heap);

        return err;
      }
    }
  }

  mem_heap_free(heap);

  return DB_SUCCESS;
}

/**
 * Parses the row reference and other info in a modify undo log record.
 * 
 * @param[in] recovery             Recovery flag.
 * @param[in,out] node             Row undo node.
 * @param[in,out] thr              Query thread.
 */
static void row_undo_mod_parse_undo_rec(ib_recovery_t recovery, Undo_node *node, que_thr_t *thr) {
  undo_no_t undo_no;
  uint64_t table_id;
  trx_id_t trx_id;
  roll_ptr_t roll_ptr;
  ulint info_bits;
  ulint type;
  ulint cmpl_info;
  bool dummy_extern;

  auto trx = thr_get_trx(thr);
  auto ptr = trx_undo_rec_get_pars(node->undo_rec, &type, &cmpl_info, &dummy_extern, &undo_no, &table_id);
  node->rec_type = type;

  node->table = srv_dict_sys->table_get_on_id(recovery, table_id, trx);

  /* TODO: other fixes associated with DROP TABLE + rollback in the
  same table by another user */

  if (node->table == nullptr) {
    /* Table was dropped */
    return;
  }

  if (node->table->m_ibd_file_missing) {
    /* We skip undo operations to missing .ibd files */
    node->table = nullptr;

    return;
  }

  auto clust_index = node->table->get_first_index();

  ptr = trx_undo_update_rec_get_sys_cols(ptr, &trx_id, &roll_ptr, &info_bits);

  ptr = trx_undo_rec_get_row_ref(ptr, clust_index, &(node->ref), node->heap);

  trx_undo_update_rec_get_update(ptr, clust_index, type, trx_id, roll_ptr, info_bits, trx, node->heap, &(node->update));
  node->new_roll_ptr = roll_ptr;
  node->new_trx_id = trx_id;
  node->cmpl_info = cmpl_info;
}

db_err row_undo_mod(Undo_node *node, que_thr_t *thr) {
  db_err err;

  ut_ad(node && thr);
  ut_ad(node->state == UNDO_NODE_MODIFY);

  // FIXME: Get rid of this global variable access
  row_undo_mod_parse_undo_rec(srv_config.m_force_recovery, node, thr);

  if (!node->table || !row_undo_search_clust_to_pcur(node)) {
    /* It is already undone, or will be undone by another query
    thread, or table was dropped */

    trx_undo_rec_release(node->trx, node->undo_no);
    node->state = UNDO_NODE_FETCH_NEXT;

    return DB_SUCCESS;
  }

  /* Get first secondary index */
  node->index = node->table->get_first_index()->get_next();

  if (node->rec_type == TRX_UNDO_UPD_EXIST_REC) {

    err = row_undo_mod_upd_exist_sec(node, thr);

  } else if (node->rec_type == TRX_UNDO_DEL_MARK_REC) {

    err = row_undo_mod_del_mark_sec(node, thr);
  } else {
    ut_ad(node->rec_type == TRX_UNDO_UPD_DEL_REC);
    err = row_undo_mod_upd_del_sec(node, thr);
  }

  if (err != DB_SUCCESS) {

    return err;
  }

  err = row_undo_mod_clust(node, thr);

  return err;
}
