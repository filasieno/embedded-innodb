/****************************************************************************
Copyright (c) 1994, 2010, Innobase Oy. All Rights Reserved.
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

/** @file page/page0page.c
Index page routines

Created 2/2/1994 Heikki Tuuri
*******************************************************/

#include "page0page.h"

#include <srv0state.h>

#include "btr0btr.h"

#include "buf0buf.h"
#include "fut0lst.h"
#include "lock0lock.h"
#include "page0cur.h"
#include "srv0srv.h"

/*			THE INDEX PAGE

The index page consists of a page header which contains the page's
id and other information. On top of it are the index records
in a heap linked into a one way linear list according to alphabetic order.

Just below page end is an array of pointers which we call page directory,
to about every sixth record in the list. The pointers are placed in
the directory in the alphabetical order of the records pointed to,
enabling us to make binary search using the array. Each slot n:o I
in the directory points to a record, where a 4-bit field contains a count
of those records which are in the linear list between pointer I and
the pointer I - 1 in the directory, including the record
pointed to by pointer I and not including the record pointed to by I - 1.
We say that the record pointed to by slot I, or that slot I, owns
these records. The count is always kept in the range 4 to 8, with
the exception that it is 1 for the first slot, and 1--8 for the second slot.

An essentially binary search can be performed in the list of index
records, like we could do if we had pointer to every record in the
page directory. The data structure is, however, more efficient when
we are doing inserts, because most inserts are just pushed on a heap.
Only every 8th insert requires block move in the directory pointer
table, which itself is quite small. A record is deleted from the page
by just taking it off the linear list and updating the number of owned
records-field of the record which owns it, and updating the page directory,
if necessary. A special case is the one when the record owns itself.
Because the overhead of inserts is so small, we may also increase the
page size from the projected default of 8 kB to 64 kB without too
much loss of efficiency in inserts. Bigger page becomes actual
when the disk transfer rate compared to seek and latency time rises.
On the present system, the page size is set so that the page transfer
time (3 ms) is 20 % of the disk random access time (15 ms).

When the page is split, merged, or becomes full but contains deleted
records, we have to reorganize the page.

Assuming a page size of 8 kB, a typical index page of a secondary
index contains 300 index entries, and the size of the page directory
is 50 x 4 bytes = 200 bytes. */

ulint page_dir_find_owner_slot(const rec_t *rec) {
  const page_t *page;
  uint16_t rec_offs_bytes;
  const page_dir_slot_t *slot;
  const page_dir_slot_t *first_slot;
  const rec_t *r = rec;

  ut_ad(page_rec_check(rec));

  page = page_align(rec);
  first_slot = page_dir_get_nth_slot(page, 0);
  slot = page_dir_get_nth_slot(page, page_dir_get_n_slots(page) - 1);

  while (rec_get_n_owned(r) == 0) {
    r = rec_get_next_ptr_const(r);
    ut_ad(r >= page + PAGE_SUPREMUM);
    ut_ad(r < page + (UNIV_PAGE_SIZE - PAGE_DIR));
  }

  rec_offs_bytes = mach_encode_2(r - page);

  while (likely(*(uint16_t *)slot != rec_offs_bytes)) {

    if (unlikely(slot == first_slot)) {
      log_err(std::format("Probable data corruption on page {}. Original record ", page_get_page_no(page)));
      log_err(rec_to_string(rec));

      log_err("on that page. Cannot find the dir slot for record on that page.");
      log_err(rec_to_string(page + mach_decode_2(rec_offs_bytes)));

      buf_page_print(page, 0);

      ut_error;
    }

    slot += PAGE_DIR_SLOT_SIZE;
  }

  return (((ulint)(first_slot - slot)) / PAGE_DIR_SLOT_SIZE);
}

/** Used to check the consistency of a directory slot.
@return	true if succeed */
static bool page_dir_slot_check(page_dir_slot_t *slot) /*!< in: slot */
{
  page_t *page;
  ulint n_slots;
  ulint n_owned;

  ut_a(slot);

  page = page_align(slot);

  n_slots = page_dir_get_n_slots(page);

  ut_a(slot <= page_dir_get_nth_slot(page, 0));
  ut_a(slot >= page_dir_get_nth_slot(page, n_slots - 1));

  ut_a(page_rec_check(page_dir_slot_get_rec(slot)));

  n_owned = rec_get_n_owned(page_dir_slot_get_rec(slot));

  if (slot == page_dir_get_nth_slot(page, 0)) {
    ut_a(n_owned == 1);
  } else if (slot == page_dir_get_nth_slot(page, n_slots - 1)) {
    ut_a(n_owned >= 1);
    ut_a(n_owned <= PAGE_DIR_SLOT_MAX_N_OWNED);
  } else {
    ut_a(n_owned >= PAGE_DIR_SLOT_MIN_N_OWNED);
    ut_a(n_owned <= PAGE_DIR_SLOT_MAX_N_OWNED);
  }

  return (true);
}

void page_set_max_trx_id(Buf_block *block, trx_id_t trx_id, mtr_t *mtr) {
  auto page = block->get_frame();

  ut_ad(!mtr || mtr->memo_contains(block, MTR_MEMO_PAGE_X_FIX));

  /* It is not necessary to write this change to the redo log, as
  during a database recovery we assume that the max trx id of every
  page is the maximum trx id assigned before the crash. */

  if (mtr != nullptr) {
    mlog_write_uint64(page + (PAGE_HEADER + PAGE_MAX_TRX_ID), trx_id, mtr);
  } else {
    mach_write_to_8(page + (PAGE_HEADER + PAGE_MAX_TRX_ID), trx_id);
  }
}

byte *page_mem_alloc_heap(page_t *page, ulint need, ulint *heap_no) {
  ut_ad(page && heap_no);

  auto avl_space = page_get_max_insert_size(page, 1);

  if (avl_space >= need) {
    auto block = page_header_get_ptr(page, PAGE_HEAP_TOP);

    page_header_set_ptr(page, PAGE_HEAP_TOP, block + need);

    *heap_no = page_dir_get_n_heap(page);

    page_dir_set_n_heap(page, 1 + *heap_no);

    return block;
  }

  return (nullptr);
}

