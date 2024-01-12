use starknet::ContractAddress;
use integer::u256_from_felt252;
use ecdsa::check_ecdsa_signature;
use starknet::contract_address_to_felt252;
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use dojo_ars::models::{LastCheck};
use dojo_ars::world_config::{VoxelId, VoxelIdV1, ResourcesCost, AssetContract};
use starknet::get_caller_address;

#[starknet::interface]
trait ICalleeVoxel20<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        amount: u256,
    );

    fn burn(
        ref self: TContractState,
        from: ContractAddress,
        amount: u256,
    );
}

#[starknet::interface]
trait ICalleeVoxel1155<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        id: u256,
        amount: u256,
    );

    fn burn_batch(
        ref self: TContractState,
        from: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>
    );
}

#[starknet::interface]
trait ICalleeCore1155<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        id: u256,
        amount: u256,
    );
}

#[starknet::interface]
trait ICalleeBlueprint<TContractState> {
    fn get_costdata(
        self: @TContractState,
        token_id: u256,
    ) -> CostData;
}

#[starknet::interface]
trait ICalleeBuild<TContractState> {
    fn mint(
        ref self: TContractState, 
        recipient: ContractAddress,
    );
}

#[derive(Drop, Serde)]
struct CostData {
    base_block: u256,
    color_r: u256,
    color_g: u256,
    color_b: u256,
    color_black: u256,
}

#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    AssetContractEvent: AssetContractEvent,
}

#[derive(Drop, starknet::Event)]
struct AssetContractEvent {
    ckey: felt252,
    ctype: felt252,
    address: ContractAddress,
    debuga: felt252,
}

fn verifySign(
    last_check: u256,
    public_key: felt252,
    issuer: felt252,
    receiver: ContractAddress,
    tid: felt252,
    starkid: felt252,
    endid: felt252,
    amt: felt252,
    t721id: felt252,
    remove_block: felt252,
    r: felt252,
    s: felt252
) -> felt252 {
    let tokenid = u256_from_felt252(tid);
    let thischecksid = u256_from_felt252(starkid);
    assert(last_check + 1 == thischecksid, 'CHECKS ID NOT VALID');
    let message_hash = pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(issuer, contract_address_to_felt252(receiver)), tid), starkid), endid), amt), t721id), remove_block);
    assert(
        check_ecdsa_signature(
            message_hash: message_hash,
            public_key: public_key,
            signature_r: r,
            signature_s: s,
        ),
        'INVALID_SIGNATURE',
    );
    starknet::VALIDATED
}

