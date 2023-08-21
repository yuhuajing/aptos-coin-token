//:!:>moon
module ClayCoin::clay_coin {
    use std::signer;
    use std::string;
    use aptos_framework::timestamp;
    use std::event;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, FreezeCapability, BurnCapability};
    use ClayCoin::acl::{Self, ACL};

    const ENOT_ADMIN:u64=0;
    const E_DONT_HAVE_CAPABILITY:u64=1;
    const E_HAVE_CAPABILITY:u64=2;
    const ENOT_ENOUGH_TOKEN:u64=3;
    const E_MINT_FORBIDDEN:u64=4;
    const E_ADDR_NOT_REGISTED_ClayCoin:u64=5;
    const ERR_NO_UNLOCKED:u64=6;
    const ENOT_VALID_LOCK_TIME:u64=7;
    const E_NOT_WHIIELIST:u64=8;
    const DEPLOYER: address = @admin;
    const RESOURCE_ACCOUNT_ADDRESS: address = @staking;
    const TEAM_ADDRESS: address = @staking;


    struct ClayCoin has key {}

    struct LockedYHJ has key {
        coins: Coin<ClayCoin>,
        vec : vector<LockedItem>,
    }

    struct LockedItem has key, store, drop {
        amount: u64,
        owner: address,
        unlock_timestamp: u64,
    }

    // struct Coinabilities has key{
    //     mint_cap: coin::MintCapability<ClayCoin>,
    //     burn_cap: coin::BurnCapability<ClayCoin>,
    //     freeze_cap: coin::FreezeCapability<ClayCoin>
    // }

    struct Caps has key {
        admin_address: address, // admin address, control direct mint ANI and other setting
        staking_address: address,   // staking address (masterchef resource address), which can also mint ANI
        direct_mint: bool,
        mint: MintCapability<ClayCoin>,
        freeze: FreezeCapability<ClayCoin>,
        burn: BurnCapability<ClayCoin>,
        mint_event: event::EventHandle<MintBurnEvent>,
        burn_event: event::EventHandle<MintBurnEvent>,
        acl:ACL,
    }

    struct MintBurnEvent has drop, store {
        value: u64,
    }

    public fun has_coin_capabilities(addr:address){
        assert!(exists<Caps>(addr),E_DONT_HAVE_CAPABILITY);
    }
    public fun not_has_coin_capabilities(addr:address){
        assert!(!exists<Caps>(addr),E_HAVE_CAPABILITY);
    }

    fun init_module(admin: &signer){
        // let account_addr = signer::address_of(admin);
        // not_has_coin_capabilities(account_addr);
        let (burn_cap,freeze_cap,mint_cap) = coin::initialize<ClayCoin>(
            admin,
            string::utf8(b"YHJ Coin"),
            string::utf8(b"THJ"),
            8,
            true,
        );

        move_to(admin,Caps{
                admin_address: DEPLOYER, // admin address, control direct mint ANI and other setting
                staking_address: RESOURCE_ACCOUNT_ADDRESS,   // staking address (masterchef resource address), which can also mint ANI
                direct_mint: true,
                mint: mint_cap,
                freeze: freeze_cap,
                burn: burn_cap,
                mint_event: account::new_event_handle<MintBurnEvent>(admin),
                burn_event: account::new_event_handle<MintBurnEvent>(admin),
                acl:acl::empty(),
            });

        register(admin);

        move_to(admin, LockedYHJ {
            coins: coin::zero<ClayCoin>(),
            vec: vector::empty(),
        });
        //team_emission(admin);
    }

    public entry fun team_emission(admin: &signer) acquires Caps, LockedYHJ {
        let count = 1;
        while (count <= 16) {
            mint_lock_YHJ(admin, TEAM_ADDRESS, 50000000000000, count * 90);
            count = count + 1;
        };
    }

        /// Mint YHJ with a lock period.
    public entry fun mint_lock_YHJ(
        admin: &signer,
        to: address,
        amount: u64,
        days_to_unlock: u64,
    ) acquires Caps, LockedYHJ {
        let admin_addr = signer::address_of(admin);
        has_coin_capabilities(admin_addr);
        is_admin(admin_addr);
        assert!(days_to_unlock >= 1, ENOT_VALID_LOCK_TIME);       
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        let locked_YHJ = borrow_global_mut<LockedYHJ>(DEPLOYER);
        let coins = coin::mint<ClayCoin>(amount, &caps.mint);
        coin::merge(&mut locked_YHJ.coins, coins);
        vector::push_back(&mut locked_YHJ.vec, LockedItem {
            amount: amount,
            owner: to,
            unlock_timestamp: timestamp::now_seconds() + days_to_unlock * 86400,
        });
        event::emit_event(&mut caps.mint_event, MintBurnEvent {
            value: amount,
        });
    }

    public entry fun withdraw_unlocked_YHJ(account:&signer)acquires LockedYHJ{
        let account_addr = signer::address_of(account);
        register(account);
        let locked_yhj = borrow_global_mut<LockedYHJ>(DEPLOYER);
        let index=0;
        let is_succ = false;
        let now = timestamp::now_seconds();
        while(index < vector::length(&locked_yhj.vec)){
            let item = vector::borrow_mut(&mut locked_yhj.vec,index);
            if(item.owner == account_addr && item.unlock_timestamp<=now){
                let coins = coin::extract(&mut locked_yhj.coins, item.amount);
                coin::deposit<ClayCoin>(account_addr, coins);
                let _removed_item = vector::swap_remove(&mut locked_yhj.vec, index);
                is_succ = true;
            }else{
                index = index+1;
            }
        };
        assert!(is_succ, ERR_NO_UNLOCKED);
    }