/**
 * Creates a log record for the creation of a page.
 *
 * @param frame A buffer frame where the page is created.
 * @param mtr A mini-transaction handle.
 */
inline void page_create_write_log(buf_frame_t *frame, mtr_t *mtr) {
  mlog_write_initial_log_record(frame, MLOG_PAGE_CREATE, mtr);
}

byte *page_parse_create(byte *ptr, byte *, Buf_block *block, Index *index,mtr_t *mtr) {
  ut_ad(ptr != nullptr);

  /* The record is empty, except for the record initial part */

  if (block != nullptr) {
    page_create(index, block, mtr);
  }

  return ptr;
}

page_t *page_create(const Index *index, Buf_block *block, mtr_t *mtr) {
  ut_ad(block != nullptr);

  page_create_write_log(block->get_frame(), mtr);

  /* The infimum and supremum records use a dummy index. */
  // auto index = srv_dict_sys->m_dummy_index;

  /* 1. INCREMENT MODIFY CLOCK */
  buf_block_modify_clock_inc(block);

  auto page = block->get_frame();

  state.srv_fil->page_set_type(page, FIL_PAGE_TYPE_INDEX);

  auto heap = mem_heap_create(200);

  /* 3. CREATE THE INFIMUM AND SUPREMUM RECORDS */

  /* Create first a data tuple for infimum record */
  auto tuple = dtuple_create(heap, 1);
  dtuple_set_info_bits(tuple, REC_STATUS_INFIMUM);
  auto field = dtuple_get_nth_field(tuple, 0);

  dfield_set_data(field, "infimum", 8);
  dtype_set(dfield_get_type(field), DATA_VARCHAR, DATA_ENGLISH | DATA_NOT_NULL, 8);
  /* Set the corresponding physical record to its place in the page
  record heap */

  auto heap_top = page + PAGE_DATA;

  auto infimum_rec = rec_convert_dtuple_to_rec(heap_top, index, tuple, 0);

  ut_a(infimum_rec == page + PAGE_INFIMUM);

  rec_set_n_owned(infimum_rec, 1);
  rec_set_heap_no(infimum_rec, 0);

  ulint *offsets;

  {
    Phy_rec record{index, infimum_rec};

    offsets = record.get_col_offsets(nullptr, ULINT_UNDEFINED, &heap, Current_location());

    heap_top = rec_get_end(infimum_rec, offsets);
  }

  /* Create then a tuple for supremum */

  tuple = dtuple_create(heap, 1);
  dtuple_set_info_bits(tuple, REC_STATUS_SUPREMUM);
  field = dtuple_get_nth_field(tuple, 0);

  dfield_set_data(field, "supremum", 9);
  dtype_set(dfield_get_type(field), DATA_VARCHAR, DATA_ENGLISH | DATA_NOT_NULL, 9);

  auto supremum_rec = rec_convert_dtuple_to_rec(heap_top, index, tuple, 0);

  ut_a(supremum_rec == page + PAGE_SUPREMUM);

  rec_set_n_owned(supremum_rec, 1);
  rec_set_heap_no(supremum_rec, 1);

  {
    Phy_rec record{index, supremum_rec};

    offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());

    heap_top = rec_get_end(supremum_rec, offsets);
  }

  ut_ad(heap_top == page + PAGE_SUPREMUM_END);

  mem_heap_free(heap);
  heap = nullptr;

  /* 4. INITIALIZE THE PAGE */

  page_header_set_field(page, PAGE_N_DIR_SLOTS, 2);
  page_header_set_ptr(page, PAGE_HEAP_TOP, heap_top);
  page_header_set_field(page, PAGE_N_HEAP, PAGE_HEAP_NO_USER_LOW);
  page_header_set_ptr(page, PAGE_FREE, nullptr);
  page_header_set_field(page, PAGE_GARBAGE, 0);
  page_header_set_ptr(page, PAGE_LAST_INSERT, nullptr);
  page_header_set_field(page, PAGE_DIRECTION, PAGE_NO_DIRECTION);
  page_header_set_field(page, PAGE_N_DIRECTION, 0);
  page_header_set_field(page, PAGE_N_RECS, 0);
  page_set_max_trx_id(block, 0, nullptr);
  memset(heap_top, 0, UNIV_PAGE_SIZE - PAGE_EMPTY_DIR_START - page_offset(heap_top));

  /* 5. SET POINTERS IN RECORDS AND DIR SLOTS */

  /* Set the slots to point to infimum and supremum. */

  auto slot = page_dir_get_nth_slot(page, 0);

  page_dir_slot_set_rec(slot, infimum_rec);

  slot = page_dir_get_nth_slot(page, 1);
  page_dir_slot_set_rec(slot, supremum_rec);

  /* Set the next pointers in infimum and supremum */

  rec_set_next_offs(infimum_rec, PAGE_SUPREMUM);
  rec_set_next_offs(supremum_rec, 0);

  return page;
}

void page_copy_rec_list_end_no_locks(Buf_block *new_block, Buf_block *block, rec_t *rec, const Index *index, mtr_t *mtr) {
  page_t *new_page = new_block->get_frame();
  page_cur_t cur1;
  rec_t *cur2;
  mem_heap_t *heap = nullptr;
  ulint offsets_[REC_OFFS_NORMAL_SIZE];
  ulint *offsets = offsets_;
  rec_offs_init(offsets_);

  page_cur_position(rec, block, &cur1);

  if (page_cur_is_before_first(&cur1)) {

    page_cur_move_to_next(&cur1);
  }

  ut_a(mach_read_from_2(new_page + UNIV_PAGE_SIZE - 10) == PAGE_INFIMUM);

  cur2 = page_get_infimum_rec(new_block->get_frame());

  /* Copy records from the original page to the new page */

  while (!page_cur_is_after_last(&cur1)) {
    auto cur1_rec = page_cur_get_rec(&cur1);

    {
      Phy_rec record{index, cur1_rec};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
    }

    auto ins_rec = page_cur_insert_rec_low(cur2, index, cur1_rec, offsets, mtr);

    if (unlikely(ins_rec == nullptr)) {
      /* Track an assertion failure reported on the mailing
      list on June 18th, 2003 */

      buf_page_print(new_page, 0);
      buf_page_print(page_align(rec), 0);
      ut_print_timestamp(ib_stream);

      ib_logger(
        ib_stream,
        "rec offset %lu, cur1 offset %lu,"
        " cur2 offset %lu\n",
        (ulong)page_offset(rec),
        (ulong)page_offset(page_cur_get_rec(&cur1)),
        (ulong)page_offset(cur2)
      );
      ut_error;
    }

    page_cur_move_to_next(&cur1);
    cur2 = ins_rec;
  }

  if (likely_null(heap)) {
    mem_heap_free(heap);
  }
}

