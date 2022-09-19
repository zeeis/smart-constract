// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0

pub mod account;
pub mod hash;
pub mod signature;
pub mod type_info;

use move_deps::{
    move_core_types::{account_address::AccountAddress, identifier::Identifier},
    move_vm_runtime::native_functions::{NativeFunction, NativeFunctionTable},
};

pub mod cost {
    pub const APTOS_CREATE_ADDRESS: u64 = 5;
    pub const APTOS_LIB_TYPE_OF: u64 = 10;
    pub const APTOS_SIP_HASH: u64 = 10;
}

pub mod status {
    // Failure in parsing a struct type tag
    pub const NFE_EXPECTED_STRUCT_TYPE_TAG: u64 = 0x1;
    // Failure in address parsing (likely no correct length)
    pub const NFE_UNABLE_TO_PARSE_ADDRESS: u64 = 0x2;
}

pub fn all_natives(framework_addr: AccountAddress) -> NativeFunctionTable {
    const NATIVES: &[(&str, &str, NativeFunction)] = &[
        ("Account", "create_address", account::native_create_address),
        ("Account", "create_signer", account::native_create_signer),
        (
            "Signature",
            "bls12381_validate_pubkey",
            signature::native_bls12381_public_key_validation,
        ),
        (
            "Signature",
            "ed25519_validate_pubkey",
            signature::native_ed25519_publickey_validation,
        ),
        (
            "Signature",
            "ed25519_verify",
            signature::native_ed25519_signature_verification,
        ),
        ("TypeInfo", "type_of", type_info::type_of),
        ("Hash", "sip_hash", hash::native_sip_hash),
    ];
    NATIVES
        .iter()
        .cloned()
        .map(|(module_name, func_name, func)| {
            (
                framework_addr,
                Identifier::new(module_name).unwrap(),
                Identifier::new(func_name).unwrap(),
                func,
            )
        })
        .collect()
}
