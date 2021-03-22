
import os
import subprocess
import ctypes

if __name__ == '__main__':
  # Move to our directory
  os.chdir( os.path.dirname(os.path.abspath(__file__)) )
  # Ensure shared lib is compiled
  subprocess.run([
    'cargo', 'build', '--release'
  ], check=True)

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


