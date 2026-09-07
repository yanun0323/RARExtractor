// UnRAR source code may be used in any software to handle RAR archives without
// limitations free of charge, but cannot be used to develop RAR (WinRAR)
// compatible archiver and to re-create RAR compression algorithm, which is
// proprietary. Distribution of modified UnRAR source code in separate form or
// as a part of other software is permitted, provided that full text of this
// paragraph, starting from "UnRAR source code" words, is included in license,
// or in documentation if license is not available, and in source code comments
// of resulting package.

#include "rar_bridge.h"

#include "dll.hpp"

#include <atomic>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <limits>
#include <new>
#include <stdexcept>
#include <string>
#include <system_error>

bool UtfToWide(const char *source, std::wstring &destination);
void WideToUtf(const std::wstring &source, std::string &destination);

struct RARBridgeCancellation {
  std::atomic_bool cancelled{false};
};

namespace {

enum class Operation { list, test, extract };

struct ScanResult {
  uint64_t item_count = 0;
  uint64_t total_size = 0;
};

struct Session {
  const RARBridgeOptions *options = nullptr;
  const RARBridgeCallbacks *callbacks = nullptr;
  RARBridgeCancellation *cancellation = nullptr;
  uint64_t completed_size = 0;
  uint64_t total_size = 0;
  bool resource_limit_reached = false;
  bool missing_volume = false;
  bool callback_cancelled = false;
};

void set_error(char *buffer, size_t size, const char *message) {
  if (buffer == nullptr || size == 0) {
    return;
  }
  std::snprintf(buffer, size, "%s", message);
}

bool is_cancelled(const Session &session) {
  return session.callback_cancelled ||
         (session.cancellation != nullptr &&
          session.cancellation->cancelled.load(std::memory_order_relaxed));
}

uint64_t combined_size(unsigned int low, unsigned int high) {
  return static_cast<uint64_t>(low) |
         (static_cast<uint64_t>(high) << 32U);
}

std::wstring utf8_to_wide(const char *text) {
  std::wstring output;
  if (!UtfToWide(text == nullptr ? "" : text, output)) {
    throw std::runtime_error("Invalid UTF-8");
  }
  return output;
}

std::string wide_to_utf8(const wchar_t *text) {
  std::string output;
  WideToUtf(text == nullptr ? std::wstring() : std::wstring(text), output);
  return output;
}

int unrar_callback(UINT message, LPARAM user_data, LPARAM first, LPARAM second) {
  auto &session = *reinterpret_cast<Session *>(user_data);

  if (is_cancelled(session)) {
    return -1;
  }

  switch (message) {
  case UCM_PROCESSDATA: {
    const uint64_t amount = static_cast<uint64_t>(second);
    if (session.completed_size >
        std::numeric_limits<uint64_t>::max() - amount) {
      session.resource_limit_reached = true;
      return -1;
    }
    session.completed_size += amount;
    if (session.callbacks != nullptr && session.callbacks->progress != nullptr &&
        session.callbacks->progress(session.completed_size, session.total_size,
                                    session.callbacks->context) != 0) {
      if (session.cancellation != nullptr) {
        session.cancellation->cancelled.store(true, std::memory_order_relaxed);
      }
      session.callback_cancelled = true;
      return -1;
    }
    return 0;
  }
  case UCM_NEEDPASSWORDW: {
    if (session.options->password == nullptr ||
        session.options->password[0] == '\0') {
      return -1;
    }
    try {
      const std::wstring password = utf8_to_wide(session.options->password);
      auto *destination = reinterpret_cast<wchar_t *>(first);
      const size_t capacity = static_cast<size_t>(second);
      if (capacity == 0) {
        return -1;
      }
      std::wcsncpy(destination, password.c_str(), capacity - 1);
      destination[capacity - 1] = L'\0';
      return 0;
    } catch (...) {
      return -1;
    }
  }
  case UCM_NEEDPASSWORD:
    return -1;
  case UCM_CHANGEVOLUME:
  case UCM_CHANGEVOLUMEW:
    if (second == RAR_VOL_ASK) {
      session.missing_volume = true;
      return -1;
    }
    return 0;
  case UCM_LARGEDICT: {
    const uint64_t dictionary_size = static_cast<uint64_t>(first) * 1024U;
    if (dictionary_size <= session.options->maximum_dictionary_size) {
      return 1;
    }
    session.resource_limit_reached = true;
    return 0;
  }
  default:
    return 0;
  }
}

RARBridgeResult map_unrar_result(int result, const Session &session) {
  if (is_cancelled(session)) {
    return RAR_BRIDGE_CANCELLED;
  }
  if (session.resource_limit_reached) {
    return RAR_BRIDGE_RESOURCE_LIMIT;
  }
  if (session.missing_volume) {
    return RAR_BRIDGE_MISSING_VOLUME;
  }
  switch (result) {
  case ERAR_SUCCESS:
  case ERAR_END_ARCHIVE:
    return RAR_BRIDGE_SUCCESS;
  case ERAR_BAD_DATA:
  case ERAR_BAD_ARCHIVE:
  case ERAR_UNKNOWN_FORMAT:
  case ERAR_EREAD:
    return RAR_BRIDGE_BAD_ARCHIVE;
  case ERAR_BAD_PASSWORD:
    return RAR_BRIDGE_BAD_PASSWORD;
  case ERAR_MISSING_PASSWORD:
    return RAR_BRIDGE_PASSWORD_REQUIRED;
  case ERAR_EOPEN:
    return RAR_BRIDGE_OPEN_FAILED;
  case ERAR_ECREATE:
  case ERAR_ECLOSE:
  case ERAR_EWRITE:
    return RAR_BRIDGE_WRITE_FAILED;
  case ERAR_LARGE_DICT:
  case ERAR_NO_MEMORY:
    return RAR_BRIDGE_RESOURCE_LIMIT;
  default:
    return RAR_BRIDGE_UNKNOWN_ERROR;
  }
}

const char *message_for_result(RARBridgeResult result) {
  switch (result) {
  case RAR_BRIDGE_SUCCESS:
    return "Success";
  case RAR_BRIDGE_INVALID_ARGUMENT:
    return "Invalid argument";
  case RAR_BRIDGE_OPEN_FAILED:
    return "Cannot open the RAR archive";
  case RAR_BRIDGE_BAD_ARCHIVE:
    return "The RAR archive is damaged or unsupported";
  case RAR_BRIDGE_BAD_PASSWORD:
    return "The password is incorrect";
  case RAR_BRIDGE_PASSWORD_REQUIRED:
    return "A password is required";
  case RAR_BRIDGE_MISSING_VOLUME:
    return "A RAR volume is missing";
  case RAR_BRIDGE_UNSAFE_ENTRY:
    return "The RAR archive contains an unsafe path or link";
  case RAR_BRIDGE_RESOURCE_LIMIT:
    return "The RAR archive exceeds a resource limit";
  case RAR_BRIDGE_CANCELLED:
    return "The operation was cancelled";
  case RAR_BRIDGE_WRITE_FAILED:
    return "Cannot write the extracted files";
  case RAR_BRIDGE_UNKNOWN_ERROR:
    return "UnRAR returned an unknown error";
  }
  return "UnRAR returned an unknown error";
}

bool path_is_safe(const std::string &path, uint32_t maximum_depth) {
  if (path.empty() || maximum_depth == 0 || path.front() == '/' ||
      path.front() == '\\') {
    return false;
  }
  if (path.size() >= 2 &&
      ((path[0] >= 'A' && path[0] <= 'Z') ||
       (path[0] >= 'a' && path[0] <= 'z')) &&
      path[1] == ':') {
    return false;
  }

  uint32_t depth = 0;
  size_t component_start = 0;
  for (size_t index = 0; index <= path.size(); ++index) {
    if (index != path.size() && path[index] != '/' && path[index] != '\\') {
      continue;
    }
    const std::string component =
        path.substr(component_start, index - component_start);
    component_start = index + 1;
    if (component.empty()) {
      continue;
    }
    if (component == "." || component == "..") {
      return false;
    }
    ++depth;
    if (depth > maximum_depth) {
      return false;
    }
  }
  return depth != 0;
}

RARBridgeResult scan_archive(Session &session, bool report_items,
                             ScanResult &scan_result) {
  RAROpenArchiveDataEx open_data{};
  open_data.ArcName = const_cast<char *>(session.options->archive_path);
  open_data.OpenMode = RAR_OM_LIST;
  open_data.Callback = unrar_callback;
  open_data.UserData = reinterpret_cast<LPARAM>(&session);

  HANDLE archive = RAROpenArchiveEx(&open_data);
  if (archive == nullptr) {
    return map_unrar_result(static_cast<int>(open_data.OpenResult), session);
  }

  RARBridgeResult bridge_result = RAR_BRIDGE_SUCCESS;
  while (true) {
    if (is_cancelled(session)) {
      bridge_result = RAR_BRIDGE_CANCELLED;
      break;
    }
    RARHeaderDataEx header{};
    wchar_t file_name[32768]{};
    header.FileNameEx = file_name;
    header.FileNameExSize = sizeof(file_name) / sizeof(file_name[0]);

    const int read_result = RARReadHeaderEx(archive, &header);
    if (read_result == ERAR_END_ARCHIVE) {
      break;
    }
    if (read_result != ERAR_SUCCESS) {
      bridge_result = map_unrar_result(read_result, session);
      break;
    }

    std::string path;
    try {
      path = wide_to_utf8(file_name);
    } catch (...) {
      bridge_result = RAR_BRIDGE_UNSAFE_ENTRY;
      break;
    }

    const uint64_t unpacked_size =
        combined_size(header.UnpSize, header.UnpSizeHigh);
    const uint64_t dictionary_size =
        static_cast<uint64_t>(header.DictSize) * 1024U;

    if (!path_is_safe(path, session.options->maximum_directory_depth) ||
        header.RedirType != 0) {
      bridge_result = RAR_BRIDGE_UNSAFE_ENTRY;
      break;
    }
    if (unpacked_size > session.options->maximum_file_size ||
        unpacked_size > session.options->maximum_total_size ||
        dictionary_size > session.options->maximum_dictionary_size ||
        scan_result.item_count >= session.options->maximum_item_count ||
        scan_result.total_size >
            session.options->maximum_total_size - unpacked_size) {
      bridge_result = RAR_BRIDGE_RESOURCE_LIMIT;
      break;
    }

    ++scan_result.item_count;
    scan_result.total_size += unpacked_size;

    uint32_t flags = 0;
    if ((header.Flags & RHDF_DIRECTORY) != 0) {
      flags |= RAR_BRIDGE_ITEM_DIRECTORY;
    }
    if ((header.Flags & RHDF_ENCRYPTED) != 0) {
      flags |= RAR_BRIDGE_ITEM_ENCRYPTED;
    }
    if ((header.Flags & RHDF_SOLID) != 0) {
      flags |= RAR_BRIDGE_ITEM_SOLID;
    }

    if (report_items && session.callbacks != nullptr &&
        session.callbacks->item != nullptr) {
      const RARBridgeItem item{path.c_str(), unpacked_size, dictionary_size,
                               flags};
      if (session.callbacks->item(&item, session.callbacks->context) != 0) {
        if (session.cancellation != nullptr) {
          session.cancellation->cancelled.store(true,
                                                std::memory_order_relaxed);
        }
        session.callback_cancelled = true;
        bridge_result = RAR_BRIDGE_CANCELLED;
        break;
      }
    }

    const int process_result = RARProcessFile(archive, RAR_SKIP, nullptr, nullptr);
    if (process_result != ERAR_SUCCESS) {
      bridge_result = map_unrar_result(process_result, session);
      break;
    }
  }

  const int close_result = RARCloseArchive(archive);
  if (bridge_result == RAR_BRIDGE_SUCCESS && close_result != ERAR_SUCCESS) {
    bridge_result = map_unrar_result(close_result, session);
  }
  return bridge_result;
}

RARBridgeResult process_archive(Session &session, Operation operation) {
  RAROpenArchiveDataEx open_data{};
  open_data.ArcName = const_cast<char *>(session.options->archive_path);
  open_data.OpenMode = RAR_OM_EXTRACT;
  open_data.Callback = unrar_callback;
  open_data.UserData = reinterpret_cast<LPARAM>(&session);

  HANDLE archive = RAROpenArchiveEx(&open_data);
  if (archive == nullptr) {
    return map_unrar_result(static_cast<int>(open_data.OpenResult), session);
  }

  RARBridgeResult bridge_result = RAR_BRIDGE_SUCCESS;
  while (true) {
    if (is_cancelled(session)) {
      bridge_result = RAR_BRIDGE_CANCELLED;
      break;
    }
    RARHeaderDataEx header{};
    wchar_t file_name[32768]{};
    header.FileNameEx = file_name;
    header.FileNameExSize = sizeof(file_name) / sizeof(file_name[0]);
    const int read_result = RARReadHeaderEx(archive, &header);
    if (read_result == ERAR_END_ARCHIVE) {
      break;
    }
    if (read_result != ERAR_SUCCESS) {
      bridge_result = map_unrar_result(read_result, session);
      break;
    }

    if (session.callbacks != nullptr && session.callbacks->item != nullptr) {
      std::string path;
      try {
        path = wide_to_utf8(file_name);
      } catch (...) {
        bridge_result = RAR_BRIDGE_UNSAFE_ENTRY;
        break;
      }
      const uint64_t unpacked_size =
          combined_size(header.UnpSize, header.UnpSizeHigh);
      uint32_t flags = 0;
      if ((header.Flags & RHDF_DIRECTORY) != 0) {
        flags |= RAR_BRIDGE_ITEM_DIRECTORY;
      }
      if ((header.Flags & RHDF_ENCRYPTED) != 0) {
        flags |= RAR_BRIDGE_ITEM_ENCRYPTED;
      }
      if ((header.Flags & RHDF_SOLID) != 0) {
        flags |= RAR_BRIDGE_ITEM_SOLID;
      }
      const RARBridgeItem item{
          path.c_str(), unpacked_size,
          static_cast<uint64_t>(header.DictSize) * 1024U, flags};
      if (session.callbacks->item(&item, session.callbacks->context) != 0) {
        if (session.cancellation != nullptr) {
          session.cancellation->cancelled.store(true,
                                                std::memory_order_relaxed);
        }
        session.callback_cancelled = true;
        bridge_result = RAR_BRIDGE_CANCELLED;
        break;
      }
    }

    char *destination = operation == Operation::extract
                            ? const_cast<char *>(session.options->destination_path)
                            : nullptr;
    const int unrar_operation =
        operation == Operation::extract ? RAR_EXTRACT : RAR_TEST;
    const int process_result =
        RARProcessFile(archive, unrar_operation, destination, nullptr);
    if (process_result != ERAR_SUCCESS) {
      bridge_result = map_unrar_result(process_result, session);
      break;
    }
  }

  const int close_result = RARCloseArchive(archive);
  if (bridge_result == RAR_BRIDGE_SUCCESS && close_result != ERAR_SUCCESS) {
    bridge_result = map_unrar_result(close_result, session);
  }
  return bridge_result;
}

bool options_are_valid(const RARBridgeOptions *options, Operation operation) {
  if (options == nullptr || options->archive_path == nullptr ||
      options->archive_path[0] == '\0' ||
      options->maximum_dictionary_size == 0 ||
      options->maximum_total_size == 0 || options->maximum_file_size == 0 ||
      options->maximum_item_count == 0 ||
      options->maximum_directory_depth == 0) {
    return false;
  }
  return operation != Operation::extract ||
         (options->destination_path != nullptr &&
          options->destination_path[0] != '\0');
}

RARBridgeResult run(const RARBridgeOptions *options,
                    const RARBridgeCallbacks *callbacks,
                    RARBridgeCancellation *cancellation, Operation operation,
                    char *error_message, size_t error_message_size) {
  if (!options_are_valid(options, operation)) {
    set_error(error_message, error_message_size,
              message_for_result(RAR_BRIDGE_INVALID_ARGUMENT));
    return RAR_BRIDGE_INVALID_ARGUMENT;
  }

  Session session{options, callbacks, cancellation};
  if (is_cancelled(session)) {
    set_error(error_message, error_message_size,
              message_for_result(RAR_BRIDGE_CANCELLED));
    return RAR_BRIDGE_CANCELLED;
  }
  ScanResult scan_result;
  RARBridgeResult result =
      scan_archive(session, operation == Operation::list, scan_result);
  if (result != RAR_BRIDGE_SUCCESS || operation == Operation::list) {
    set_error(error_message, error_message_size, message_for_result(result));
    return result;
  }
  session.total_size = scan_result.total_size;

  bool created_destination = false;
  if (operation == Operation::extract) {
    std::error_code filesystem_error;
    const std::filesystem::path destination(options->destination_path);
    if (std::filesystem::exists(destination, filesystem_error) ||
        filesystem_error || destination.parent_path().empty() ||
        !std::filesystem::is_directory(destination.parent_path(),
                                       filesystem_error) ||
        filesystem_error ||
        !std::filesystem::create_directory(destination, filesystem_error) ||
        filesystem_error) {
      result = RAR_BRIDGE_WRITE_FAILED;
    } else {
      created_destination = true;
    }
  }

  if (result == RAR_BRIDGE_SUCCESS) {
    result = process_archive(session, operation);
  }

  if (created_destination && result != RAR_BRIDGE_SUCCESS) {
    std::error_code ignored;
    std::filesystem::remove_all(options->destination_path, ignored);
  }

  set_error(error_message, error_message_size, message_for_result(result));
  return result;
}

} // namespace

