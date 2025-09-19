#include <cstdio>
#include <cstring>

// GAP analysis: missing API coverage
// Read/write/insert/search (DML + read helpers)
//     ib_cursor_read_row
//     ib_cursor_insert_row,
//     ib_cursor_update_row,
//     ib_cursor_delete_row
//     ib_cursor_moveto (search)
//     ib_cursor_set_simple_select
//     Typed tuple IO: ib_tuple_read_{i8,u8,i16,u16,i32,u32,i64,u64,double,float}
//     Typed tuple IO: ib_tuple_write_{i8,u8,i16,u16,i32,u32,i64,u64,double,float}
//     Tuple struct ops:
//        ib_tuple_clear
//        ib_tuple_copy
//        ib_tuple_get_cluster_key
//        ib_tuple_get_n_user_cols
//        ib_tuple_get_n_cols
//        ib_tuple_delete
//     Additional tuple creators:
//        ib_sec_read_tuple_create
//        ib_clust_search_tuple_create
//        ib_clust_read_tuple_create
// Cursor open/reset/position
//    ib_cursor_open_table_using_id
//    ib_cursor_open_index_using_id
//    ib_cursor_open_index_using_name
//    ib_cursor_reset
//    ib_cursor_is_positioned
// Schema/DDL (remaining)
//    ib_table_rename
//    ib_table_truncate
//    ib_cursor_truncate
//    ib_index_create
//    ib_index_drop
// Lookups/IDs
//    ib_table_get_id
//    ib_index_get_id
// Schema locks
//    ib_schema_lock_shared,
//    ib_schema_lock_exclusive
//    ib_schema_lock_is_shared,
//    ib_schema_lock_is_exclusive
//    ib_schema_unlock
// Database ops
//    ib_database_create
//    ib_database_drop
// Config/status/logging
//    ib_cfg_var_get_type,
//    ib_cfg_set
//    ib_cfg_get
//    ib_cfg_get_all
//    ib_status_get_i64
//    ib_status_get_all
//    ib_logger_set
//    ib_set_panic_handler
//    ib_set_trx_is_interrupted_handler
// Stats/maintenance/testing
//    ib_get_duplicate_key
//    ib_get_table_statistics
//    ib_get_index_stat_n_diff_key_vals
//    ib_update_table_statistics
//    ib_error_inject
//    ib_parallel_select_count_star
//    ib_check_table
// Savepoints
//    ib_savepoint_take
//    ib_savepoint_release
//    ib_savepoint_rollback
// Constants not yet exported to Lua
//    ib_lck_mode_t
//    ib_srch_mode_t
//    ib_match_mode_t
//    ib_col_type_t
//    ib_col_attr_t
//    ib_tbl_fmt_t
//    ib_trx_level_t
//    ib_trx_state_t
//    db_err codes
//    cfg types (ib_cfg_type_t)
//

#ifdef __has_include
#if __has_include(<lua.hpp>)
#include <lua.hpp>
#elif __has_include(<lua5.4/lua.hpp>)
#include <lua5.4/lua.hpp>
#elif __has_include(<luajit-2.1/lua.hpp>)
#include <luajit-2.1/lua.hpp>
#else
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#endif
#else
#include <lua.hpp>
#endif

#include "innodb.h"

static int lua_ib_version(lua_State *L) {
  const uint64_t v = ib_api_version();
  char buf[32];
  std::snprintf(buf, sizeof(buf), "%llu", (unsigned long long)v);
  lua_pushstring(L, buf);
  return 1;
}

