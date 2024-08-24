/** Copyright (c) 2024 Sunny Bains. All rights reserved */

#pragma once

#include "innodb.h"

#include <format>
#include <limits>
#include <string>
#include <type_traits>
#include <source_location>

/* Include the header file generated by GNU autoconf or CMake */
#include "ib0config.h"

/* Another basic type we use is unsigned long integer which should be equal to
the word size of the machine, that is on a 32-bit platform 32 bits, and on a
64-bit platform 64 bits. We also give the printf format for the type as a
macro ULINTPF. */

using lint = long int;
using ulint = uintptr_t;

#define ULINTPF "%lu"

/* Disable GCC extensions */
#if !defined(__attribute__) && !defined(__GNUC__)
#define __attribute__(X)
#define HIDDEN
#else /* !defined( __attribute__) && !defined(__GNUC__) */
/* Linkage specifier for non-static InnoDB symbols (variables and functions)
that are only referenced from within InnoDB. */
#define HIDDEN __attribute__((visibility("hidden")))
#endif /* !defined( __attribute__) && !defined(__GNUC__) */

/** Check B-tree links */
#define UNIV_BTR_DEBUG

/** Light memory debugging */
#define UNIV_LIGHT_MEM_DEBUG

constexpr ulint UNIV_WORD_SIZE = SIZEOF_LONG;

/** The following alignment is used in memory allocations in memory heap
management to ensure correct alignment for doubles etc. */
constexpr ulint UNIV_MEM_ALIGNMENT = 8;

/** The following alignment is used in aligning lints etc. */
constexpr ulint UNIV_WORD_ALIGNMENT = UNIV_WORD_SIZE;

/** The 2-logarithm of UNIV_PAGE_SIZE: */
constexpr ulint UNIV_PAGE_SIZE_SHIFT = 14;

/** The universal page size of the database */
constexpr ulint UNIV_PAGE_SIZE = 1UL << UNIV_PAGE_SIZE_SHIFT;

/* Maximum number of parallel threads in a parallelized operation */
const ulint UNIV_MAX_PARALLELISM = 32;

using byte = unsigned char;

using uint16_t = uint16_t;

constexpr ulint ULINT_MAX = ((ulint)(-2));
constexpr ulint ULINT_UNDEFINED = std::numeric_limits<ulint>::max();
constexpr uint32_t ULINT32_UNDEFINED = std::numeric_limits<uint32_t>::max();
constexpr uint64_t IB_UINT64_T_MAX = std::numeric_limits<uint64_t>::max();
constexpr uint64_t IB_ULONGLONG_MAX = std::numeric_limits<uint64_t>::max();
constexpr uint32_t UINT32_MASK = std::numeric_limits<uint32_t>::max();

/** The following number as the length of a logical field means that the field
has the SQL nullptr as its value. NOTE that because we assume that the length
of a field is a 32-bit integer when we store it, for example, to an undo log
on disk, we must have also this number fit in 32 bits, also in 64-bit
computers! */
constexpr auto UNIV_SQL_NULL = ULINT32_UNDEFINED;

/** Lengths which are not UNIV_SQL_NULL, but bigger than the following
number indicate that a field contains a reference to an externally
stored part of the field in the tablespace. The length field then
contains the sum of the following flag and the locally stored len. */
constexpr auto UNIV_EXTERN_STORAGE_FIELD = (UNIV_SQL_NULL - UNIV_PAGE_SIZE);

/* Some macros to improve branch prediction and reduce cache misses */
#if defined(__GNUC__)
/** Tell the compiler that 'expr' probably evaluates to 'constant'. */
#define expect(expr, constant) __builtin_expect(expr, constant)
/** Tell the compiler that a pointer is likely to be nullptr */
#define likely_null(ptr) __builtin_expect((ulint)ptr, 0)
/** Minimize cache-miss latency by moving data at addr into a cache before it is
 * read. */
