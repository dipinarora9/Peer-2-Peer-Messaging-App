#include "dart_api_dl.h"
#include "dart_version.h"
#include "internal/dart_api_dl_impl.h"

#include <string.h>

#define DART_API_DL_DEFINITIONS(name)                                          \
  using name##Type = decltype(&name);                                          \
  name##Type name##_DL = nullptr;
DART_API_ALL_DL_SYMBOLS(DART_API_DL_DEFINITIONS)
#undef DART_API_DL_DEFINITIONS

typedef void (*DartApiEntry_function)();

DartApiEntry_function FindFunctionPointer(const DartApiEntry* entries,
                                          const char* name) {
  while (entries->name != nullptr) {
    if (strcmp(entries->name, name) == 0) return entries->function;
    entries++;
  }
  return nullptr;
}

intptr_t Dart_InitializeApiDL(void* data) {
  DartApi* dart_api_data = reinterpret_cast<DartApi*>(data);

  if (dart_api_data->major != DART_API_DL_MAJOR_VERSION) {
    // If the DartVM we're running on does not have the same version as this
    // file was compiled against, refuse to initialize. The symbols are not
    // compatible.
    return -1;
  }
  // Minor versions are allowed to be different.
  // If the DartVM has a higher minor version, it will provide more symbols
  // than we initialize here.
  // If the DartVM has a lower minor version, it will not provide all symbols.
  // In that case, we leave the missing symbols un-initialized. Those symbols
  // should not be used by the Dart and native code. The client is responsible
  // for checking the minor version number himself based on which symbols it
  // is using.
  // (If we would error out on this case, recompiling native code against a
  // newer SDK would break all uses on older SDKs, which is too strict.)

  const DartApiEntry* dart_api_function_pointers = dart_api_data->functions;

#define DART_API_DL_INIT(name)                                                 \
  name##_DL = reinterpret_cast<name##Type>(                                    \
      FindFunctionPointer(dart_api_function_pointers, #name));
  DART_API_ALL_DL_SYMBOLS(DART_API_DL_INIT)
#undef DART_API_DL_INIT

  return 0;
}