
/** Copyright (c) 2024 Sunny Bains. All rights reserved. */

// TODO: COnvert to UNIT TEST

#include <gtest/gtest.h>

#include "innodb0types.h"
#include "lock0lock.h"
#include "srv0srv.h"
#include "trx0trx.h"

constexpr int N_TRXS = 8;
constexpr int N_ROW_LOCKS = 1;
constexpr int REC_BITMAP_SIZE = 104;


// TODO: FIX ME: it segvaults


class LockSysTest : public ::testing::Test {
    void SetUp() override {
        /* Startup minimal subsystems needed for lock system tests. */
        // ut_mem_init();
        // os_sync_init();

        // srv_config.m_max_n_threads = N_TRXS;

        // sync_init();

        // {
        //     srv_config.m_buf_pool_size = 64 * 1024 * 1024;
        //     srv_buf_pool = new (std::nothrow) Buf_pool();
        //     ASSERT_NE(srv_buf_pool, nullptr);
        //     auto success = srv_buf_pool->open(srv_config.m_buf_pool_size);
        //     ASSERT_TRUE(success);
        // }

        // srv_lock_timeout_thread_event = os_event_create(nullptr);
        // srv_trx_sys = Trx_sys::create(srv_fsp);
        // srv_lock_sys = Lock_sys::create(srv_trx_sys, 1024 * 1024);
        // UT_LIST_INIT(srv_trx_sys->m_client_trx_list);
    }

    void TearDown() override {
        /* Shutdown subsystems in reverse order. */
        // Lock_sys::destroy(srv_lock_sys);
        // Trx_sys::destroy(srv_trx_sys);
        // os_event_free(srv_lock_timeout_thread_event);
        // srv_lock_timeout_thread_event = nullptr;

        // srv_buf_pool->close();
        // sync_close();
        // os_sync_free();

        // delete srv_buf_pool;
        // ut_delete_all_mem();
    }

protected:
    // static Trx* create_user_trx() {
    //     return srv_trx_sys->create_user_trx(nullptr);
    // }

    // static void destroy_user_trx(Trx*& trx) {
    //     srv_trx_sys->destroy_user_trx(trx);
    //     ut_a(trx == nullptr);
    // }
};

TEST_F(LockSysTest, CreateRowLocksAndCheckWaiters) {
    /* Create N_TRXS transactions and create N_ROW_LOCKS row locks on
    random space/page_no/heap_no. Check basic waiter property. */



    // std::vector<Trx*> trxs;
    // trxs.resize(N_TRXS);

    // for (auto &trx : trxs) {
    //     trx = create_user_trx();
    //     ASSERT_NE(trx, nullptr);

    //     for (int i = 0; i < N_ROW_LOCKS; ++i) {
    //         auto mode = (i % 50 == 0) ? LOCK_X : LOCK_S;
    //         space_id_t space = random() % 100;
    //         page_no_t page_no = random() % 1000;
    //         auto heap_no = random() % REC_BITMAP_SIZE;

    //         ASSERT_EQ(trx->m_trx_sys, srv_lock_sys->m_trx_sys);

    //         mutex_enter(&srv_lock_sys->m_trx_sys->m_mutex);
    //         (void)srv_lock_sys->rec_create_low({space, page_no}, mode, heap_no,
    //                                            REC_BITMAP_SIZE, nullptr, trx);
    //         mutex_exit(&srv_lock_sys->m_trx_sys->m_mutex);
    //     }
    // }

    // size_t no_waiters{};

    // for (auto &trx : trxs) {
    //     if (srv_lock_sys->trx_has_no_waiters(trx)) {
    //         ++no_waiters;
    //     }
    // }

    // /* Basic sanity: we created some locks, count is within bounds. */
    // EXPECT_GE(no_waiters, 0u);
    // EXPECT_LE(no_waiters, trxs.size());

    // for (auto &trx : trxs) {
    //     mutex_enter(&srv_lock_sys->m_trx_sys->m_mutex);
    //     srv_lock_sys->release_off_trx_sys_mutex(trx);
    //     mutex_exit(&srv_lock_sys->m_trx_sys->m_mutex);
    //     destroy_user_trx(trx);
    // }
}
