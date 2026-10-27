import contextlib
import importlib.util
import io
import sys

spec = importlib.util.spec_from_file_location('mic', sys.argv[1])
mic = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mic)
mic.names = {1: {'com.apple.siri', 'siri'}, 2: {'com.apple.siri', 'siri'}, 3: {'us.zoom.xos', 'zoom.us'}}.get

def run(found, *arguments):
    mic.recorders = lambda: found
    sys.argv = ['mic', *arguments]
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        status = mic.main()
    return '%s [%s]' % (status, ' '.join(out.getvalue().split()))

print(run([]))
print(run([1, 3]))
print(run([1, 3], '--ignore', ''))
print(run([1, 3], '--ignore', 'com.apple.Siri'))
print(run([1, 2], '--ignore', 'com.apple.Siri'))
print(run([1, 2, 3], '--ignore', ' SIRI ,zoom.us'))
print(run([1, 3], '--ignore', '--list'))
print(run([1, 3], '--list'))
