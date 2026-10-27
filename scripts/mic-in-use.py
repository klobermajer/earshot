import ctypes
import json
import os
import struct
import subprocess
import sys

if sys.platform == 'darwin':
    core_audio = ctypes.CDLL('/System/Library/Frameworks/CoreAudio.framework/CoreAudio')
    core_foundation = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    core_foundation.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
    core_foundation.CFRelease.argtypes = [ctypes.c_void_p]

SYSTEM_OBJECT = 1
SCOPE_GLOBAL = 'glob'
PROCESS_OBJECT_LIST = 'prs#'
PROCESS_IS_RUNNING_INPUT = 'piri'
PROCESS_BUNDLE_ID = 'pbid'
PROCESS_PID = 'ppid'
UTF8 = 0x08000100

class Address(ctypes.Structure):
    _fields_ = [('selector', ctypes.c_uint32), ('scope', ctypes.c_uint32), ('element', ctypes.c_uint32)]

def code(name):
    return struct.unpack('>I', name.encode())[0]

def read_raw(object_id, selector, buffer):
    address = Address(code(selector), code(SCOPE_GLOBAL), 0)
    size = ctypes.c_uint32(ctypes.sizeof(buffer))
    return core_audio.AudioObjectGetPropertyData(object_id, ctypes.byref(address), 0, None, ctypes.byref(size), ctypes.byref(buffer)) == 0

def read(object_id, selector):
    address = Address(code(selector), code(SCOPE_GLOBAL), 0)
    size = ctypes.c_uint32(0)
    if core_audio.AudioObjectGetPropertyDataSize(object_id, ctypes.byref(address), 0, None, ctypes.byref(size)):
        return []
    data = (ctypes.c_uint32 * (size.value // 4))()
    return list(data) if read_raw(object_id, selector, data) else []

def read_string(object_id, selector):
    ref = ctypes.c_void_p()
    if not read_raw(object_id, selector, ref) or not ref.value:
        return ''
    buffer = ctypes.create_string_buffer(1024)
    found = core_foundation.CFStringGetCString(ref, buffer, len(buffer), UTF8)
    core_foundation.CFRelease(ref)
    return buffer.value.decode() if found else ''

def executable_name(pid):
    try:
        path = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'comm='], capture_output=True, text=True).stdout.strip()
    except OSError:
        return ''
    return os.path.basename(path)

def names(process):
    pid = read(process, PROCESS_PID)
    return {name.lower() for name in [read_string(process, PROCESS_BUNDLE_ID), executable_name(pid[0]) if pid else ''] if name}

def ignored_names(argument):
    return {name.strip().lower() for name in argument.split(',') if name.strip()}

def recording(process):
    return any(read(process, PROCESS_IS_RUNNING_INPUT))

def recorders():
    return [process for process in read(SYSTEM_OBJECT, PROCESS_OBJECT_LIST) if recording(process)]

def pipewire_objects():
    return json.loads(subprocess.run(['pw-dump'], capture_output=True, text=True).stdout or '[]')

def properties(item):
    return (item.get('info') or {}).get('props') or {}

def pipewire_recorders():
    objects = pipewire_objects()
    clients = {item['id']: properties(item) for item in objects if item.get('type') == 'PipeWire:Interface:Client'}
    streams = [properties(item) for item in objects if item.get('type') == 'PipeWire:Interface:Node']
    return [{**clients.get(stream.get('client.id'), {}), **stream} for stream in streams
            if stream.get('media.class') == 'Stream/Input/Audio' and not stream.get('stream.capture.sink')]

def pipewire_names(process):
    return {process[key].lower() for key in ('application.process.binary', 'application.name') if process.get(key)}

if sys.platform.startswith('linux'):
    recorders = pipewire_recorders
    names = pipewire_names

def list_recorders():
    found = recorders()
    for process in found:
        print(', '.join(sorted(names(process))) or 'unknown process')
    return 0 if found else 1

def check(ignored):
    found = recorders()
    if not ignored:
        return 0 if found else 1
    matched = set()
    for process in found:
        matches = names(process) & ignored
        if not matches:
            return 0
        matched.add(sorted(matches)[0])
    for name in sorted(matched):
        print(name)
    return 1

def main():
    arguments = sys.argv[1:]
    if arguments == ['--list']:
        return list_recorders()
    return check(ignored_names(arguments[1] if arguments[:1] == ['--ignore'] and len(arguments) > 1 else ''))

if __name__ == '__main__':
    sys.exit(main())