rec_t *page_copy_rec_list_end(Buf_block *new_block, Buf_block *block, rec_t *rec, const Index *index, mtr_t *mtr) {
  page_t *new_page = new_block->get_frame();
  page_t *page = page_align(rec);
  rec_t *ret = page_rec_get_next(page_get_infimum_rec(new_page));

  ut_ad(block->get_frame() == page);
  ut_ad(page_is_leaf(page) == page_is_leaf(new_page));

  /* Here, "ret" may be pointing to a user record or the
  predefined supremum record. */

  if (page_dir_get_n_heap(new_page) == PAGE_HEAP_NO_USER_LOW) {
    page_copy_rec_list_end_to_created_page(new_page, rec, index, mtr);
  } else {
    page_copy_rec_list_end_no_locks(new_block, block, rec, index, mtr);
  }

  if (!index->is_clustered() && page_is_leaf(page)) {
    page_update_max_trx_id(new_block, page_get_max_trx_id(page), mtr);
  }

  /* Update the lock table and possible hash index */

  srv_lock_sys->move_rec_list_end(new_block, block, rec);

  return ret;
}

rec_t *page_copy_rec_list_start(Buf_block *new_block, Buf_block *block, rec_t *rec, Index *index, mtr_t *mtr) {
  page_t *new_page = new_block->get_frame();
  page_cur_t cur1;
  rec_t *cur2;
  mem_heap_t *heap = nullptr;
  rec_t *ret = page_rec_get_prev(page_get_supremum_rec(new_page));
  ulint offsets_[REC_OFFS_NORMAL_SIZE];
  ulint *offsets = offsets_;
  rec_offs_init(offsets_);

  /* Here, "ret" may be pointing to a user record or the
  predefined infimum record. */

  if (page_rec_is_infimum(rec)) {

    return (ret);
  }

  page_cur_set_before_first(block, &cur1);
  page_cur_move_to_next(&cur1);

  cur2 = ret;

  /* Copy records from the original page to the new page */

  while (page_cur_get_rec(&cur1) != rec) {
    auto cur1_rec = page_cur_get_rec(&cur1);

    {
      Phy_rec record{index, cur1_rec};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
    }

    cur2 = page_cur_insert_rec_low(cur2, index, cur1_rec, offsets, mtr);
    ut_a(cur2);

    page_cur_move_to_next(&cur1);
  }

  if (likely_null(heap)) {
    mem_heap_free(heap);
  }

  if (!index->is_clustered() && page_is_leaf(page_align(rec))) {
    page_update_max_trx_id(new_block, page_get_max_trx_id(page_align(rec)), mtr);
  }

  /* Update the lock table and possible hash index */

  srv_lock_sys->move_rec_list_start(new_block, block, rec, ret);

  return ret;
}

/**
 * @brief Writes a log record of a record list end or start deletion.
 * 
 * @param[in] rec Record on page.
 * @param[in] index Record descriptor.
 * @param[in] type Operation type: MLOG_LIST_END_DELETE, MLOG_LIST_START_DELETE.
 * @param[in] mtr Mini-transaction handle.
 */
inline void page_delete_rec_list_write_log(rec_t *rec, Index *index, mlog_type_t type, mtr_t *mtr) {
  byte *log_ptr;
  ut_ad(type == MLOG_LIST_END_DELETE || type == MLOG_LIST_START_DELETE);

  log_ptr = mlog_open_and_write_index(mtr, rec, type, 2);
  if (log_ptr) {
    /* Write the parameter as a 2-byte ulint */
    mach_write_to_2(log_ptr, page_offset(rec));
    mlog_close(mtr, log_ptr + 2);
  }
}

byte *page_parse_delete_rec_list(byte type, byte *ptr, byte *end_ptr, Buf_block *block, Index *index, mtr_t *mtr) {
  ut_ad(type == MLOG_LIST_END_DELETE || type == MLOG_LIST_START_DELETE);

  /* Read the record offset as a 2-byte ulint */

  if (end_ptr < ptr + 2) {

    return nullptr;
  }

  auto offset = mach_read_from_2(ptr);

  ptr += 2;

  if (block == nullptr) {

    return ptr;
  }

  auto page = block->get_frame();

  if (type == MLOG_LIST_END_DELETE) {
    page_delete_rec_list_end(page + offset, block, index, ULINT_UNDEFINED, ULINT_UNDEFINED, mtr);
  } else {
    page_delete_rec_list_start(page + offset, block, index, mtr);
  }

  return ptr;
}