extern "C" {

RARBridgeCancellation *rar_bridge_cancellation_create(void) {
  return new (std::nothrow) RARBridgeCancellation;
}

void rar_bridge_cancel(RARBridgeCancellation *cancellation) {
  if (cancellation != nullptr) {
    cancellation->cancelled.store(true, std::memory_order_relaxed);
  }
}

void rar_bridge_cancellation_destroy(RARBridgeCancellation *cancellation) {
  delete cancellation;
}

RARBridgeResult rar_bridge_list(const RARBridgeOptions *options,
                                const RARBridgeCallbacks *callbacks,
                                RARBridgeCancellation *cancellation,
                                char *error_message,
                                size_t error_message_size) {
  return run(options, callbacks, cancellation, Operation::list, error_message,
             error_message_size);
}

RARBridgeResult rar_bridge_test(const RARBridgeOptions *options,
                                const RARBridgeCallbacks *callbacks,
                                RARBridgeCancellation *cancellation,
                                char *error_message,
                                size_t error_message_size) {
  return run(options, callbacks, cancellation, Operation::test, error_message,
             error_message_size);
}

RARBridgeResult rar_bridge_extract(const RARBridgeOptions *options,
                                   const RARBridgeCallbacks *callbacks,
                                   RARBridgeCancellation *cancellation,
                                   char *error_message,
                                   size_t error_message_size) {
  return run(options, callbacks, cancellation, Operation::extract,
             error_message, error_message_size);
}

int rar_bridge_path_is_safe(const char *path, uint32_t maximum_directory_depth) {
  return path != nullptr && path_is_safe(path, maximum_directory_depth) ? 1 : 0;
}

} // extern "C"
