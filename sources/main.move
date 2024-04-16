#[allow(lint(self_transfer))]
module platform::subscription {
    use sui::tx_context::{Self, TxContext, sender};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::table::{Table, Self};
    use sui::bag::{Self, Bag};
    use sui::transfer;
    use sui::clock::{Self, Clock, timestamp_ms};
    use std::string::{Self, String};
    use std::vector;

    /// Error Constants ///
    const ENoSubscription: u64 = 0; // No active subscription for the user
    const EInsufficientFunds: u64 = 1; // Insufficient funds to subscribe or renew
    const EInvalidTransaction: u64 = 2; // Invalid transaction type
    const ESubscriptionExists: u64 = 3; // User already has an active subscription
    const EInvalidCap: u64 = 4; // User already has an active subscription

    const FEE: u128 = 1;

    // Type that stores user account data:
    struct Account<phantom COIN> has key {
        id: UID,
        inner: address,
        create_date: u64,
        last_subscription_date: u64,
        subscription_valid_until: u64,
        sub_count: u64,
        user_address: address,
    }

    // Type that represents the platform's subscription system:
    struct Platform<phantom COIN> has key, store {
        id: UID,
        inner: ID,
        balance: Bag,
        sub_price: u64
    }

    struct PlatformCap has key {
        id: UID,
        platform: ID
    }

    struct Protocol has key, store {
        id: UID,
        balance: Bag
    }

    struct AdminCap has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Protocol {
            id: object::new(ctx),
            balance: bag::new(ctx)
        });
        transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
    }

    /// Create a new subscription platform.
    public fun new_platform<COIN>(price:u64, ctx: &mut TxContext) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        transfer::share_object(Platform<COIN> {
            id: id_,
            inner: inner_,
            balance: bag::new(ctx),
            sub_price: price
        });
        transfer::transfer(PlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx));
    }

    // Subscribe a user to the platform.
    public fun subscribe<COIN>(
        protocol: &mut Protocol,
        platform: &mut Platform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        coin: Coin<COIN>,
        ctx: &mut TxContext
    ) : Account<COIN> {
        let value = coin::value(&coin);
        let deposit_value = value - (((value as u128) * FEE / 100) as u64);
        assert!(value + deposit_value >= platform.sub_price, EInsufficientFunds);
        let protocol_fee = value - deposit_value;
        // split the protocol fee 
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx);
        // define the protocol balance 
        let protocol_balance = coin::into_balance(protocol_fee);
        // define the platform balance 
        let platform_balance = coin::into_balance(coin);
        // get protocol bag
        let protocol_bag = &mut protocol.balance;
        // get platfrom bag
        let platform_bag = &mut platform.balance;
        // define the name of coin
        let name = coin::get_name(coin_metadata);
        // we should create a key value pair in our bag like <String, Balance>
        let coin_names = string::utf8(b"coins");
        // lets check is there any same token in protocol bag 
        helper_bag(protocol_bag, coin_names, protocol_balance);
        // lets check is there any same token in platform bag 
        helper_bag(platform_bag, coin_names, platform_balance);

        let id_ = object::new(ctx);
        let inner_ = object::uid_to_address(&id_); 
        let account = Account {
            id: id_,
            inner: inner_,
            create_date: clock::timestamp_ms(clock),
            last_subscription_date: 0,
            subscription_valid_until: 0,
            sub_count: 1,
            user_address: tx_context::sender(ctx),
        };
        account
    }

    // Renew a user's subscription on the platform.
    public fun resubscribe<COIN>(
        protocol:&mut Protocol,
        platform: &mut Platform<COIN>,
        acc: &mut Account<COIN>,
        c: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        coin: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        // get value 
        let value = coin::value(&coin);
        // calculate deposit value 
        let deposit_value = value - (((value as u128) * FEE / 100) as u64);
        // check the fee + sub price 
        assert!(value + deposit_value >= platform.sub_price, EInsufficientFunds);
        // calculate the protocol fee
        let protocol_fee = value - deposit_value;
        // split the protocol fee 
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx);
        // define the protocol balance 
        let protocol_balance = coin::into_balance(protocol_fee);
        // define the platform balance 
        let platform_balance = coin::into_balance(coin);
        // get protocol bag
        let protocol_bag = &mut protocol.balance;
        // get platfrom bag
        let platform_bag = &mut platform.balance;
        // define the name of coin
        let name = coin::get_name(coin_metadata);
        // we should create a key value pair in our bag like <String, Balance>
        let coin_names = string::utf8(b"coins");
        // lets check is there any same token in protocol bag 
        helper_bag(protocol_bag, coin_names, protocol_balance);
        // lets check is there any same token in platform bag 
        helper_bag(platform_bag, coin_names, platform_balance);
        // increase the sub count 1
        acc.sub_count = acc.sub_count + 1;
        // set the latest sub date 
        acc.last_subscription_date = timestamp_ms(c);
    }

    public fun withdraw_fee<COIN>(_:&AdminCap, self: &mut Protocol, coin: String, ctx: &mut TxContext) : Coin<COIN> {
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    public fun withdraw_sub<COIN>(self: &mut Platform<COIN>, cap: &PlatformCap, coin: String, ctx: &mut TxContext) : Coin<COIN> {
        assert!(self.inner == cap.platform, EInvalidCap);
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    // Example accessor function for fetching user's subscription fee
    public fun get_account_date<COIN>(self: &Account<COIN>): u64 {
        self.create_date
    }
    public fun get_account_id<COIN>(self: &Account<COIN>): address {
        self.inner
    }
    public fun get_account_sub_date<COIN>(self: &Account<COIN>): u64 {
        self.last_subscription_date
    }
    public fun get_account_sub_valid<COIN>(self: &Account<COIN>): u64 {
        self.subscription_valid_until
    }
    public fun get_account_owner<COIN>(self: &Account<COIN>): address {
        self.user_address
    }

    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) {
        if(bag::contains(bag_, coin)) { 
        // if there is a same token in our bag we will join it.
            let coin_value = bag::borrow_mut( bag_, coin);
            balance::join(coin_value, balance);
        }
        // if it is not lets add it.
        else {
             // add fund into the bag 
             bag::add(bag_, coin, balance);
        };
    }
}