void page_delete_rec_list_end(rec_t *rec, Buf_block *block, Index *index, ulint n_recs, ulint size, mtr_t *mtr) {
  page_dir_slot_t *slot;
  ulint slot_index;
  rec_t *last_rec;
  rec_t *prev_rec;
  ulint n_owned;
  page_t *page = page_align(rec);
  mem_heap_t *heap = nullptr;
  ulint offsets_[REC_OFFS_NORMAL_SIZE];
  ulint *offsets = offsets_;
  rec_offs_init(offsets_);

  ut_ad(size == ULINT_UNDEFINED || size < UNIV_PAGE_SIZE);

  if (page_rec_is_infimum(rec)) {
    rec = page_rec_get_next(rec);
  }

  if (page_rec_is_supremum(rec)) {

    return;
  }

  /* Reset the last insert info in the page header and increment
  the modify clock for the frame */

  page_header_set_ptr(page, PAGE_LAST_INSERT, nullptr);

  /* The page gets invalid for optimistic searches: increment the
  frame modify clock */

  buf_block_modify_clock_inc(block);

  page_delete_rec_list_write_log(rec, index, MLOG_LIST_END_DELETE, mtr);

  prev_rec = page_rec_get_prev(rec);

  last_rec = page_rec_get_prev(page_get_supremum_rec(page));

  if ((size == ULINT_UNDEFINED) || (n_recs == ULINT_UNDEFINED)) {
    rec_t *rec2 = rec;
    /* Calculate the sum of sizes and the number of records */
    size = 0;
    n_recs = 0;

    do {
      {
        Phy_rec record{index, rec2};

        offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
      }

      auto s = rec_offs_size(offsets);

      ut_ad(rec2 - page + s - rec_offs_extra_size(offsets) < UNIV_PAGE_SIZE);
      ut_ad(size + s < UNIV_PAGE_SIZE);
      size += s;
      n_recs++;

      rec2 = page_rec_get_next(rec2);
    } while (!page_rec_is_supremum(rec2));

    if (unlikely(heap != nullptr)) {
      mem_heap_free(heap);
    }
  }

  ut_ad(size < UNIV_PAGE_SIZE);

  /* Update the page directory; there is no need to balance the number
  of the records owned by the supremum record, as it is allowed to be
  less than PAGE_DIR_SLOT_MIN_N_OWNED */

  rec_t *rec2 = rec;
  ulint count = 0;

  while (rec_get_n_owned(rec2) == 0) {
    count++;

    rec2 = rec_get_next_ptr(rec2);
  }

  ut_ad(rec_get_n_owned(rec2) > count);

  n_owned = rec_get_n_owned(rec2) - count;
  slot_index = page_dir_find_owner_slot(rec2);
  slot = page_dir_get_nth_slot(page, slot_index);

  page_dir_slot_set_rec(slot, page_get_supremum_rec(page));
  page_dir_slot_set_n_owned(slot, n_owned);

  page_dir_set_n_slots(page, slot_index + 1);

  /* Remove the record chain segment from the record chain */
  page_rec_set_next(prev_rec, page_get_supremum_rec(page));

  /* Catenate the deleted chain segment to the page free list */

  page_rec_set_next(last_rec, page_header_get_ptr(page, PAGE_FREE));
  page_header_set_ptr(page, PAGE_FREE, rec);

  page_header_set_field(page, PAGE_GARBAGE, size + page_header_get_field(page, PAGE_GARBAGE));

  page_header_set_field(page, PAGE_N_RECS, (ulint)(page_get_n_recs(page) - n_recs));
}

void page_delete_rec_list_start(rec_t *rec, Buf_block *block, Index *index, mtr_t *mtr) {
  page_cur_t cur1;
  ulint offsets_[REC_OFFS_NORMAL_SIZE];
  ulint *offsets = offsets_;
  mem_heap_t *heap = nullptr;

  rec_offs_init(offsets_);

  if (page_rec_is_infimum(rec)) {

    return;
  }

  page_delete_rec_list_write_log(rec, index, MLOG_LIST_START_DELETE, mtr);

  page_cur_set_before_first(block, &cur1);
  page_cur_move_to_next(&cur1);

  /* Individual deletes are not logged */

  auto log_mode = mtr->set_log_mode(MTR_LOG_NONE);

  while (page_cur_get_rec(&cur1) != rec) {
    {
      Phy_rec record{index, page_cur_get_rec(&cur1)};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
    }
    page_cur_delete_rec(&cur1, index, offsets, mtr);
  }

  if (unlikely(heap != nullptr)) {
    mem_heap_free(heap);
  }

  /* Restore log mode */

  auto old_mode = mtr->set_log_mode(log_mode);
  ut_a(old_mode == MTR_LOG_NONE);
}

bool page_move_rec_list_end(Buf_block *new_block, Buf_block *block, rec_t *split_rec, Index *index, mtr_t *mtr) {
  page_t *new_page = new_block->get_frame();
  ulint old_data_size;
  ulint new_data_size;
  ulint old_n_recs;
  ulint new_n_recs;

  old_data_size = page_get_data_size(new_page);
  old_n_recs = page_get_n_recs(new_page);

  if (unlikely(!page_copy_rec_list_end(new_block, block, split_rec, index, mtr))) {
    return false;
  }

  new_data_size = page_get_data_size(new_page);
  new_n_recs = page_get_n_recs(new_page);

  ut_ad(new_data_size >= old_data_size);

  page_delete_rec_list_end(split_rec, block, index, new_n_recs - old_n_recs, new_data_size - old_data_size, mtr);

  return (true);
}

bool page_move_rec_list_start(Buf_block *new_block, Buf_block *block, rec_t *split_rec, Index *index, mtr_t *mtr) {
  if (unlikely(!page_copy_rec_list_start(new_block, block, split_rec, index, mtr))) {
    return (false);
  }

  page_delete_rec_list_start(split_rec, block, index, mtr);

  return (true);
}

void page_rec_write_index_page_no(rec_t *rec, ulint i, ulint page_no, mtr_t *mtr) {
  byte *data;
  ulint len;

  data = rec_get_nth_field(rec, i, &len);

  ut_ad(len == 4);

  mlog_write_ulint(data, page_no, MLOG_4BYTES, mtr);
}

/**
 * @brief Deletes a slot from the directory and updates the n_owned fields in the records.
 * 
 * This function updates the n_owned fields in the records, so that the first slot after
 * the deleted ones inherits the records of the deleted slots.
 * 
 * @param[in,out] page The index page.
 * @param[in] slot_no The slot to be deleted.
 */
inline void page_dir_delete_slot(page_t *page, ulint slot_no) {
  page_dir_slot_t *slot;
  ulint n_owned;
  ulint n_slots;

  ut_ad(slot_no > 0);
  ut_ad(slot_no + 1 < page_dir_get_n_slots(page));

  n_slots = page_dir_get_n_slots(page);

  /* 1. Reset the n_owned fields of the slots to be
  deleted */
  slot = page_dir_get_nth_slot(page, slot_no);
  n_owned = page_dir_slot_get_n_owned(slot);
  page_dir_slot_set_n_owned(slot, 0);

  /* 2. Update the n_owned value of the first non-deleted slot */

  slot = page_dir_get_nth_slot(page, slot_no + 1);
  page_dir_slot_set_n_owned(slot, n_owned + page_dir_slot_get_n_owned(slot));

  /* 3. Destroy the slot by copying slots */
  for (ulint i = slot_no + 1; i < n_slots; i++) {
    rec_t *rec = (rec_t *)page_dir_slot_get_rec(page_dir_get_nth_slot(page, i));
    page_dir_slot_set_rec(page_dir_get_nth_slot(page, i - 1), rec);
  }

  /* 4. Zero out the last slot, which will be removed */
  mach_write_to_2(page_dir_get_nth_slot(page, n_slots - 1), 0);

  /* 5. Update the page header */
  page_header_set_field(page, PAGE_N_DIR_SLOTS, n_slots - 1);
}