fn util_mint_voxel_by_checks(
    world: IWorldDispatcher,
    contract_voxel_address: ContractAddress,
    contract_core_address: ContractAddress,
    public_key: felt252,
    issuer: felt252,
    receiver: ContractAddress,
    tid: Array<felt252>,
    startid: Array<felt252>,
    endid: Array<felt252>,
    amt: Array<felt252>,
    t721id: Array<felt252>,
    remove_block: Array<felt252>,
    r: Array<felt252>,
    s: Array<felt252>,
) {
    let mut i: usize = 0;

    let _tid = tid.clone();
    let _startid = startid.clone();
    let _endid = endid.clone();
    let _amt = amt.clone();
    let _r = r.clone();
    let _s = s.clone();
    let _t721id = t721id.clone();
    let _rblock = remove_block.clone();
    loop {
        if i == tid.len() {
            break;
        }
        let tokenid = u256_from_felt252(*_tid.at(i));
        let last_check = get!(world, (receiver, tokenid), (LastCheck));
        assert(verifySign(last_check.last_id, public_key, issuer, receiver, *_tid.at(i), *_startid.at(i), *_endid.at(i), *_amt.at(i), *_t721id.at(i), *_rblock.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

        let endchecksid = u256_from_felt252(*_endid.at(i));
        let amount = u256_from_felt252(*_amt.at(i));
        if tokenid == 10001 || tokenid == 10002 || tokenid == 10003  {
            ICalleeCore1155Dispatcher { contract_address: contract_core_address }.mint(receiver, tokenid, amount);
        } else {
            ICalleeVoxel1155Dispatcher { contract_address: contract_voxel_address }.mint(receiver, tokenid, amount);
        }
        set!(world, (LastCheck { player: receiver, token_id: tokenid, last_id: endchecksid } ));
        i += 1;
    };
}

fn util_mint_build(
    world: IWorldDispatcher,
    contract_build_address: ContractAddress,
    contract_voxel_address: ContractAddress,
    from_tid: felt252,
) {
    let config_id: u8 = 1;
    let voxel_ids = get!(world, (config_id), (VoxelId));
    let cost_num = get!(world, (from_tid), (ResourcesCost));
    let mut burn_ids: Array<u256> = ArrayTrait::new();
    let mut burn_amounts: Array<u256> = ArrayTrait::new();
    burn_ids.append(voxel_ids.base_voxel_id);
    burn_amounts.append(cost_num.block_num);
    burn_ids.append(voxel_ids.r_voxel_id);
    burn_amounts.append(cost_num.r_num);
    burn_ids.append(voxel_ids.g_voxel_id);
    burn_amounts.append(cost_num.g_num);
    burn_ids.append(voxel_ids.b_voxel_id);
    burn_amounts.append(cost_num.b_num);
    burn_ids.append(voxel_ids.balck_voxel_id);
    burn_amounts.append(cost_num.black_num);
    
    ICalleeVoxel1155Dispatcher { contract_address: contract_voxel_address }.burn_batch(get_caller_address(), burn_ids, burn_amounts);
    ICalleeBuildDispatcher { contract_address: contract_build_address }.mint(get_caller_address());
}


fn util_mint_voxel_by_checks_v1(
    world: IWorldDispatcher,
    public_key: felt252,
    issuer: felt252,
    receiver: ContractAddress,
    tid: Array<felt252>,
    startid: Array<felt252>,
    endid: Array<felt252>,
    amt: Array<felt252>,
    t721id: Array<felt252>,
    remove_block: Array<felt252>,
    r: Array<felt252>,
    s: Array<felt252>,
) {
    let mut i: usize = 0;

    let _tid = tid.clone();
    let _startid = startid.clone();
    let _endid = endid.clone();
    let _amt = amt.clone();
    let _r = r.clone();
    let _s = s.clone();
    let _t721id = t721id.clone();
    let _rblock = remove_block.clone();
    loop {
        if i == tid.len() {
            break;
        }
        let tokenid = u256_from_felt252(*_tid.at(i));
        let last_check = get!(world, (receiver, tokenid), (LastCheck));
        assert(verifySign(last_check.last_id, public_key, issuer, receiver, *_tid.at(i), *_startid.at(i), *_endid.at(i), *_amt.at(i), *_t721id.at(i), *_rblock.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

        let endchecksid = u256_from_felt252(*_endid.at(i));
        let amount = u256_from_felt252(*_amt.at(i));

        let acontract_address = get!(world, (*_tid.at(i)), (AssetContract));
        emit !(world, AssetContractEvent{ckey: acontract_address.contract_key, ctype: acontract_address.contract_type, address: acontract_address.contract_address, debuga: 1});
        if acontract_address.contract_type == 20 {
            ICalleeVoxel20Dispatcher { contract_address: acontract_address.contract_address }.mint(receiver, amount);
        } else if acontract_address.contract_type == 1155 {
            ICalleeCore1155Dispatcher { contract_address: acontract_address.contract_address }.mint(receiver, tokenid, amount);
        }
        
        set!(world, (LastCheck { player: receiver, token_id: tokenid, last_id: endchecksid } ));
        i += 1;
    };
}

fn util_mint_build_v1(
    world: IWorldDispatcher,
    from_contract: ContractAddress,
    from_tid: u256,
) {
    let config_id: u8 = 1;
    let voxel_ids = get!(world, (config_id), (VoxelIdV1));
    let costdata: CostData = ICalleeBlueprintDispatcher { contract_address: from_contract }.get_costdata(from_tid);
    
    let asset_contract1 = get!(world, (voxel_ids.base_voxel_id), (AssetContract));
    ICalleeVoxel20Dispatcher { contract_address: asset_contract1.contract_address }.burn(get_caller_address(), costdata.base_block);
    let asset_contract2 = get!(world, (voxel_ids.r_voxel_id), (AssetContract));
    ICalleeVoxel20Dispatcher { contract_address: asset_contract2.contract_address }.burn(get_caller_address(), costdata.color_r);
    let asset_contract3 = get!(world, (voxel_ids.g_voxel_id), (AssetContract));
    ICalleeVoxel20Dispatcher { contract_address: asset_contract3.contract_address }.burn(get_caller_address(), costdata.color_g);
    let asset_contract4 = get!(world, (voxel_ids.b_voxel_id), (AssetContract));
    ICalleeVoxel20Dispatcher { contract_address: asset_contract4.contract_address }.burn(get_caller_address(), costdata.color_b);
    let asset_contract5 = get!(world, (voxel_ids.balck_voxel_id), (AssetContract));
    ICalleeVoxel20Dispatcher { contract_address: asset_contract5.contract_address }.burn(get_caller_address(), costdata.color_black);
    
    // let asset_contract = get!(world, 721, (AssetContract));
    // ICalleeBuildDispatcher { contract_address: asset_contract.contract_address }.mint(get_caller_address());
}

fn debug_init_checks(
    world: IWorldDispatcher,
    receiver: ContractAddress,
    tid: Array<felt252>,
) {
    let mut i: usize = 0;

    let _tid = tid.clone();
    loop {
        if i == tid.len() {
            break;
        }
        let tokenid = u256_from_felt252(*_tid.at(i));
        
        set!(world, (LastCheck { player: receiver, token_id: tokenid, last_id: 0 } ));
        i += 1;
    };
}
