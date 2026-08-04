#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>

namespace {

constexpr DWORD macm_signature = 0x4d41434d;
constexpr DWORD macm_commit = 0x00ab0001;

template<typename T>
T & field(std::uint8_t * base, std::size_t offset) {
    return *reinterpret_cast<T *>(base + offset);
}

}

int main(int argc, char ** argv) {
    HANDLE mapping = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, "MACMSharedMemory");
    if (!mapping) {
        std::fprintf(stderr, "OpenFileMapping failed: %lu\n", GetLastError());
        return 1;
    }

    auto * view = static_cast<std::uint8_t *>(MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, 0));
    if (!view) {
        std::fprintf(stderr, "MapViewOfFile failed: %lu\n", GetLastError());
        CloseHandle(mapping);
        return 1;
    }

    HANDLE mutex = CreateMutexA(nullptr, FALSE, "Global\\Access_MACMSharedMemory");
    WaitForSingleObject(mutex, INFINITE);

    int result = 0;
    if (field<DWORD>(view, 0x00) != macm_signature || field<DWORD>(view, 0x0c) == 0) {
        std::fprintf(stderr, "Invalid MACM mapping\n");
        result = 1;
    } else {
        auto * gpu = view + field<DWORD>(view, 0x08);

        if (argc == 3 || argc == 5) {
            field<DWORD>(gpu, 0x34) = std::strtoul(argv[1], nullptr, 10);
            field<DWORD>(gpu, 0x38) = std::strtoul(argv[2], nullptr, 10);
            if (argc == 5) {
                field<LONG>(gpu, 0xbc) = std::strtol(argv[3], nullptr, 10);
                field<LONG>(gpu, 0xcc) = std::strtol(argv[4], nullptr, 10);
            }
            field<DWORD>(view, 0x20) = macm_commit;
        }

        std::printf("fan=%lu flags=%lu core_boost=%ld memory_boost=%ld\n",
                field<DWORD>(gpu, 0x34), field<DWORD>(gpu, 0x38),
                field<LONG>(gpu, 0xbc), field<LONG>(gpu, 0xcc));
    }

    ReleaseMutex(mutex);
    CloseHandle(mutex);
    UnmapViewOfFile(view);
    CloseHandle(mapping);
    return result;
}
