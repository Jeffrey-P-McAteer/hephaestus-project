
import os
import subprocess
import ctypes
import webbrowser

def run_integration_tests():
  # Ensure shared lib is compiled
  subprocess.run([
    'cargo', 'build', '--release'
  ], check=True)

  # Dynamic test, as if we were PAM itself
  shared_lib_f = os.path.join('target', 'release', 'libdod_pam_hwauth.so')
  if os.name == 'nt':
    shared_lib_f = os.path.join('target', 'release', 'dod_pam_hwauth.dll')

  print('Loading lib: {}'.format(shared_lib_f))

  dod_pam_hwauth = ctypes.CDLL(shared_lib_f)
  res = dod_pam_hwauth.pam_sm_authenticate(
    0, 0, 0, 0,
  )

  print('res={}'.format(res))
  print('0 == success, other number == error')
  print('See for error codes: https://pubs.opengroup.org/onlinepubs/8329799/apdxa.htm')


def run_coverage_tests():
  # Now perform coverage testing; see 
  # https://readthedocs.org/projects/gcovr/downloads/pdf/stable/
  # https://github.com/mozilla/grcov

  os.environ['CARGO_INCREMENTAL'] = '0'
  os.environ['RUSTFLAGS'] = '-Zinstrument-coverage -Zprofile -Ccodegen-units=1 -Copt-level=0 -Clink-dead-code -Coverflow-checks=off -Zpanic_abort_tests -Cpanic=abort'
  os.environ['RUSTDOCFLAGS'] = '-Cpanic=abort'

  subprocess.run([
    'cargo', 'build', '--release'
  ], check=True)
  
  subprocess.run([
    'cargo', 'test', '--release'
  ], check=True)

  subprocess.run([
    'grcov',
    '.',
    '-s', '.',
    '--binary-path', os.path.join('target', 'release'),
    '-t', 'html',
    '--branch',
    '--ignore-not-existing',
    '-o', os.path.join('target', 'release', 'coverage'),
  ], check=True)

  webbrowser.open(os.path.join('target', 'release', 'coverage', 'index.html'))

if __name__ == '__main__':
  # Move to our directory
  os.chdir( os.path.dirname(os.path.abspath(__file__)) )

  #run_integration_tests()
  run_coverage_tests()
  
