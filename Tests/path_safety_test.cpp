#include "rar_bridge.h"

#include <cassert>
#include <cstdio>

int main() {
  assert(rar_bridge_path_is_safe("file.txt", 8) == 1);
  assert(rar_bridge_path_is_safe("folder/file.txt", 8) == 1);
  assert(rar_bridge_path_is_safe("folder\\file.txt", 8) == 1);
  assert(rar_bridge_path_is_safe("", 8) == 0);
  assert(rar_bridge_path_is_safe("/etc/passwd", 8) == 0);
  assert(rar_bridge_path_is_safe("\\server\\file", 8) == 0);
  assert(rar_bridge_path_is_safe("C:\\file", 8) == 0);
  assert(rar_bridge_path_is_safe("../file", 8) == 0);
  assert(rar_bridge_path_is_safe("folder/../file", 8) == 0);
  assert(rar_bridge_path_is_safe("folder/./file", 8) == 0);
  assert(rar_bridge_path_is_safe("a/b/c", 2) == 0);

  RARBridgeOptions options{};
  options.archive_path = "/file-that-does-not-exist.rar";
  options.maximum_dictionary_size = 1;
  options.maximum_total_size = 1;
  options.maximum_file_size = 1;
  options.maximum_item_count = 1;
  options.maximum_directory_depth = 1;
  RARBridgeCancellation *cancellation = rar_bridge_cancellation_create();
  assert(cancellation != nullptr);
  rar_bridge_cancel(cancellation);
  assert(rar_bridge_list(&options, nullptr, cancellation, nullptr, 0) ==
         RAR_BRIDGE_CANCELLED);
  rar_bridge_cancellation_destroy(cancellation);

  std::puts("path-safety-test: passed");
}
