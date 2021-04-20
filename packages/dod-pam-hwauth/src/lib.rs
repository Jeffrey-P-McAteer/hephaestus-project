
#![allow(dead_code)]

use libc::{
  c_int, c_uint, c_char, c_void
};
use pcsc::{
  Context, Scope, ShareMode, Protocols, Error, Card
};

#[cfg(test)]
mod tests;


// Constants copied from: https://pubs.opengroup.org/onlinepubs/8329799/apdxa.htm

const PAM_SUCCESS: c_uint = 0; /* Normal function return */
const PAM_OPEN_ERR: c_uint = 1; /* Failure in loading service module*/
const PAM_SYMBOL_ERR: c_uint = 2; /* Symbol not found */
const PAM_SERVICE_ERR: c_uint = 3; /* Error in underlying service module */
const PAM_SYSTEM_ERR: c_uint = 4; /* System error */
const PAM_BUF_ERR: c_uint = 5; /* Memory buffer error */
const PAM_CONV_ERR: c_uint = 6; /* Conversation failure */
const PAM_PERM_DENIED: c_uint = 7; /* Permission denied */
const PAM_MAXTRIES: c_uint = 8; /* Maximum number of tries exceeded */
const PAM_AUTH_ERR: c_uint = 9; /* Authentication failure */
const PAM_NEW_AUTHTOK_REQD: c_uint = 10; /* Get new auth token from the user */
const PAM_CRED_INSUFFICIENT: c_uint = 11; /* can not access auth data b/c */
                                  /* of insufficient credentials  */
const PAM_AUTHINFO_UNAVAIL: c_uint = 12; /* Can not retrieve auth information */
const PAM_USER_UNKNOWN: c_uint = 13; /* No account present for user */
const PAM_CRED_UNAVAIL: c_uint = 14; /* can not retrieve user credentials */
const PAM_CRED_EXPIRED: c_uint = 15; /* user credentials expired */
const PAM_CRED_ERR: c_uint = 16; /* failure setting user credentials */
const PAM_ACCT_EXPIRED: c_uint = 17; /* user account has expired */
const PAM_AUTHTOK_EXPIRED: c_uint = 18; /* Password expired and no longer */
const PAM_SESSION_ERR: c_uint = 19; /* can not make/remove entry for */
                                  /* specified session */
const PAM_AUTHTOK_ERR: c_uint = 20; /* Authentication token */
                                      /* manipulation error */
const PAM_AUTHTOK_RECOVERY_ERR: c_uint = 21; /* Old authentication token */
                                      /* cannot be recovered */
const PAM_AUTHTOK_LOCK_BUSY: c_uint = 22; /* Authentication token */
                                      /* lock busy */
const PAM_AUTHTOK_DISABLE_AGING: c_uint = 23; /* Authentication token aging */
                                      /* is disabled */
const PAM_NO_MODULE_DATA: c_uint = 24; /* module data not found */
const PAM_IGNORE: c_uint = 25; /* ignore module */
const PAM_ABORT: c_uint = 26; /* General PAM failure */
const PAM_TRY_AGAIN: c_uint = 27; /* Unable to update password */
                                      /* Try again another time */
const PAM_MODULE_UNKNOWN: c_uint = 28; /* Module unknown */
const PAM_DOMAIN_UNKNOWN: c_uint = 29; /* Domain unknown */



const PAM_SILENT: c_uint = 0x80000000;
const PAM_DISALLOW_NULL_AUTHTOK: c_uint = 0x1; /* The password must be non-null*/

/* flags for pam_setcred() */
const PAM_ESTABLISH_CRED: c_uint = 0x1; /* set scheme specific user id */
const PAM_DELETE_CRED: c_uint = 0x2; /* unset scheme specific user id */
const PAM_REINITIALIZE_CRED: c_uint = 0x4; /* reinitialize user credentials */
                                          /* (after a password has changed */
const PAM_REFRESH_CRED: c_uint = 0x8; /* extend lifetime of credentials */



