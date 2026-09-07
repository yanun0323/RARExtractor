#ifndef RAR_BRIDGE_H
#define RAR_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RARBridgeCancellation RARBridgeCancellation;

typedef enum RARBridgeResult {
  RAR_BRIDGE_SUCCESS = 0,
  RAR_BRIDGE_INVALID_ARGUMENT = 1,
  RAR_BRIDGE_OPEN_FAILED = 2,
  RAR_BRIDGE_BAD_ARCHIVE = 3,
  RAR_BRIDGE_BAD_PASSWORD = 4,
  RAR_BRIDGE_PASSWORD_REQUIRED = 5,
  RAR_BRIDGE_MISSING_VOLUME = 6,
  RAR_BRIDGE_UNSAFE_ENTRY = 7,
  RAR_BRIDGE_RESOURCE_LIMIT = 8,
  RAR_BRIDGE_CANCELLED = 9,
  RAR_BRIDGE_WRITE_FAILED = 10,
  RAR_BRIDGE_UNKNOWN_ERROR = 11
} RARBridgeResult;

typedef enum RARBridgeItemFlags {
  RAR_BRIDGE_ITEM_DIRECTORY = 1 << 0,
  RAR_BRIDGE_ITEM_ENCRYPTED = 1 << 1,
  RAR_BRIDGE_ITEM_SOLID = 1 << 2
} RARBridgeItemFlags;

typedef struct RARBridgeOptions {
  const char *archive_path;
  const char *destination_path;
  const char *password;
  uint64_t maximum_dictionary_size;
  uint64_t maximum_total_size;
  uint64_t maximum_file_size;
  uint64_t maximum_item_count;
  uint32_t maximum_directory_depth;
} RARBridgeOptions;

typedef struct RARBridgeItem {
  const char *path;
  uint64_t unpacked_size;
  uint64_t dictionary_size;
  uint32_t flags;
} RARBridgeItem;

typedef int (*RARBridgeItemCallback)(const RARBridgeItem *item, void *context);
typedef int (*RARBridgeProgressCallback)(uint64_t completed_size,
                                         uint64_t total_size,
                                         void *context);

typedef struct RARBridgeCallbacks {
  RARBridgeItemCallback item;
  RARBridgeProgressCallback progress;
  void *context;
} RARBridgeCallbacks;

RARBridgeCancellation *rar_bridge_cancellation_create(void);
void rar_bridge_cancel(RARBridgeCancellation *cancellation);
void rar_bridge_cancellation_destroy(RARBridgeCancellation *cancellation);

RARBridgeResult rar_bridge_list(const RARBridgeOptions *options,
                                const RARBridgeCallbacks *callbacks,
                                RARBridgeCancellation *cancellation,
                                char *error_message,
                                size_t error_message_size);

RARBridgeResult rar_bridge_test(const RARBridgeOptions *options,
                                const RARBridgeCallbacks *callbacks,
                                RARBridgeCancellation *cancellation,
                                char *error_message,
                                size_t error_message_size);

RARBridgeResult rar_bridge_extract(const RARBridgeOptions *options,
                                   const RARBridgeCallbacks *callbacks,
                                   RARBridgeCancellation *cancellation,
                                   char *error_message,
                                   size_t error_message_size);

int rar_bridge_path_is_safe(const char *path, uint32_t maximum_directory_depth);

#ifdef __cplusplus
}
#endif

#endif

