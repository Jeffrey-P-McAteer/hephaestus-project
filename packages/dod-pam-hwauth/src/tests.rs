
// This file is only compiles for tests, and is responsible for
// testing all branches 

use super::*;

#[test]
fn test_auth_withbad_data() {
  unsafe {
    let r = pam_sm_setcred(
      std::mem::transmute(0 as u8),
      std::mem::transmute(0),
      std::mem::transmute(0),
      std::mem::transmute(std::ptr::null::<u8>()
    ));
    assert_eq!(r, PAM_USER_UNKNOWN as c_int);

    let r = pam_sm_acct_mgmt(
      std::mem::transmute(0 as u8),
      std::mem::transmute(0),
      std::mem::transmute(0),
      std::mem::transmute(std::ptr::null::<u8>()
    ));
    assert_eq!(r, PAM_USER_UNKNOWN as c_int);

    let r = pam_sm_authenticate(
      std::mem::transmute(0 as u8),
      std::mem::transmute(0),
      std::mem::transmute(0),
      std::mem::transmute(std::ptr::null::<u8>()
    ));
    assert_eq!(r, PAM_AUTHINFO_UNAVAIL as c_int);

  }
}