//Need to_Address to register the coinType firstly
    public entry fun mint_YHJ(admin:&signer,amount:u64,to:address)acquires Caps{
        let admin_addr = signer::address_of(admin);
        is_admin(admin_addr);
        has_coin_capabilities(admin_addr);
       // assert!(coin::is_account_registered<ClayCoin>(to),E_ADDR_NOT_REGISTED_ClayCoin);
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        assert!(caps.direct_mint,E_MINT_FORBIDDEN);
        let coins = coin::mint<ClayCoin>(amount,&caps.mint);
      //  coin::deposit<ClayCoin>(to, coins);
        coin::deposit(to, coins);
        event::emit_event(&mut caps.mint_event, MintBurnEvent {
            value: amount,
        });
    }

    public entry fun staking_mint_YHJ(
        staking: &signer,
        amount: u64,
    )acquires Caps {
        let caps = borrow_global<Caps>(DEPLOYER);
        assert!(caps.direct_mint,E_MINT_FORBIDDEN);
        let staking_addr = signer::address_of(staking);
        assert!( staking_addr == caps.staking_address, E_MINT_FORBIDDEN);
        register(staking);
        
        let coins = coin::mint<ClayCoin>(amount, &caps.mint);
        coin::deposit<ClayCoin>(staking_addr, coins);
    }

    public entry fun wl_mint_YHJ(
        wl: &signer,
        amount: u64,
    )acquires Caps {
        let caps = borrow_global<Caps>(DEPLOYER);
        assert!(caps.direct_mint,E_MINT_FORBIDDEN);
        let wl_addr = signer::address_of(wl);
        assert!(acl::is_allowed(&caps.acl,&wl_addr),E_NOT_WHIIELIST);
        register(wl);
        
        let coins = coin::mint<ClayCoin>(amount, &caps.mint);
        coin::deposit<ClayCoin>(wl_addr, coins);
    }

    public entry fun burn_YHJ(
        account: &signer,
        amount: u64
    ) acquires Caps {
        let account_addr = signer::address_of(account);
        assert!(coin::balance<ClayCoin>(account_addr) >= amount,ENOT_ENOUGH_TOKEN);
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        let coins = coin::withdraw<ClayCoin>(account, amount);
        coin::burn(coins, &caps.burn);
        event::emit_event(&mut caps.burn_event, MintBurnEvent {
            value: amount,
        });
    }

    // public entry fun burn_YHJ_Coin(
    //     account:&signer,
    //     amount:u64,
    //     //coins: Coin<ClayCoin>,
    // ) acquires Caps {        
    //     let account_addr = signer::address_of(account);
    //     is_admin(account_addr);
    //     has_coin_capabilities(account_addr);
    //     let amount = coin::value(&coins);
    //     assert!(coin::balance<ClayCoin>(account_addr)>=amount,ENOT_ENOUGH_TOKEN);
    //     let caps = borrow_global_mut<Caps>(DEPLOYER);
    //     coin::burn(coins, &caps.burn);
    //     event::emit_event(&mut caps.burn_event, MintBurnEvent {
    //         value: amount,
    //     });
    // }

    public entry fun register(account: &signer){
        let account_address = signer::address_of(account);
        if (!coin::is_account_registered<ClayCoin>(account_address)){
            coin::register<ClayCoin>(account);
        };
    }

    public entry fun is_admin(admin:address)acquires Caps{
        let caps = borrow_global<Caps>(DEPLOYER);
        assert!(admin==caps.admin_address,ENOT_ADMIN);
    }

    /// Set admin address
    public entry fun set_admin_address(
        admin: &signer,
        new_admin_address: address,
    ) acquires Caps {
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        assert!(signer::address_of(admin) == caps.admin_address, ENOT_ADMIN);
        caps.admin_address = new_admin_address;
    }

    /// Set staking address
    public entry fun set_staking_address(
        admin: &signer,
        new_staking_address: address,
    ) acquires Caps {
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        assert!(signer::address_of(admin) == caps.admin_address, ENOT_ADMIN);
        caps.staking_address = new_staking_address;
    }

    /// After call this, direct mint will be disabled forever
    public entry fun set_disable_direct_mint(
        admin: &signer
    ) acquires Caps {
        let caps = borrow_global_mut<Caps>(DEPLOYER);
        assert!(signer::address_of(admin) == caps.admin_address, ENOT_ADMIN);
        caps.direct_mint = false;
    }