/**
 * @brief Adds a slot to the directory.
 * 
 * This function adds a slot to the directory but does not set the record pointers
 * in the added slots or update n_owned values. This is the responsibility of the caller.
 * 
 * @param[in,out] page The index page.
 * @param[in] start The slot above which the new slots are added.
 */
inline void page_dir_add_slot(page_t *page, ulint start) {
  auto n_slots = page_dir_get_n_slots(page);

  ut_ad(start < n_slots - 1);

  /* Update the page header */
  page_dir_set_n_slots(page, n_slots + 1);

  /* Move slots up */
  auto slot = page_dir_get_nth_slot(page, n_slots);

  memmove(slot, slot + PAGE_DIR_SLOT_SIZE, (n_slots - 1 - start) * PAGE_DIR_SLOT_SIZE);
}

void page_dir_split_slot(page_t *page, ulint slot_no) {
  ut_ad(page);
  ut_ad(slot_no > 0);

  auto slot = page_dir_get_nth_slot(page, slot_no);
  auto n_owned = page_dir_slot_get_n_owned(slot);
  ut_ad(n_owned == PAGE_DIR_SLOT_MAX_N_OWNED + 1);

  /* 1. We loop to find a record approximately in the middle of the
  records owned by the slot. */

  auto prev_slot = page_dir_get_nth_slot(page, slot_no - 1);
  auto rec = (rec_t *)page_dir_slot_get_rec(prev_slot);

  for (ulint i = 0; i < n_owned / 2; i++) {
    rec = page_rec_get_next(rec);
  }

  ut_ad(n_owned / 2 >= PAGE_DIR_SLOT_MIN_N_OWNED);

  /* 2. We add one directory slot immediately below the slot to be
  split. */

  page_dir_add_slot(page, slot_no - 1);

  /* The added slot is now number slot_no, and the old slot is
  now number slot_no + 1 */

  auto new_slot = page_dir_get_nth_slot(page, slot_no);
  slot = page_dir_get_nth_slot(page, slot_no + 1);

  /* 3. We store the appropriate values to the new slot. */

  page_dir_slot_set_rec(new_slot, rec);
  page_dir_slot_set_n_owned(new_slot, n_owned / 2);

  /* 4. Finally, we update the number of records field of the
  original slot */

  page_dir_slot_set_n_owned(slot, n_owned - (n_owned / 2));
}

void page_dir_balance_slot(page_t *page, ulint slot_no) {
  ut_ad(slot_no > 0);

  auto slot = page_dir_get_nth_slot(page, slot_no);

  /* The last directory slot cannot be balanced with the upper
  neighbor, as there is none. */

  if (unlikely(slot_no == page_dir_get_n_slots(page) - 1)) {

    return;
  }

  auto up_slot = page_dir_get_nth_slot(page, slot_no + 1);
  auto n_owned = page_dir_slot_get_n_owned(slot);
  auto up_n_owned = page_dir_slot_get_n_owned(up_slot);

  ut_ad(n_owned == PAGE_DIR_SLOT_MIN_N_OWNED - 1);

  /* If the upper slot has the minimum value of n_owned, we will merge
  the two slots, therefore we assert: */
  ut_ad(2 * PAGE_DIR_SLOT_MIN_N_OWNED - 1 <= PAGE_DIR_SLOT_MAX_N_OWNED);

  if (up_n_owned > PAGE_DIR_SLOT_MIN_N_OWNED) {

    /* In this case we can just transfer one record owned
    by the upper slot to the property of the lower slot */
    auto old_rec = const_cast<rec_t *>(page_dir_slot_get_rec(slot));
    auto new_rec = rec_get_next_ptr(old_rec);

    rec_set_n_owned(old_rec, 0);
    rec_set_n_owned(new_rec, n_owned + 1);

    page_dir_slot_set_rec(slot, new_rec);

    page_dir_slot_set_n_owned(up_slot, up_n_owned - 1);
  } else {
    /* In this case we may merge the two slots */
    page_dir_delete_slot(page, slot_no);
  }
}

rec_t *page_get_middle_rec(page_t *page) {
  /* This many records we must leave behind */
  auto middle = (page_get_n_recs(page) + PAGE_HEAP_NO_USER_LOW) / 2;

  ulint i{};
  ulint count{};

  for (i = 0;; i++) {

    auto slot = page_dir_get_nth_slot(page, i);
    auto n_owned = page_dir_slot_get_n_owned(slot);

    if (count + n_owned > middle) {
      break;
    } else {
      count += n_owned;
    }
  }

  ut_ad(i > 0);

  auto slot = page_dir_get_nth_slot(page, i - 1);
  auto rec = reinterpret_cast<const rec_t *>(page_dir_slot_get_rec(slot));

  rec = page_rec_get_next(rec);

  /* There are now count records behind rec */

  for (ulint i = 0; i < middle - count; i++) {
    rec = page_rec_get_next(rec);
  }

  return const_cast<rec_t *>(rec);
}

ulint page_rec_get_n_recs_before(const rec_t *rec) {
  ut_ad(page_rec_check(rec));

  lint n{};

  while (rec_get_n_owned(rec) == 0) {

    rec = rec_get_next_ptr_const(rec);
    n--;
  }

  auto page = page_align(rec);

  for (uint i = 0;; i++) {
    auto slot = page_dir_get_nth_slot(page, i);
    auto slot_rec = page_dir_slot_get_rec(slot);

    n += rec_get_n_owned(slot_rec);

    if (rec == slot_rec) {

      break;
    }
  }

  --n;

  ut_ad(n >= 0);

  return ulint(n);
}

void page_rec_print(const rec_t *rec, const ulint *offsets) {
  log_info(std::format("n_owned: {}; heap_no: {}; next rec: {}", rec_get_n_owned(rec), rec_get_heap_no(rec), rec_get_next_offs(rec)));

  page_rec_check(rec);
  rec_validate(rec, offsets);
}

