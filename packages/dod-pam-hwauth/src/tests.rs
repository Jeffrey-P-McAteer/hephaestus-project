
// This file is only compiles for tests, and is responsible for
// testing all branches 

use super::*;

use cargo_tarpaulin::config::Config;
use cargo_tarpaulin::launch_tarpaulin;
//use cargo_tarpaulin::traces::CoverageStat;

#[test]
fn test_auth_withbad_data() {

  let mut config = Config::default();
  config.verbose = true;
  config.test_timeout = std::time::Duration::from_secs(3);
  config.manifest = std::env::current_dir();
  config.manifest.push("Cargo.toml");

  let (res, ret) = launch_tarpaulin(&config, &None).unwrap();

  unsafe {
    let r = pam_sm_setcred(
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