//Need from)address && to_Address to register the coinType firstly
    public entry fun transfer(from:&signer,to:address,amount:u64){
        let from_addr = signer::address_of(from);
        assert!(coin::balance<ClayCoin>(from_addr)>=amount,ENOT_ENOUGH_TOKEN);
        coin::transfer<ClayCoin>(from, to, amount);
    }

    public entry fun freeze_user(account: &signer) acquires Caps {
        let account_addr = signer::address_of(account);
      //  is_admin(account_addr);
       // has_coin_capabilities(account_addr);
        let caps = borrow_global<Caps>(DEPLOYER);
        coin::freeze_coin_store<ClayCoin>(account_addr, &caps.freeze);
    }

    public entry fun unfreeze_user(account: &signer) acquires Caps {
        let account_addr = signer::address_of(account);
       // is_admin(account_addr);
       // has_coin_capabilities(account_addr);
       let caps = borrow_global<Caps>(DEPLOYER);
        coin::unfreeze_coin_store<ClayCoin>(account_addr, &caps.freeze);
    }

        /// if not in the allow list, add it. Otherwise, remove it.
    public entry fun allowlist(account: &signer, ua: address) acquires Caps {
        let account_addr = signer::address_of(account);
       // assert_executor_registered(account_addr);
        is_admin(account_addr);
        let config = borrow_global_mut<Caps>(account_addr);
        // let (found, index) = vector::index_of(&config.acl.allow_list, &ua);
        // if (found) {
        //     vector::swap_remove(&mut config.acl.allow_list, index);
        // } else {
        //     vector::push_back(&mut config.acl.allow_list, ua);
        // };

        acl::allowlist(&mut config.acl, ua);
    }

    /// if not in the deny list, add it. Otherwise, remove it.
    public entry fun denylist(account: &signer, ua: address) acquires Caps {
        let account_addr = signer::address_of(account);
        is_admin(account_addr);
        let config = borrow_global_mut<Caps>(account_addr);
        // let (found, index) = vector::index_of(&config.acl.deny_list, &ua);
        // if (found) {
        //     vector::swap_remove(&mut config.acl.deny_list, index);
        // } else {
        //     vector::push_back(&mut config.acl.deny_list, ua);
        // };
        acl::denylist(&mut config.acl, ua);
    }

    // fun is_allowed(acl: &ACL, addr: &address):bool{
    //     if (vector::contains(&acl.deny_list, addr)) {
    //         return false
    //     };
    //     vector::length(&acl.allow_list) == 0 || vector::contains(&acl.allow_list, addr)
    // }

    #[view]
    public fun is_allowed_Addr(addr: &signer):bool acquires Caps {
       let account_addr = signer::address_of(addr);
       let config = borrow_global<Caps>(DEPLOYER);
       acl::is_allowed(&config.acl,&account_addr)
    }

    #[view]
    public fun balance(account:&signer):u64{
        let account_addr = signer::address_of(account);
        coin::balance<ClayCoin>(account_addr)
    }
}