// https://linux.die.net/man/3/pam_sm_setcred
#[no_mangle]
pub extern "C" fn pam_sm_setcred(
  _pamh: c_void,
  _flags: c_int,
  _argc: c_int,
  _argv: *const *const c_char
) -> c_int {
  
  return PAM_USER_UNKNOWN as c_int;
}


// https://linux.die.net/man/3/pam_sm_acct_mgmt
#[no_mangle]
pub extern "C" fn pam_sm_acct_mgmt(
  _pamh: c_void,
  _flags: c_int,
  _argc: c_int,
  _argv: *const *const c_char
) -> c_int {

  return PAM_USER_UNKNOWN as c_int;
}

fn send_apdu(apdu: &[u8], card: &Card) -> Result<Vec<u8>, ()> {
  let mut rapdu_buf = [0; 2048];
  let rapdu = match card.transmit(apdu, &mut rapdu_buf) {
      Ok(rapdu) => rapdu,
      Err(err) => {
          eprintln!("Failed to transmit APDU command to card: {}", err);
          return Err(());
      }
  };

  return Ok(rapdu.to_vec());
}

// https://linux.die.net/man/3/pam_sm_authenticate
#[no_mangle]
pub extern "C" fn pam_sm_authenticate(
  _pamh: c_void,
  _flags: c_int,
  _argc: c_int,
  _argv: *const *const c_char
) -> c_int {

  // TODO check if username being authenticated against is `owner`


  // TODO read pub keys from /etc/dod_authorized_owners and /etc/dod_authorized_owners.d/*

  

  // Establish a PC/SC context.
  let ctx = match Context::establish(Scope::User) {
      Ok(ctx) => ctx,
      Err(err) => {
          eprintln!("Failed to establish context: {}", err);
          return PAM_AUTHINFO_UNAVAIL as i32;
      }
  };

  // List available readers.
  let mut readers_buf = [0; 2048];
  let mut readers = match ctx.list_readers(&mut readers_buf) {
      Ok(readers) => readers,
      Err(err) => {
          eprintln!("Failed to list readers: {}", err);
          return PAM_AUTHINFO_UNAVAIL as i32;
      }
  };

  // for each reader...
  let mut max_readers = 10;
  loop {
    max_readers -= 1;
    if max_readers < 1 {
      break;
    }
    let reader = match readers.next() {
        Some(reader) => reader,
        None => {
            println!("No more readers are connected.");
            return PAM_AUTHINFO_UNAVAIL as c_int;
        }
    };
    println!("Using reader: {:?}", reader);

    // Connect to the card.
    let mut card = match ctx.connect(reader, ShareMode::Shared, Protocols::ANY) {
        Ok(card) => card,
        Err(Error::NoSmartcard) => {
            println!("A smartcard is not present in the reader.");
            return PAM_AUTHINFO_UNAVAIL as c_int;
        }
        Err(err) => {
            eprintln!("Failed to connect to card: {}", err);
            return PAM_AUTHINFO_UNAVAIL as c_int;
        }
    };

    // response of 6A, 86 means "Incorrect parameters P1-P2"

    // Select master file; a4 == select, 
    // let rapdu = send_apdu(b"\x00\xa4\x00\x00", &card).unwrap();
    // println!("APDU response: {:02X?} (expected )", rapdu);
    // // opens a logical channel numbered in CLA (byte 1, last 2 bits)

    // let rapdu = send_apdu(b"\x00\xB0\x00\x00\x20", &card).unwrap();
    // println!("APDU response: {:02X?}", rapdu);

    // https://cardwerk.com/iso-7816-part-4/
    // See https://cardwerk.com/smart-card-standard-iso7816-4-section-6-basic-interindustry-commands/
    //let rapdu = send_apdu(b"\xA0\xA4\x00\x00\x02\x7F\x10", &card).unwrap();
    let rapdu = send_apdu(b"\x00\xCA\x00\x6E", &card).unwrap();
    println!("APDU response: {:02X?}", rapdu); // 6a 82 - file not found


    if rapdu.len() > 0 {
      return PAM_AUTHINFO_UNAVAIL as c_int;
    }


  }

  if max_readers < 1 {
    return PAM_AUTHINFO_UNAVAIL as c_int;
  }

  return PAM_SUCCESS as c_int;
}



