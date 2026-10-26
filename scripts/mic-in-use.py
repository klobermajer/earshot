import ctypes
import struct
import sys

core_audio = ctypes.CDLL('/System/Library/Frameworks/CoreAudio.framework/CoreAudio')

SYSTEM_OBJECT = 1
SCOPE_GLOBAL = 'glob'
PROCESS_OBJECT_LIST = 'prs#'
PROCESS_IS_RUNNING_INPUT = 'piri'


class Address(ctypes.Structure):
    _fields_ = [('selector', ctypes.c_uint32), ('scope', ctypes.c_uint32), ('element', ctypes.c_uint32)]


def code(name):
    return struct.unpack('>I', name.encode())[0]


def read(object_id, selector):
    address = Address(code(selector), code(SCOPE_GLOBAL), 0)
    size = ctypes.c_uint32(0)
    if core_audio.AudioObjectGetPropertyDataSize(object_id, ctypes.byref(address), 0, None, ctypes.byref(size)):
        return []
    data = (ctypes.c_uint32 * (size.value // 4))()
    if core_audio.AudioObjectGetPropertyData(object_id, ctypes.byref(address), 0, None, ctypes.byref(size), data):
        return []
    return list(data)


processes = read(SYSTEM_OBJECT, PROCESS_OBJECT_LIST)
sys.exit(0 if any(any(read(process, PROCESS_IS_RUNNING_INPUT)) for process in processes) else 1)
