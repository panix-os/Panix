#include <stddef.h>
#include <stdint.h>

class MemoryRange {
    private:

        uintptr_t _base;
        size_t _size;

    public:

        MemoryRange()
            : _base(0),
              _size(0)
        {
        }

        MemoryRange(uintptr_t base, size_t size)
            : _base(base), _size(size)
        {
        }

        uintptr_t base(void) { return _base; }

        size_t size(void) { return _size; }
};
