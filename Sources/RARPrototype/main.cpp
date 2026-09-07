#include "rar_bridge.h"

#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>

namespace {

void print_usage(const char *program) {
  std::fprintf(stderr,
               "Usage:\n"
               "  %s list <archive.rar> [--password-stdin]\n"
               "  %s test <archive.rar> [--password-stdin]\n"
               "  %s extract <archive.rar> <new-directory> "
               "[--password-stdin]\n",
               program, program, program);
}

std::string json_string(const char *text) {
  std::string output = "\"";
  for (const unsigned char character : std::string(text)) {
    switch (character) {
    case '\\':
      output += "\\\\";
      break;
    case '"':
      output += "\\\"";
      break;
    case '\n':
      output += "\\n";
      break;
    case '\r':
      output += "\\r";
      break;
    case '\t':
      output += "\\t";
      break;
    default:
      if (character < 0x20) {
        char escaped[7];
        std::snprintf(escaped, sizeof(escaped), "\\u%04x", character);
        output += escaped;
      } else {
        output += static_cast<char>(character);
      }
    }
  }
  output += '"';
  return output;
}

int print_item(const RARBridgeItem *item, void *) {
  std::printf("{\"path\":%s,\"size\":%llu,\"flags\":%u}\n",
              json_string(item->path).c_str(),
              static_cast<unsigned long long>(item->unpacked_size), item->flags);
  return 0;
}

RARBridgeOptions default_options() {
  RARBridgeOptions options{};
  options.maximum_dictionary_size = 4ULL * 1024 * 1024 * 1024;
  options.maximum_total_size = 1024ULL * 1024 * 1024 * 1024;
  options.maximum_file_size = 256ULL * 1024 * 1024 * 1024;
  options.maximum_item_count = 1'000'000;
  options.maximum_directory_depth = 128;
  return options;
}

} // namespace

int main(int argc, char **argv) {
  if (argc < 3) {
    print_usage(argv[0]);
    return 64;
  }

  const std::string command = argv[1];
  if (command != "list" && command != "test" && command != "extract") {
    print_usage(argv[0]);
    return 64;
  }

  const int minimum_arguments = command == "extract" ? 4 : 3;
  if (argc < minimum_arguments || argc > minimum_arguments + 1) {
    print_usage(argv[0]);
    return 64;
  }

  std::string password;
  if (argc == minimum_arguments + 1) {
    if (std::strcmp(argv[minimum_arguments], "--password-stdin") != 0) {
      print_usage(argv[0]);
      return 64;
    }
    std::getline(std::cin, password);
  }

  RARBridgeOptions options = default_options();
  options.archive_path = argv[2];
  options.destination_path = command == "extract" ? argv[3] : nullptr;
  options.password = password.empty() ? nullptr : password.c_str();

  RARBridgeCallbacks callbacks{};
  callbacks.item = print_item;
  char error[256]{};
  RARBridgeResult result;
  if (command == "list") {
    result = rar_bridge_list(&options, &callbacks, nullptr, error, sizeof(error));
  } else if (command == "test") {
    result = rar_bridge_test(&options, nullptr, nullptr, error, sizeof(error));
  } else {
    result =
        rar_bridge_extract(&options, &callbacks, nullptr, error, sizeof(error));
  }

  if (result != RAR_BRIDGE_SUCCESS) {
    std::fprintf(stderr, "rar-prototype: %s\n", error);
    return static_cast<int>(result);
  }
  return 0;
}