#define prefetch_r(addr) __builtin_prefetch(addr, 0, 3)
/** Minimize cache-miss latency by moving data at addr into a cache before
it is read or written. */
#define prefetch_rw(addr) __builtin_prefetch(addr, 1, 3)
#else
#define expect(c, f)
#endif /* defined(__GNUC__) */

/** Tell the compiler that cond is likely to hold */
#define likely(cond) expect(cond, true)

/** Tell the compiler that cond is unlikely to hold */
#define unlikely(cond) expect(cond, false)

constexpr ulint NAME_CHAR_LEN = 64;
constexpr ulint SYSTEM_CHARSET_MBMAXLEN = 3;
constexpr ulint NAME_LEN = NAME_CHAR_LEN * SYSTEM_CHARSET_MBMAXLEN;

constexpr ulint IB_FILE = 1;
constexpr auto IB_TMP_FILE = ULINT_UNDEFINED;

/* An auxiliary macro to improve readability */
#if !defined __STRICT_ANSI__ && defined __GNUC__ && (__GNUC__) > 2
#define STRUCT_FLD(name, value) .name = value
#else
#define STRUCT_FLD(name, value) value
#endif

// FIXME: Get rid of this too
using os_thread_ret_t = void *;

template <typename T>
constexpr auto to_int(T v) -> typename std::underlying_type<T>::type {
  return static_cast<typename std::underlying_type<T>::type>(v);
}

/** Explicitly call the destructor, this is to get around Clang bug#12350.
@param[in,out]  p               Instance on which to call the destructor */
template <typename T>
void call_destructor(T *p, int n = 1) {
  for (int i = 0; i < n; ++i, ++p) {
    p->~T();
  }
}

constexpr const char SRV_PATH_SEPARATOR = '/';

/** Page number type. FIXME: Change to uint32_t later. */
using page_no_t = ulint;

/** Table space ID type. FIXME: Change to uint32_t later. */
using space_id_t = ulint;

/** Log sequence number. */
using lsn_t = uint64_t;

/** Transaction identifier (DB_TRX_ID, DATA_TRX_ID) */
using trx_id_t = uint64_t;

constexpr auto NULL_PAGE_NO = std::numeric_limits<page_no_t>::max();
constexpr auto NULL_SPACE_ID = std::numeric_limits<space_id_t>::max();

constexpr auto LSN_MAX = std::numeric_limits<lsn_t>::max();

constexpr ulint IB_FILE_BLOCK_SIZE = 512;

#ifdef UNIV_DEBUG
#define IF_DEBUG(...) __VA_ARGS__
#else
#define IF_DEBUG(...)
#endif /* UNIV_DEBUG */

#ifdef UNIV_SYNC_DEBUG
#define IF_SYNC_DEBUG(...) __VA_ARGS__
#else
#define IF_SYNC_DEBUG(...)
#endif /* UNIV_SYNC_DEBUG */

struct Source_location {
  /** Constructor/
   * @param file      File name
   * @param line      Line number
   * @param function  Function name
   */
  explicit Source_location(auto from = std::source_location::current())
    : m_from(from) {}  

  explicit Source_location()
    : m_from(std::source_location::current()){}

  std::string to_string() const noexcept {
    return std::format("{}:{} {}", m_from.file_name(), m_from.line(), m_from.function_name());
  }

  const std::source_location m_from{};
};

#ifdef __cpp_lib_hardware_interference_size
using std::hardware_constructive_interference_size;
using std::hardware_destructive_interference_size;
#else
// 64 bytes on x86-64 │ L1_CACHE_BYTES │ L1_CACHE_SHIFT │ __cacheline_aligned │ ...
constexpr std::size_t hardware_constructive_interference_size = 64;
constexpr std::size_t hardware_destructive_interference_size = 64;
#endif /* __cpp_lib_hardware_interference_size */

/** OS file handle */
using os_file_t = int;

#include "innodb0valgrind.h"
#include "ut0dbg.h"
#include "ut0ut.h"