void page_dir_print(page_t *page, ulint pr_n) {
  auto n = page_dir_get_n_slots(page);

  ib_logger(
    ib_stream,
    "--------------------------------\n"
    "PAGE DIRECTORY\n"
    "Page address %p\n"
    "Directory stack top at offs: %lu; number of slots: %lu\n",
    page,
    (ulong)page_offset(page_dir_get_nth_slot(page, n - 1)),
    (ulong)n
  );

  for (ulint i = 0; i < n; i++) {
    auto slot = page_dir_get_nth_slot(page, i);

    if ((i == pr_n) && (i < n - pr_n)) {
      ib_logger(ib_stream, "    ...   \n");
    }
    if ((i < pr_n) || (i >= n - pr_n)) {
      ib_logger(
        ib_stream,
        "Contents of slot: %lu: n_owned: %lu,"
        " rec offs: %lu\n",
        (ulong)i,
        (ulong)page_dir_slot_get_n_owned(slot),
        (ulong)page_offset(page_dir_slot_get_rec(slot))
      );
    }
  }
  ib_logger(
    ib_stream,
    "Total of %lu records\n"
    "--------------------------------\n",
    (ulong)(PAGE_HEAP_NO_USER_LOW + page_get_n_recs(page))
  );
}

void page_print_list(Buf_block *block, Index *index, ulint pr_n) {
  page_t *page = block->m_frame;
  page_cur_t cur;
  ulint count;
  ulint n_recs;
  mem_heap_t *heap = nullptr;
  ulint offsets_[REC_OFFS_NORMAL_SIZE];
  ulint *offsets = offsets_;
  rec_offs_init(offsets_);

  ib_logger(
    ib_stream,
    "--------------------------------\n"
    "PAGE RECORD LIST\n"
    "Page address %p\n",
    page
  );

  n_recs = page_get_n_recs(page);

  page_cur_set_before_first(block, &cur);
  count = 0;
  for (;;) {

    {
      Phy_rec record{index, cur.m_rec};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
    }

    page_rec_print(cur.m_rec, offsets);

    if (count == pr_n) {
      break;
    }
    if (page_cur_is_after_last(&cur)) {
      break;
    }
    page_cur_move_to_next(&cur);
    count++;
  }

  if (n_recs > 2 * pr_n) {
    ib_logger(ib_stream, " ... \n");
  }

  while (!page_cur_is_after_last(&cur)) {
    page_cur_move_to_next(&cur);

    if (count + pr_n >= n_recs) {
      {
        Phy_rec record{index, cur.m_rec};

        offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
      }

      page_rec_print(cur.m_rec, offsets);
    }
    count++;
  }

  ib_logger(
    ib_stream,
    "Total of %lu records \n"
    "--------------------------------\n",
    (ulong)(count + 1)
  );

  if (likely_null(heap)) {
    mem_heap_free(heap);
  }
}

void page_header_print(const page_t *page) {
  ib_logger(
    ib_stream,
    "--------------------------------\n"
    "PAGE HEADER INFO\n"
    "Page address %p, n records %lu \n"
    "n dir slots %lu, heap top %lu\n"
    "Page n heap %lu, free %lu, garbage %lu\n"
    "Page last insert %lu, direction %lu, n direction %lu\n",
    page,
    (ulong)page_header_get_field(page, PAGE_N_RECS),
    (ulong)page_header_get_field(page, PAGE_N_DIR_SLOTS),
    (ulong)page_header_get_field(page, PAGE_HEAP_TOP),
    (ulong)page_dir_get_n_heap(page),
    (ulong)page_header_get_field(page, PAGE_FREE),
    (ulong)page_header_get_field(page, PAGE_GARBAGE),
    (ulong)page_header_get_field(page, PAGE_LAST_INSERT),
    (ulong)page_header_get_field(page, PAGE_DIRECTION),
    (ulong)page_header_get_field(page, PAGE_N_DIRECTION)
  );
}

void page_print(Buf_block *block, Index *index, ulint dn, ulint rn) {
  page_t *page = block->m_frame;

  page_header_print(page);
  page_dir_print(page, dn);
  page_print_list(block, index, rn);
}

bool page_rec_validate(rec_t *rec, const ulint *offsets) {
  ulint n_owned;
  ulint heap_no;
  page_t *page;

  page = page_align(rec);

  page_rec_check(rec);
  rec_validate(rec, offsets);

  n_owned = rec_get_n_owned(rec);
  heap_no = rec_get_heap_no(rec);

  if (unlikely(!(n_owned <= PAGE_DIR_SLOT_MAX_N_OWNED))) {
    ib_logger(ib_stream, "Dir slot of rec %lu, n owned too big %lu\n", (ulong)page_offset(rec), (ulong)n_owned);
    return (false);
  }

  if (unlikely(!(heap_no < page_dir_get_n_heap(page)))) {
    ib_logger(
      ib_stream, "Heap no of rec %lu too big %lu %lu\n", (ulong)page_offset(rec), (ulong)heap_no, (ulong)page_dir_get_n_heap(page)
    );
    return (false);
  }

  return (true);
}

void page_check_dir(const page_t *page) {
  ulint n_slots;
  ulint infimum_offs;
  ulint supremum_offs;

  n_slots = page_dir_get_n_slots(page);
  infimum_offs = mach_read_from_2(page_dir_get_nth_slot(page, 0));
  supremum_offs = mach_read_from_2(page_dir_get_nth_slot(page, n_slots - 1));

  if (unlikely(!page_rec_is_infimum_low(infimum_offs))) {

    ib_logger(
      ib_stream,
      "Page directory corruption:"
      " infimum not pointed to\n"
    );
    buf_page_print(page, 0);
  }

  if (unlikely(!page_rec_is_supremum_low(supremum_offs))) {

    ib_logger(
      ib_stream,
      "Page directory corruption:"
      " supremum not pointed to\n"
    );
    buf_page_print(page, 0);
  }
}