static int lua_ib_init(lua_State *L) {
  (void)L;
  const ib_err_t rc = ib_init();
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_startup(lua_State *L) {
  const char *format = luaL_optstring(L, 1, "Barracuda");
  const ib_err_t rc = ib_startup(format);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_shutdown(lua_State *L) {
  int flag = (int)luaL_optinteger(L, 1, (int)IB_SHUTDOWN_NORMAL);
  const ib_err_t rc = ib_shutdown(static_cast<ib_shutdown_t>(flag));
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static void push_constants(lua_State *L) {
  lua_createtable(L, 0, 8);
  lua_pushinteger(L, IB_SHUTDOWN_NORMAL);
  lua_setfield(L, -2, "SHUTDOWN_NORMAL");
  lua_pushinteger(L, IB_SHUTDOWN_NO_IBUFMERGE_PURGE);
  lua_setfield(L, -2, "SHUTDOWN_NO_IBUFMERGE_PURGE");
  lua_pushinteger(L, IB_SHUTDOWN_NO_BUFPOOL_FLUSH);
  lua_setfield(L, -2, "SHUTDOWN_NO_BUFPOOL_FLUSH");
  lua_setfield(L, -2, "shutdown");  // module.shutdown = { ...constants... }
}

extern "C" int luaopen_innodb(lua_State *L) {
  luaL_Reg funcs[] = {

    {nullptr, nullptr}
  };

  lua_createtable(L, 0, (int)(sizeof(funcs) / sizeof(funcs[0])));
  for (const luaL_Reg *r = funcs; r->name != nullptr; ++r) {
    lua_pushcfunction(L, r->func);
    lua_setfield(L, -2, r->name);
  }

  push_constants(L);
  return 1;
}

// ---- Extended bindings below ----

static ib_trx_t to_trx(lua_State *L, int idx) {
  return reinterpret_cast<ib_trx_t>(lua_touserdata(L, idx));
}

static ib_crsr_t to_crsr(lua_State *L, int idx) {
  return reinterpret_cast<ib_crsr_t>(lua_touserdata(L, idx));
}

static ib_tpl_t to_tpl(lua_State *L, int idx) {
  return reinterpret_cast<ib_tpl_t>(lua_touserdata(L, idx));
}

static ib_tbl_sch_t to_tbl_sch(lua_State *L, int idx) {
  return reinterpret_cast<ib_tbl_sch_t>(lua_touserdata(L, idx));
}

static ib_idx_sch_t to_idx_sch(lua_State *L, int idx) {
  return reinterpret_cast<ib_idx_sch_t>(lua_touserdata(L, idx));
}

// trx
static int lua_ib_trx_begin(lua_State *L) {
  int lvl = (int)luaL_optinteger(L, 1, (int)IB_TRX_READ_COMMITTED);
  ib_trx_t trx = ib_trx_begin(static_cast<ib_trx_level_t>(lvl));
  if (!trx) {
    lua_pushnil(L);
    lua_pushstring(L, "ib_trx_begin failed");
    return 2;
  }
  lua_pushlightuserdata(L, trx);
  return 1;
}

static int lua_ib_trx_commit(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  ib_err_t rc = ib_trx_commit(trx);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_trx_rollback(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  ib_err_t rc = ib_trx_rollback(trx);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_trx_release(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  ib_err_t rc = ib_trx_release(trx);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_trx_state(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  int st = (int)ib_trx_state(trx);
  lua_pushinteger(L, st);
  return 1;
}

static int lua_ib_trx_start(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  int lvl = (int)luaL_checkinteger(L, 2);
  ib_err_t rc = ib_trx_start(trx, static_cast<ib_trx_level_t>(lvl));
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

// cursors
static int lua_ib_cursor_open_table(lua_State *L) {
  const char *name = luaL_checkstring(L, 1);
  ib_trx_t trx = lua_islightuserdata(L, 2) ? to_trx(L, 2) : nullptr;
  ib_crsr_t crsr{};
  ib_err_t rc = ib_cursor_open_table(name, trx, &crsr);
  if (rc == DB_SUCCESS) {
    lua_pushlightuserdata(L, crsr);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_close(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_err_t rc = ib_cursor_close(crsr);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_next(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_err_t rc = ib_cursor_next(crsr);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_prev(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_err_t rc = ib_cursor_prev(crsr);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_first(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_err_t rc = ib_cursor_first(crsr);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_last(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_err_t rc = ib_cursor_last(crsr);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_cursor_attach_trx(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_trx_t trx = to_trx(L, 2);
  ib_cursor_attach_trx(crsr, trx);
  lua_pushboolean(L, 1);
  return 1;
}

static int lua_ib_cursor_set_match_mode(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  int mode = (int)luaL_checkinteger(L, 2);
  ib_cursor_set_match_mode(crsr, static_cast<ib_match_mode_t>(mode));
  lua_pushboolean(L, 1);
  return 1;
}

static int lua_ib_cursor_lock(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  int mode = (int)luaL_checkinteger(L, 2);
  ib_err_t rc = ib_cursor_lock(crsr, static_cast<ib_lck_mode_t>(mode));
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

// tuples
static int lua_ib_sec_search_tuple_create(lua_State *L) {
  ib_crsr_t crsr = to_crsr(L, 1);
  ib_tpl_t tpl = ib_sec_search_tuple_create(crsr);
  if (!tpl) {
    lua_pushnil(L);
    lua_pushstring(L, "sec_search_tuple_create failed");
    return 2;
  }
  lua_pushlightuserdata(L, tpl);
  return 1;
}

static int lua_ib_col_set_value(lua_State *L) {
  ib_tpl_t tpl = to_tpl(L, 1);
  int col = (int)luaL_checkinteger(L, 2);
  size_t len{};
  const char *data = luaL_checklstring(L, 3, &len);
  ib_err_t rc = ib_col_set_value(tpl, (ulint)col, data, (ulint)len);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_col_get_len(lua_State *L) {
  ib_tpl_t tpl = to_tpl(L, 1);
  int col = (int)luaL_checkinteger(L, 2);
  lua_pushinteger(L, (lua_Integer)ib_col_get_len(tpl, (ulint)col));
  return 1;
}

static int lua_ib_col_copy_value(lua_State *L) {
  ib_tpl_t tpl = to_tpl(L, 1);
  int col = (int)luaL_checkinteger(L, 2);
  ulint len = ib_col_get_len(tpl, (ulint)col);
  if (len == IB_SQL_NULL) {
    lua_pushnil(L);
    return 1;
  }
  std::string buf;
  buf.resize((size_t)len);
  ulint n = ib_col_copy_value(tpl, (ulint)col, buf.data(), (ulint)buf.size());
  lua_pushlstring(L, buf.data(), (size_t)n);
  return 1;
}

// DDL schema helpers
static int lua_ib_table_schema_create(lua_State *L) {
  const char *name = luaL_checkstring(L, 1);
  int fmt = (int)luaL_optinteger(L, 2, (int)IB_TBL_V1);
  lua_Integer page_size = luaL_optinteger(L, 3, 0);
  ib_tbl_sch_t sch{};
  ib_err_t rc = ib_table_schema_create(name, &sch, static_cast<ib_tbl_fmt_t>(fmt), (ulint)page_size);
  if (rc == DB_SUCCESS) {
    lua_pushlightuserdata(L, sch);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_table_schema_add_col(lua_State *L) {
  ib_tbl_sch_t sch = to_tbl_sch(L, 1);
  const char *name = luaL_checkstring(L, 2);
  int col_type = (int)luaL_checkinteger(L, 3);
  int col_attr = (int)luaL_optinteger(L, 4, (int)IB_COL_NONE);
  int client_type = (int)luaL_optinteger(L, 5, 0);
  lua_Integer len = luaL_optinteger(L, 6, 0);
  ib_err_t rc = ib_table_schema_add_col(
    sch, name, static_cast<ib_col_type_t>(col_type), static_cast<ib_col_attr_t>(col_attr), (uint16_t)client_type, (ulint)len
  );
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_index_schema_create(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  const char *name = luaL_checkstring(L, 2);
  const char *table_name = luaL_checkstring(L, 3);
  ib_idx_sch_t idx{};
  ib_err_t rc = ib_index_schema_create(trx, name, table_name, &idx);
  if (rc == DB_SUCCESS) {
    lua_pushlightuserdata(L, idx);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_index_schema_add_col(lua_State *L) {
  ib_idx_sch_t idx = to_idx_sch(L, 1);
  const char *name = luaL_checkstring(L, 2);
  lua_Integer prefix_len = luaL_optinteger(L, 3, 0);
  ib_err_t rc = ib_index_schema_add_col(idx, name, (ulint)prefix_len);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_table_create(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  ib_tbl_sch_t sch = to_tbl_sch(L, 2);
  ib_id_t id{};
  ib_err_t rc = ib_table_create(trx, sch, &id);
  if (rc == DB_SUCCESS) {
    lua_pushinteger(L, (lua_Integer)id);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

static int lua_ib_table_drop(lua_State *L) {
  ib_trx_t trx = to_trx(L, 1);
  const char *name = luaL_checkstring(L, 2);
  ib_err_t rc = ib_table_drop(trx, name);
  if (rc == DB_SUCCESS) {
    lua_pushboolean(L, 1);
    return 1;
  }
  lua_pushnil(L);
  lua_pushstring(L, ib_strerror(rc));
  return 2;
}

// Register extended functions under innodb.ext
extern "C" int luaopen_innodb_ext(lua_State *L) {
  luaL_Reg regs[] = {
    {"ib_version", lua_ib_version},
    {"ib_init", lua_ib_init},
    {"ib_startup", lua_ib_startup},
    {"ib_shutdown", lua_ib_shutdown},
    {"ib_trx_begin", lua_ib_trx_begin},
    {"ib_trx_commit", lua_ib_trx_commit},
    {"ib_trx_rollback", lua_ib_trx_rollback},
    {"ib_trx_release", lua_ib_trx_release},
    {"ib_trx_state", lua_ib_trx_state},
    {"ib_trx_start", lua_ib_trx_start},
    {"ib_cursor_open_table", lua_ib_cursor_open_table},
    {"ib_cursor_close", lua_ib_cursor_close},
    {"ib_cursor_next", lua_ib_cursor_next},
    {"ib_cursor_prev", lua_ib_cursor_prev},
    {"ib_cursor_first", lua_ib_cursor_first},
    {"ib_cursor_last", lua_ib_cursor_last},
    {"ib_cursor_attach_trx", lua_ib_cursor_attach_trx},
    {"ib_cursor_set_match_mode", lua_ib_cursor_set_match_mode},
    {"ib_cursor_lock", lua_ib_cursor_lock},
    {"ib_sec_search_tuple_create", lua_ib_sec_search_tuple_create},
    {"ib_col_set_value", lua_ib_col_set_value},
    {"ib_col_get_len", lua_ib_col_get_len},
    {"ib_col_copy_value", lua_ib_col_copy_value},
    {"ib_table_schema_create", lua_ib_table_schema_create},
    {"ib_table_schema_add_col", lua_ib_table_schema_add_col},
    {"ib_index_schema_create", lua_ib_index_schema_create},
    {"ib_index_schema_add_col", lua_ib_index_schema_add_col},
    {"ib_table_create", lua_ib_table_create},
    {"ib_table_drop", lua_ib_table_drop},
    {nullptr, nullptr}
  };

  lua_createtable(L, 0, (int)(sizeof(regs) / sizeof(regs[0])));
  for (const luaL_Reg *r = regs; r->name; ++r) {
    lua_pushcfunction(L, r->func);
    lua_setfield(L, -2, r->name);
  }
  return 1;
}
