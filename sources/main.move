#[allow(lint(self_transfer))]
module platform::subscription {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use std::string::{String};
    use std::vector;

    /// Error Constants ///
    const ENoSubscription: u64 = 0; // No active subscription for the user
    const EInsufficientFunds: u64 = 1; // Insufficient funds to subscribe or renew
    const EInvalidTransaction: u64 = 2; // Invalid transaction type
    const ESubscriptionExists: u64 = 3; // User already has an active subscription

    // Type that stores user account data:
    struct Account<phantom COIN> has key, store {
        id: UID,
        inner: address,
        create_date: u64,
        last_subscription_date: u64,
        subscription_valid_until: u64,
        subscription_fee: Coin<COIN>,
        user_address: address,
    }

    // Type that represents the platform's subscription system:
    struct Platform<phantom COIN> has key, store {
        id: UID,
        user_accounts: Table<address, Account<COIN>>,
        platform_address: address
    }

    /// Create a new subscription platform.
    public fun create_platform<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let user_accounts = table::new<address, Account<COIN>>(ctx);
        transfer::share_object(Platform<COIN> {
            id,
            user_accounts,
            platform_address: tx_context::sender(ctx)
        })
    }

    // Subscribe a user to the platform.
    public fun subscribe<COIN>(
        platform: &mut Platform<COIN>,
        clock: &Clock,
        subscription_fee: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        // Check if user already has an active subscription
        assert!(!table::contains<address, Account<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ESubscriptionExists);
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_address(&id_); 
        let user_account = Account {
            id: object::new(ctx),
            inner: inner_,
            create_date: clock::timestamp_ms(clock),
            last_subscription_date: 0,
            subscription_valid_until: 0,
            subscription_fee,
            user_address: tx_context::sender(ctx),
        };
        // Save user account to the platform
        table::add(&mut platform.user_accounts, inner_, user_account);
    }

    // Renew a user's subscription on the platform.
    public fun renew_subscription<COIN>(
        platform: &mut Platform<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, Account<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow_mut<address, Account<COIN>>(&mut platform.user_accounts, tx_context::sender(ctx));
        assert!(coin::value(&user_account.subscription_fee) >= 0, EInsufficientFunds);
        // Subscription renewal logic goes here
    }

    // Unsubscribe a user from the platform.
    public fun unsubscribe<COIN>(
        platform: &mut Platform<COIN>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, Account<COIN>>(&platform.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        // Unsubscribe logic goes here
    }

    // Accessor functions

    public fun user_create_date<COIN>(self: &Platform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, Account<COIN>>(&self.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, Account<COIN>>(&self.user_accounts, tx_context::sender(ctx));
        user_account.create_date
    }

    // Implement other accessor functions as needed...

    // Example accessor function for fetching user's subscription fee
    public fun user_subscription_fee<COIN>(self: &Platform<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, Account<COIN>>(&self.user_accounts, tx_context::sender(ctx)), ENoSubscription);
        let user_account = table::borrow<address, Account<COIN>>(&self.user_accounts, tx_context::sender(ctx));
        coin::value(&user_account.subscription_fee)
    }
}