bool page_simple_validate(page_t *page) {
  page_dir_slot_t *slot;
  ulint slot_no;
  ulint n_slots;
  rec_t *rec;
  byte *rec_heap_top;
  ulint count;
  ulint own_count;
  bool ret = false;

  /* Check first that the record heap and the directory do not
  overlap. */

  n_slots = page_dir_get_n_slots(page);

  if (unlikely(n_slots > UNIV_PAGE_SIZE / 4)) {
    ib_logger(ib_stream, "Nonsensical number %lu of page dir slots\n", (ulong)n_slots);

    goto func_exit;
  }

  rec_heap_top = page_header_get_ptr(page, PAGE_HEAP_TOP);

  if (unlikely(rec_heap_top > page_dir_get_nth_slot(page, n_slots - 1))) {

    ib_logger(
      ib_stream,
      "Record heap and dir overlap on a page,"
      " heap top %lu, dir %lu\n",
      (ulong)page_header_get_field(page, PAGE_HEAP_TOP),
      (ulong)page_offset(page_dir_get_nth_slot(page, n_slots - 1))
    );

    goto func_exit;
  }

  /* Validate the record list in a loop checking also that it is
  consistent with the page record directory. */

  count = 0;
  own_count = 1;
  slot_no = 0;
  slot = page_dir_get_nth_slot(page, slot_no);

  rec = page_get_infimum_rec(page);

  for (;;) {
    if (unlikely(rec > rec_heap_top)) {
      ib_logger(
        ib_stream,
        "Record %lu is above"
        " rec heap top %lu\n",
        (ulong)(rec - page),
        (ulong)(rec_heap_top - page)
      );

      goto func_exit;
    }

    if (unlikely(rec_get_n_owned(rec))) {
      /* This is a record pointed to by a dir slot */
      if (unlikely(rec_get_n_owned(rec) != own_count)) {

        ib_logger(
          ib_stream,
          "Wrong owned count %lu, %lu,"
          " rec %lu\n",
          (ulong)rec_get_n_owned(rec),
          (ulong)own_count,
          (ulong)(rec - page)
        );

        goto func_exit;
      }

      if (unlikely(page_dir_slot_get_rec(slot) != rec)) {
        ib_logger(
          ib_stream,
          "Dir slot does not point"
          " to right rec %lu\n",
          (ulong)(rec - page)
        );

        goto func_exit;
      }

      own_count = 0;

      if (!page_rec_is_supremum(rec)) {
        slot_no++;
        slot = page_dir_get_nth_slot(page, slot_no);
      }
    }

    if (page_rec_is_supremum(rec)) {

      break;
    }

    if (unlikely(rec_get_next_offs(rec) < FIL_PAGE_DATA || rec_get_next_offs(rec) >= UNIV_PAGE_SIZE)) {
      log_err(std::format("Next record offset nonsensical {} for rec {}", rec_get_next_offs(rec), (rec - page)));

      goto func_exit;
    }

    count++;

    if (unlikely(count > UNIV_PAGE_SIZE)) {
      ib_logger(
        ib_stream,
        "Page record list appears"
        " to be circular %lu\n",
        (ulong)count
      );
      goto func_exit;
    }

    rec = page_rec_get_next(rec);
    own_count++;
  }

  if (unlikely(rec_get_n_owned(rec) == 0)) {
    ib_logger(ib_stream, "n owned is zero in a supremum rec\n");

    goto func_exit;
  }

  if (unlikely(slot_no != n_slots - 1)) {
    ib_logger(ib_stream, "n slots wrong %lu, %lu\n", (ulong)slot_no, (ulong)(n_slots - 1));
    goto func_exit;
  }

  if (unlikely(page_header_get_field(page, PAGE_N_RECS) + PAGE_HEAP_NO_USER_LOW != count + 1)) {
    ib_logger(
      ib_stream,
      "n recs wrong %lu %lu\n",
      (ulong)page_header_get_field(page, PAGE_N_RECS) + PAGE_HEAP_NO_USER_LOW,
      (ulong)(count + 1)
    );

    goto func_exit;
  }

  /* Check then the free list */
  rec = page_header_get_ptr(page, PAGE_FREE);

  while (rec != nullptr) {
    if (unlikely(rec < page + FIL_PAGE_DATA || rec >= page + UNIV_PAGE_SIZE)) {
      ib_logger(
        ib_stream,
        "Free list record has"
        " a nonsensical offset %lu\n",
        (ulong)(rec - page)
      );

      goto func_exit;
    }

    if (unlikely(rec > rec_heap_top)) {
      ib_logger(
        ib_stream,
        "Free list record %lu"
        " is above rec heap top %lu\n",
        (ulong)(rec - page),
        (ulong)(rec_heap_top - page)
      );

      goto func_exit;
    }

    count++;

    if (unlikely(count > UNIV_PAGE_SIZE)) {
      ib_logger(
        ib_stream,
        "Page free list appears"
        " to be circular %lu\n",
        (ulong)count
      );
      goto func_exit;
    }

    rec = page_rec_get_next(rec);
  }

  if (unlikely(page_dir_get_n_heap(page) != count + 1)) {

    ib_logger(ib_stream, "N heap is wrong %lu, %lu\n", (ulong)page_dir_get_n_heap(page), (ulong)(count + 1));

    goto func_exit;
  }

  ret = true;

func_exit:
  return (ret);
}

