use array::ArrayTrait;
use starknet::ContractAddress;

// locals
use core1155::utils::serde::SerdeTraitExt;
use core1155::utils::try_selector_with_fallback;
use core1155::utils::unwrap_and_cast::UnwrapAndCast;

mod selectors {
  const supports_interface: felt252 = 0xfe80f537b66d12a00b6d3c072b44afbb716e78dde5c3f0ef116ee93d3e3283;
  const supportsInterface: felt252 = 0x29e211664c0b63c79638fbea474206ca74016b3e9a3dc4f9ac300ffd8bdf2cd;
}

#[derive(Copy, Drop)]
struct DualCaseSRC5 {
  contract_address: ContractAddress
}

trait DualCaseSRC5Trait {
  fn supports_interface(self: @DualCaseSRC5, interface_id: felt252) -> bool;
}

impl DualCaseSRC5Impl of DualCaseSRC5Trait {
  fn supports_interface(self: @DualCaseSRC5, interface_id: felt252) -> bool {
    let mut args = array![];
    args.append_serde(interface_id);

    try_selector_with_fallback(
      *self.contract_address,
      selectors::supports_interface,
      selectors::supportsInterface,
      args.span()
    ).unwrap_and_cast()
  }
}