bool page_validate(page_t *page, Index *index) {
  page_dir_slot_t *slot;
  mem_heap_t *heap;
  byte *buf;
  ulint count;
  ulint own_count;
  ulint rec_own_count;
  ulint slot_no;
  ulint data_size;
  rec_t *rec;
  rec_t *old_rec = nullptr;
  ulint offs;
  ulint n_slots;
  bool ret = false;
  ulint i;
  ulint *offsets = nullptr;
  ulint *old_offsets = nullptr;

  if (unlikely(!page_simple_validate(page))) {
    goto func_exit2;
  }

  heap = mem_heap_create(UNIV_PAGE_SIZE + 200);

  /* The following buffer is used to check that the
  records in the page record heap do not overlap */

  buf = mem_heap_zalloc(heap, UNIV_PAGE_SIZE);

  /* Check first that the record heap and the directory do not
  overlap. */

  n_slots = page_dir_get_n_slots(page);

  if (unlikely(!(page_header_get_ptr(page, PAGE_HEAP_TOP) <= page_dir_get_nth_slot(page, n_slots - 1)))) {

    ib_logger(
      ib_stream,
      "Record heap and dir overlap"
      " on space %lu page %lu index %s, %p, %p\n",
      (ulong)page_get_space_id(page),
      (ulong)page_get_page_no(page),
      index->m_name,
      page_header_get_ptr(page, PAGE_HEAP_TOP),
      page_dir_get_nth_slot(page, n_slots - 1)
    );

    goto func_exit;
  }

  /* Validate the record list in a loop checking also that
  it is consistent with the directory. */
  count = 0;
  data_size = 0;
  own_count = 1;
  slot_no = 0;
  slot = page_dir_get_nth_slot(page, slot_no);

  rec = page_get_infimum_rec(page);

  for (;;) {
    {
      Phy_rec record{index, rec};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location());
    }

    if (unlikely(!page_rec_validate(rec, offsets))) {
      goto func_exit;
    }

    /* Check that the records are in the ascending order */
    if (likely(count >= PAGE_HEAP_NO_USER_LOW) && !page_rec_is_supremum(rec)) {
      if (unlikely(cmp_rec_rec(rec, old_rec, offsets, old_offsets, index)) != 1) {

        log_warn(std::format(
          "Records in wrong orderon space {} page {} index {}\n",
          page_get_space_id(page),
          page_get_page_no(page),
          index->m_name
        ));

        log_err("previous record ");
        log_err(rec_to_string(old_rec));
        log_err("record ");
        log_err(rec_to_string(rec));

        goto func_exit;
      }
    }

    if (page_rec_is_user_rec(rec)) {

      data_size += rec_offs_size(offsets);
    }

    offs = page_offset(rec_get_start(rec, offsets));
    i = rec_offs_size(offsets);
    if (unlikely(offs + i >= UNIV_PAGE_SIZE)) {
      log_err("record offset out of bounds\n");
      goto func_exit;
    }

    while (i--) {
      if (unlikely(buf[offs + i])) {
        /* No other record may overlap this */

        log_err("Record overlaps another\n");
        goto func_exit;
      }

      buf[offs + i] = 1;
    }

    rec_own_count = rec_get_n_owned(rec);

    if (unlikely(rec_own_count)) {
      /* This is a record pointed to by a dir slot */
      if (unlikely(rec_own_count != own_count)) {
        ib_logger(ib_stream, "Wrong owned count %lu, %lu\n", (ulong)rec_own_count, (ulong)own_count);
        goto func_exit;
      }

      if (page_dir_slot_get_rec(slot) != rec) {
        ib_logger(
          ib_stream,
          "Dir slot does not"
          " point to right rec\n"
        );
        goto func_exit;
      }

      page_dir_slot_check(slot);

      own_count = 0;
      if (!page_rec_is_supremum(rec)) {
        slot_no++;
        slot = page_dir_get_nth_slot(page, slot_no);
      }
    }

    if (page_rec_is_supremum(rec)) {
      break;
    }

    count++;
    own_count++;
    old_rec = rec;
    rec = page_rec_get_next(rec);

    /* set old_offsets to offsets; recycle offsets */
    {
      ulint *offs = old_offsets;
      old_offsets = offsets;
      offsets = offs;
    }
  }

  if (unlikely(rec_get_n_owned(rec) == 0)) {
    ib_logger(ib_stream, "n owned is zero\n");
    goto func_exit;
  }

  if (unlikely(slot_no != n_slots - 1)) {
    ib_logger(ib_stream, "n slots wrong %lu %lu\n", (ulong)slot_no, (ulong)(n_slots - 1));
    goto func_exit;
  }

  if (unlikely(page_header_get_field(page, PAGE_N_RECS) + PAGE_HEAP_NO_USER_LOW != count + 1)) {
    ib_logger(
      ib_stream,
      "n recs wrong %lu %lu\n",
      (ulong)page_header_get_field(page, PAGE_N_RECS) + PAGE_HEAP_NO_USER_LOW,
      (ulong)(count + 1)
    );
    goto func_exit;
  }

  if (unlikely(data_size != page_get_data_size(page))) {
    ib_logger(ib_stream, "Summed data size %lu, returned by func %lu\n", (ulong)data_size, (ulong)page_get_data_size(page));
    goto func_exit;
  }

  /* Check then the free list */
  rec = page_header_get_ptr(page, PAGE_FREE);

  while (rec != nullptr) {
    {
      Phy_rec record{index, rec};

      offsets = record.get_col_offsets(offsets, ULINT_UNDEFINED, &heap, Current_location()); 
    }

    if (unlikely(!page_rec_validate(rec, offsets))) {

      goto func_exit;
    }

    count++;
    offs = page_offset(rec_get_start(rec, offsets));
    i = rec_offs_size(offsets);
    if (unlikely(offs + i >= UNIV_PAGE_SIZE)) {
      ib_logger(ib_stream, "record offset out of bounds\n");
      goto func_exit;
    }

    while (i--) {

      if (unlikely(buf[offs + i])) {
        ib_logger(
          ib_stream,
          "Record overlaps another"
          " in free list\n"
        );
        goto func_exit;
      }

      buf[offs + i] = 1;
    }

    rec = page_rec_get_next(rec);
  }

  if (unlikely(page_dir_get_n_heap(page) != count + 1)) {
    ib_logger(ib_stream, "N heap is wrong %lu %lu\n", (ulong)page_dir_get_n_heap(page), (ulong)count + 1);
    goto func_exit;
  }

  ret = true;

func_exit:
  mem_heap_free(heap);

  if (unlikely(ret == false)) {
  func_exit2:
    ib_logger(
      ib_stream,
      "Apparent corruption"
      " in space %lu page %lu index %s\n",
      (ulong)page_get_space_id(page),
      (ulong)page_get_page_no(page),
      index->m_name
    );
    buf_page_print(page, 0);
  }

  return ret;
}

const rec_t *page_find_rec_with_heap_no(const page_t *page, ulint heap_no) {
  auto rec = page + PAGE_INFIMUM;

  for (;;) {
    ulint rec_heap_no = rec_get_heap_no(rec);

    if (rec_heap_no == heap_no) {

      return rec;
    } else if (rec_heap_no == PAGE_HEAP_NO_SUPREMUM) {

      return nullptr;
    }

    rec = page + rec_get_next_offs(rec);
  }
}
